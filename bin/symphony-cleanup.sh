#!/bin/bash

# Symphony Cleanup - Clean up worktrees, sessions, and state files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Show usage
usage() {
    echo "Usage: symphony-cleanup.sh [OPTIONS]"
    echo "Options:"
    echo "  --all          Clean everything (sessions, worktrees, state, logs)"
    echo "  --sessions     Clean only tmux sessions"
    echo "  --worktrees    Clean only git worktrees"
    echo "  --state        Clean only state files"
    echo "  --logs         Clean only log files"
    echo "  --force        Force cleanup without prompts"
    echo "  --help         Show this help"
}

# Default cleanup options
CLEAN_SESSIONS=false
CLEAN_WORKTREES=false
CLEAN_STATE=false
CLEAN_LOGS=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEAN_SESSIONS=true
            CLEAN_WORKTREES=true
            CLEAN_STATE=true
            CLEAN_LOGS=true
            shift
            ;;
        --sessions)
            CLEAN_SESSIONS=true
            shift
            ;;
        --worktrees)
            CLEAN_WORKTREES=true
            shift
            ;;
        --state)
            CLEAN_STATE=true
            shift
            ;;
        --logs)
            CLEAN_LOGS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# If no specific options, default to all
if [[ "$CLEAN_SESSIONS" == false && "$CLEAN_WORKTREES" == false && "$CLEAN_STATE" == false && "$CLEAN_LOGS" == false ]]; then
    CLEAN_SESSIONS=true
    CLEAN_WORKTREES=true
    CLEAN_STATE=true
    CLEAN_LOGS=true
fi

# Confirmation prompt
confirm_cleanup() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}Symphony Cleanup${NC}"
    echo "This will clean up:"
    [[ "$CLEAN_SESSIONS" == true ]] && echo "  - tmux sessions"
    [[ "$CLEAN_WORKTREES" == true ]] && echo "  - git worktrees"
    [[ "$CLEAN_STATE" == true ]] && echo "  - state files"
    [[ "$CLEAN_LOGS" == true ]] && echo "  - log files"
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled"
        exit 0
    fi
}

# Clean tmux sessions
cleanup_sessions() {
    if [[ "$CLEAN_SESSIONS" != true ]]; then
        return
    fi
    
    echo -e "${BLUE}Cleaning tmux sessions...${NC}"
    
    # Kill symphony session if it exists
    if tmux has-session -t symphony 2>/dev/null; then
        tmux kill-session -t symphony
        echo -e "${GREEN}✓ Killed symphony session${NC}"
    else
        echo "No symphony session to clean"
    fi
    
    # Clean any orphaned symphony sessions
    local symphony_sessions
    symphony_sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^symphony' || true)
    if [[ -n "$symphony_sessions" ]]; then
        echo "$symphony_sessions" | while read -r session; do
            tmux kill-session -t "$session"
            echo -e "${GREEN}✓ Killed session: $session${NC}"
        done
    fi
}

# Clean git worktrees
cleanup_worktrees() {
    if [[ "$CLEAN_WORKTREES" != true ]]; then
        return
    fi
    
    echo -e "${BLUE}Cleaning git worktrees...${NC}"
    
    if [[ ! -d ".symphony/worktrees" ]]; then
        echo "No worktrees directory found"
        return
    fi
    
    # Remove all worktrees in the symphony directory
    for worktree in .symphony/worktrees/*/; do
        if [[ -d "$worktree" ]]; then
            local worktree_name
            worktree_name=$(basename "$worktree")
            echo "Removing worktree: $worktree_name"
            
            # Try git worktree remove first
            if git worktree remove "$worktree" 2>/dev/null; then
                echo -e "${GREEN}✓ Removed worktree: $worktree_name${NC}"
            else
                # Force remove if git worktree remove fails
                echo -e "${YELLOW}Git worktree remove failed, force removing directory${NC}"
                rm -rf "$worktree"
                echo -e "${GREEN}✓ Force removed: $worktree_name${NC}"
            fi
        fi
    done
    
    # Clean up orphaned worktree references
    git worktree prune 2>/dev/null || true
    
    # Remove empty worktrees directory
    if [[ -d ".symphony/worktrees" ]]; then
        rmdir .symphony/worktrees 2>/dev/null || true
    fi
    
    # Clean up symphony branches
    echo "Cleaning symphony branches..."
    local symphony_branches
    symphony_branches=$(git branch | grep 'symphony/' || true)
    if [[ -n "$symphony_branches" ]]; then
        echo "$symphony_branches" | while read -r branch; do
            local branch_name
            branch_name=$(echo "$branch" | xargs)  # trim whitespace
            git branch -D "$branch_name" 2>/dev/null && echo -e "${GREEN}✓ Deleted branch: $branch_name${NC}" || true
        done
    fi
}

# Clean state files
cleanup_state() {
    if [[ "$CLEAN_STATE" != true ]]; then
        return
    fi
    
    echo -e "${BLUE}Cleaning state files...${NC}"
    
    # Clean current task and registry
    if [[ -f ".symphony/state/CURRENT_TASK.json" ]]; then
        rm ".symphony/state/CURRENT_TASK.json"
        echo -e "${GREEN}✓ Removed CURRENT_TASK.json${NC}"
    fi
    
    if [[ -f ".symphony/state/REGISTRY.json" ]]; then
        rm ".symphony/state/REGISTRY.json"
        echo -e "${GREEN}✓ Removed REGISTRY.json${NC}"
    fi
    
    # Reset queue to empty
    if [[ -f ".symphony/state/QUEUE.json" ]]; then
        echo '{"tasks": [], "current": null, "completed": []}' > .symphony/state/QUEUE.json
        echo -e "${GREEN}✓ Reset QUEUE.json${NC}"
    fi
    
    # Clean task directories (keeping structure)
    if [[ -d ".symphony/tasks" ]]; then
        find .symphony/tasks -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
        echo -e "${GREEN}✓ Cleaned task directories${NC}"
    fi
}

# Clean log files
cleanup_logs() {
    if [[ "$CLEAN_LOGS" != true ]]; then
        return
    fi
    
    echo -e "${BLUE}Cleaning log files...${NC}"
    
    if [[ -d ".symphony/logs" ]]; then
        rm -f .symphony/logs/*.log
        echo -e "${GREEN}✓ Cleaned log files${NC}"
    else
        echo "No logs directory found"
    fi
}

# Check if we're in a git repository with symphony
if [[ ! -d ".git" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "Run this from the root of your git repository."
    exit 1
fi

if [[ ! -d ".symphony" ]]; then
    echo -e "${YELLOW}No .symphony directory found${NC}"
    echo "Nothing to clean up."
    exit 0
fi

# Confirm and execute cleanup
confirm_cleanup

echo -e "${BLUE}🎼 Starting Symphony cleanup...${NC}"
echo

cleanup_sessions
cleanup_worktrees
cleanup_state
cleanup_logs

echo
echo -e "${GREEN}🎉 Symphony cleanup complete!${NC}"

# Show what remains
if [[ -d ".symphony" ]]; then
    echo
    echo "Remaining Symphony files:"
    find .symphony -type f 2>/dev/null | head -10 || echo "None"
    
    # Check if .symphony is empty
    if [[ -z "$(find .symphony -type f 2>/dev/null)" ]]; then
        echo -e "${YELLOW}The .symphony directory is now empty${NC}"
        read -p "Remove .symphony directory entirely? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf .symphony
            echo -e "${GREEN}✓ Removed .symphony directory${NC}"
        fi
    fi
fi