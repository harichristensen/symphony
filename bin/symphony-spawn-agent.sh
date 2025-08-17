#!/bin/bash

# Symphony Agent Spawner - Spawn Claude Code agents in tmux panes with git worktrees

set -e

AGENT_TYPE="$1"
TASK_ID="$2"
PANE_ID="$3"
SESSION_NAME="symphony"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SYMPHONY_LIB="$HOME/.symphony/lib"
source "$SYMPHONY_LIB/git-operations.sh" 2>/dev/null || true
source "$SYMPHONY_LIB/agent-prompts.sh" 2>/dev/null || true

# Usage
usage() {
    echo "Usage: symphony-spawn-agent.sh <agent_type> <task_id> <pane_id>"
    echo "Example: symphony-spawn-agent.sh frontend-agent 1642334567 1"
}

# Validate inputs
if [[ -z "$AGENT_TYPE" || -z "$TASK_ID" || -z "$PANE_ID" ]]; then
    usage
    exit 1
fi

# Generate unique agent ID
AGENT_ID="${AGENT_TYPE}-$(date +%s)"
WORKTREE_PATH=".symphony/worktrees/$AGENT_ID"
TASK_DIR=".symphony/tasks/${TASK_ID}_task"
AGENT_DIR="$TASK_DIR/agents/$AGENT_TYPE"

echo -e "${BLUE}Spawning $AGENT_TYPE in pane $PANE_ID...${NC}"

# Create agent directory
mkdir -p "$AGENT_DIR"

# Create git worktree
create_agent_worktree() {
    echo "Creating git worktree for $AGENT_ID..."
    
    # Create worktree from current branch
    local current_branch
    current_branch=$(git branch --show-current)
    local agent_branch="symphony/${TASK_ID}/${AGENT_TYPE}"
    
    # Create new branch for this agent
    git checkout -b "$agent_branch" 2>/dev/null || git checkout "$agent_branch"
    
    # Create worktree
    git worktree add "$WORKTREE_PATH" "$agent_branch"
    
    # Switch back to original branch
    git checkout "$current_branch"
    
    echo -e "${GREEN}✓ Created worktree: $WORKTREE_PATH${NC}"
}

# Generate agent prompt
generate_agent_prompt() {
    local config_dirs=""
    
    # Read directories from config for this agent type
    if [[ -f "symphony.config.yml" ]]; then
        # Simple grep-based parsing (could be improved with yq)
        local in_agent_section=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*${AGENT_TYPE}:[[:space:]]*$ ]]; then
                in_agent_section=true
            elif [[ "$line" =~ ^[[:space:]]*[^[:space:]]+:[[:space:]]*$ ]] && [[ "$in_agent_section" == true ]]; then
                in_agent_section=false
            elif [[ "$in_agent_section" == true ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*[\'\"]*([^\'\"]+)[\'\"]*[[:space:]]*$ ]]; then
                local dir="${BASH_REMATCH[1]}"
                config_dirs="$config_dirs$dir "
            fi
        done < symphony.config.yml
    fi
    
    cat << EOF
You are a specialized $AGENT_TYPE for the Symphony orchestration system.

ROLE: $AGENT_TYPE
TASK_ID: $TASK_ID  
WORKING_DIRECTORY: $WORKTREE_PATH
ASSIGNED_DIRECTORIES: $config_dirs

Your responsibilities:
1. Read the task requirements from $TASK_DIR/TASK.md
2. Work only on files in your assigned directories: $config_dirs
3. Write progress updates to $AGENT_DIR/PROGRESS.md every 5-10 minutes
4. Commit your changes to your branch when complete
5. Update STATUS to COMPLETE in PROGRESS.md when done

IMPORTANT CONSTRAINTS:
- Only edit files in your assigned directories
- Do not modify shared files without coordination
- Report progress regularly using this format:

\`\`\`markdown
# PROGRESS.md
Status: IN_PROGRESS
Progress: 45%
Current: Implementing authentication components
Last Updated: $(date -Iseconds)

## Completed
- Created login form component
- Added form validation

## In Progress  
- Implementing JWT token handling

## Next Steps
- Add logout functionality
- Write unit tests
\`\`\`

When complete, set Status to COMPLETE and commit all changes.

Start by reading the task requirements and creating your initial PROGRESS.md file.
EOF
}

# Start agent in tmux pane
start_agent() {
    # Create worktree first
    create_agent_worktree
    
    # Generate prompt
    local agent_prompt
    agent_prompt=$(generate_agent_prompt)
    
    # Update agent registry
    local registry_entry
    registry_entry="{\"id\": \"$AGENT_ID\", \"type\": \"$AGENT_TYPE\", \"worktree\": \"$WORKTREE_PATH\", \"task\": \"$TASK_ID\", \"pane\": \"$PANE_ID\", \"started\": \"$(date -Iseconds)\"}"
    
    if [[ -f ".symphony/state/REGISTRY.json" ]]; then
        # Add to existing registry (simple append - could be improved)
        local temp_file
        temp_file=$(mktemp)
        jq ". + [$registry_entry]" .symphony/state/REGISTRY.json > "$temp_file" && mv "$temp_file" .symphony/state/REGISTRY.json
    else
        echo "[$registry_entry]" > .symphony/state/REGISTRY.json
    fi
    
    # Switch to target pane
    tmux select-pane -t "$SESSION_NAME:0.$PANE_ID"
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "clear" Enter
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "echo 'Symphony Agent: $AGENT_TYPE'" Enter
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "echo 'Agent ID: $AGENT_ID'" Enter
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "echo 'Worktree: $WORKTREE_PATH'" Enter
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "echo ''" Enter
    
    # Change to agent worktree
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "cd $WORKTREE_PATH" Enter
    
    # Start Claude Code with agent prompt
    tmux send-keys -t "$SESSION_NAME:0.$PANE_ID" "claude --task '$agent_prompt'" Enter
    
    echo -e "${GREEN}✓ Started $AGENT_TYPE in pane $PANE_ID${NC}"
    echo "Agent ID: $AGENT_ID"
    echo "Worktree: $WORKTREE_PATH"
}

# Check if tmux session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo -e "${RED}Error: No Symphony session found${NC}"
    echo "Start the orchestrator first with 'symphony start'"
    exit 1
fi

# Check if pane exists
if ! tmux display-message -t "$SESSION_NAME:0.$PANE_ID" -p 2>/dev/null; then
    echo -e "${RED}Error: Pane $PANE_ID does not exist${NC}"
    exit 1
fi

# Start the agent
start_agent

echo -e "${GREEN}🎉 Agent $AGENT_TYPE spawned successfully!${NC}"