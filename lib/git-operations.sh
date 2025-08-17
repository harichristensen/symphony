#!/bin/bash

# Symphony Git Operations
# Functions for managing git worktrees and branch operations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create a git worktree for an agent
create_agent_worktree() {
    local agent_id="$1"
    local task_id="$2"
    local base_branch="${3:-main}"
    
    local worktree_path=".symphony/worktrees/$agent_id"
    local agent_branch="symphony/${task_id}/${agent_id}"
    
    echo -e "${BLUE}Creating worktree for agent $agent_id...${NC}"
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        return 1
    fi
    
    # Create worktree directory if it doesn't exist
    mkdir -p "$(dirname "$worktree_path")"
    
    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        echo -e "${YELLOW}Worktree already exists at $worktree_path${NC}"
        return 0
    fi
    
    # Create new branch for this agent
    local current_branch=$(git branch --show-current)
    
    # Create agent branch from base branch
    if git show-ref --verify --quiet "refs/heads/$agent_branch"; then
        echo -e "${YELLOW}Branch $agent_branch already exists${NC}"
    else
        git checkout -b "$agent_branch" "$base_branch" 2>/dev/null || {
            echo -e "${RED}Failed to create branch $agent_branch${NC}"
            return 1
        }
        echo -e "${GREEN}✓ Created branch: $agent_branch${NC}"
    fi
    
    # Create the worktree
    if git worktree add "$worktree_path" "$agent_branch"; then
        echo -e "${GREEN}✓ Created worktree: $worktree_path${NC}"
    else
        echo -e "${RED}Failed to create worktree at $worktree_path${NC}"
        return 1
    fi
    
    # Switch back to original branch
    git checkout "$current_branch" 2>/dev/null
    
    echo "$worktree_path"
}

# Remove a git worktree
remove_agent_worktree() {
    local agent_id="$1"
    local worktree_path=".symphony/worktrees/$agent_id"
    
    echo -e "${BLUE}Removing worktree for agent $agent_id...${NC}"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${YELLOW}Worktree does not exist: $worktree_path${NC}"
        return 0
    fi
    
    # Remove the worktree
    if git worktree remove "$worktree_path" 2>/dev/null; then
        echo -e "${GREEN}✓ Removed worktree: $worktree_path${NC}"
    else
        echo -e "${YELLOW}Git worktree remove failed, force removing directory${NC}"
        rm -rf "$worktree_path"
        echo -e "${GREEN}✓ Force removed: $worktree_path${NC}"
    fi
}

# List all Symphony worktrees
list_symphony_worktrees() {
    echo -e "${BLUE}Symphony worktrees:${NC}"
    
    if [[ ! -d ".symphony/worktrees" ]]; then
        echo "No worktrees directory found"
        return
    fi
    
    local found=false
    for worktree in .symphony/worktrees/*/; do
        if [[ -d "$worktree" ]]; then
            local agent_id=$(basename "$worktree")
            local branch=$(git -C "$worktree" branch --show-current 2>/dev/null || echo "unknown")
            echo "  $agent_id -> $worktree (branch: $branch)"
            found=true
        fi
    done
    
    if [[ "$found" == false ]]; then
        echo "No worktrees found"
    fi
}

# Clean up all Symphony worktrees
cleanup_all_worktrees() {
    local force="${1:-false}"
    
    echo -e "${BLUE}Cleaning up all Symphony worktrees...${NC}"
    
    if [[ ! -d ".symphony/worktrees" ]]; then
        echo "No worktrees to clean up"
        return 0
    fi
    
    if [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}This will remove all Symphony worktrees and branches.${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cleanup cancelled"
            return 0
        fi
    fi
    
    # Remove all worktrees
    for worktree in .symphony/worktrees/*/; do
        if [[ -d "$worktree" ]]; then
            local agent_id=$(basename "$worktree")
            remove_agent_worktree "$agent_id"
        fi
    done
    
    # Prune worktree references
    git worktree prune 2>/dev/null || true
    
    # Remove symphony branches
    echo -e "${BLUE}Cleaning up Symphony branches...${NC}"
    local symphony_branches=$(git branch | grep 'symphony/' | sed 's/^[* ] //' || true)
    if [[ -n "$symphony_branches" ]]; then
        echo "$symphony_branches" | while IFS= read -r branch; do
            if [[ -n "$branch" ]]; then
                git branch -D "$branch" 2>/dev/null && echo -e "${GREEN}✓ Deleted branch: $branch${NC}" || true
            fi
        done
    fi
    
    # Remove worktrees directory if empty
    if [[ -d ".symphony/worktrees" ]]; then
        rmdir .symphony/worktrees 2>/dev/null && echo -e "${GREEN}✓ Removed empty worktrees directory${NC}" || true
    fi
}

# Get the current branch for a worktree
get_worktree_branch() {
    local worktree_path="$1"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "ERROR: Worktree not found"
        return 1
    fi
    
    git -C "$worktree_path" branch --show-current 2>/dev/null || echo "unknown"
}

# Check if worktree has uncommitted changes
check_worktree_status() {
    local worktree_path="$1"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "ERROR: Worktree not found"
        return 1
    fi
    
    cd "$worktree_path" || return 1
    
    local status=""
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        status="MODIFIED"
    elif [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        status="UNTRACKED"
    else
        status="CLEAN"
    fi
    
    cd - >/dev/null || return 1
    echo "$status"
}

# Get git status for all worktrees
get_all_worktree_status() {
    echo "{"
    echo "  \"worktrees\": ["
    
    local first=true
    if [[ -d ".symphony/worktrees" ]]; then
        for worktree in .symphony/worktrees/*/; do
            if [[ -d "$worktree" ]]; then
                local agent_id=$(basename "$worktree")
                local branch=$(get_worktree_branch "$worktree")
                local status=$(check_worktree_status "$worktree")
                
                [[ "$first" == false ]] && echo ","
                echo "    {"
                echo "      \"agent_id\": \"$agent_id\","
                echo "      \"path\": \"$worktree\","
                echo "      \"branch\": \"$branch\","
                echo "      \"status\": \"$status\""
                echo -n "    }"
                first=false
            fi
        done
    fi
    
    echo ""
    echo "  ]"
    echo "}"
}

# Commit agent changes
commit_agent_changes() {
    local worktree_path="$1"
    local commit_message="$2"
    local agent_id="$3"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${RED}Error: Worktree not found: $worktree_path${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Committing changes for agent $agent_id...${NC}"
    
    cd "$worktree_path" || return 1
    
    # Check if there are changes to commit
    if git diff-index --quiet HEAD -- && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
        echo -e "${YELLOW}No changes to commit${NC}"
        cd - >/dev/null
        return 0
    fi
    
    # Add all changes
    git add -A
    
    # Commit with message
    local full_message="Symphony Agent ($agent_id): $commit_message"
    if git commit -m "$full_message"; then
        echo -e "${GREEN}✓ Committed changes${NC}"
        echo "Message: $full_message"
    else
        echo -e "${RED}Failed to commit changes${NC}"
        cd - >/dev/null
        return 1
    fi
    
    cd - >/dev/null
}

# Get commit history for agent worktree
get_agent_commits() {
    local worktree_path="$1"
    local limit="${2:-10}"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "ERROR: Worktree not found"
        return 1
    fi
    
    git -C "$worktree_path" log --oneline -n "$limit" --pretty=format:'{"hash": "%h", "message": "%s", "author": "%an", "date": "%ai"}' | \
    sed 's/$/,/' | sed '$ s/,$//' | \
    (echo '['; cat; echo ']')
}

# Cherry-pick agent commits to main branch
integrate_agent_commits() {
    local worktree_path="$1"
    local target_branch="${2:-main}"
    local agent_id="$3"
    
    echo -e "${BLUE}Integrating commits from agent $agent_id...${NC}"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${RED}Error: Worktree not found: $worktree_path${NC}"
        return 1
    fi
    
    # Get the agent's branch
    local agent_branch=$(get_worktree_branch "$worktree_path")
    if [[ "$agent_branch" == "unknown" ]]; then
        echo -e "${RED}Could not determine agent branch${NC}"
        return 1
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Switch to target branch
    if ! git checkout "$target_branch"; then
        echo -e "${RED}Failed to checkout target branch: $target_branch${NC}"
        return 1
    fi
    
    # Get commits to cherry-pick (commits on agent branch not on target)
    local commits=$(git log --reverse --pretty=format:'%H' "$target_branch..$agent_branch")
    
    if [[ -z "$commits" ]]; then
        echo -e "${YELLOW}No commits to integrate${NC}"
        git checkout "$current_branch"
        return 0
    fi
    
    # Cherry-pick each commit
    local success=true
    while IFS= read -r commit; do
        if [[ -n "$commit" ]]; then
            echo "Cherry-picking commit: $commit"
            if ! git cherry-pick "$commit"; then
                echo -e "${RED}Cherry-pick failed for commit: $commit${NC}"
                echo "Resolve conflicts manually and run 'git cherry-pick --continue'"
                success=false
                break
            fi
        fi
    done <<< "$commits"
    
    if [[ "$success" == true ]]; then
        echo -e "${GREEN}✓ Successfully integrated all commits from agent $agent_id${NC}"
    fi
    
    # Switch back to original branch
    git checkout "$current_branch"
    
    return $([[ "$success" == true ]] && echo 0 || echo 1)
}

# Validate git repository state
validate_git_state() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: Not in a git repository"
        return 1
    fi
    
    # Check if working directory is clean
    if ! git diff-index --quiet HEAD --; then
        echo "WARNING: Working directory has uncommitted changes"
    fi
    
    # Check if we have any worktrees
    if git worktree list >/dev/null 2>&1; then
        echo "INFO: Git worktrees are supported"
    else
        echo "ERROR: Git worktrees not supported (git version too old?)"
        return 1
    fi
    
    echo "Git state is valid for Symphony operations"
    return 0
}

# Initialize git for Symphony
init_git_for_symphony() {
    echo -e "${BLUE}Initializing git for Symphony...${NC}"
    
    # Validate git state
    if ! validate_git_state; then
        return 1
    fi
    
    # Create .symphony directory structure
    mkdir -p .symphony/worktrees
    
    # Add .symphony runtime files to .gitignore
    if [[ -f ".gitignore" ]]; then
        if ! grep -q "\.symphony/worktrees" .gitignore; then
            echo "" >> .gitignore
            echo "# Symphony runtime files" >> .gitignore
            echo ".symphony/state/" >> .gitignore
            echo ".symphony/worktrees/" >> .gitignore
            echo ".symphony/logs/" >> .gitignore
            echo -e "${GREEN}✓ Added Symphony entries to .gitignore${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Git initialized for Symphony${NC}"
}