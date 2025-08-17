#!/bin/bash

# Symphony Orchestrator - Main tmux orchestration script
# Manages tmux sessions and spawns Claude Code agents

set -e

SYMPHONY_LIB="$HOME/.symphony/lib"
TASK_DESCRIPTION="$1"
SESSION_NAME="symphony"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Source library functions
source "$SYMPHONY_LIB/tmux-layouts.sh" 2>/dev/null || true
source "$SYMPHONY_LIB/agent-prompts.sh" 2>/dev/null || true
source "$SYMPHONY_LIB/git-operations.sh" 2>/dev/null || true

# Cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Orchestrator stopping...${NC}"
    # Don't kill session here - let user decide
}
trap cleanup EXIT

# Initialize task
init_task() {
    local task_id
    task_id=$(date +%s)
    local task_dir=".symphony/tasks/${task_id}_task"
    
    mkdir -p "$task_dir/agents"
    
    # Create task file
    cat > "$task_dir/TASK.md" << EOF
# Task: $TASK_DESCRIPTION

**Created:** $(date -Iseconds)
**ID:** $task_id

## Description
$TASK_DESCRIPTION

## Status
Planning phase - analyzing requirements and determining agent assignments.
EOF
    
    # Update state
    echo "{\"id\": \"$task_id\", \"state\": \"PLANNING\", \"started\": \"$(date -Iseconds)\", \"agents\": []}" > .symphony/state/CURRENT_TASK.json
    
    echo "$task_id"
}

# Create tmux session with layout
create_session() {
    echo -e "${BLUE}Creating tmux session: $SESSION_NAME${NC}"
    
    # Create new session detached
    tmux new-session -d -s "$SESSION_NAME" -c "$(pwd)"
    
    # Set up layout: orchestrator + agents + monitor
    tmux rename-window -t "$SESSION_NAME:0" "Symphony"
    
    # Split into main layout
    tmux split-window -t "$SESSION_NAME:0" -h -p 25  # Monitor pane (25% right)
    tmux split-window -t "$SESSION_NAME:0.0" -v -p 20  # Orchestrator (20% top of left)
    
    # Split bottom left into agent panes (grid)
    tmux split-window -t "$SESSION_NAME:0.1" -h -p 50  # Split bottom horizontally
    tmux split-window -t "$SESSION_NAME:0.1" -v -p 50  # Split left bottom vertically
    tmux split-window -t "$SESSION_NAME:0.3" -v -p 50  # Split right bottom vertically
    
    # Name the panes
    tmux select-pane -t "$SESSION_NAME:0.0" -T "Orchestrator"
    tmux select-pane -t "$SESSION_NAME:0.1" -T "Agent-1"
    tmux select-pane -t "$SESSION_NAME:0.2" -T "Agent-2" 
    tmux select-pane -t "$SESSION_NAME:0.3" -T "Agent-3"
    tmux select-pane -t "$SESSION_NAME:0.4" -T "Agent-4"
    tmux select-pane -t "$SESSION_NAME:0.5" -T "Monitor"
    
    # Start monitor in right pane
    tmux send-keys -t "$SESSION_NAME:0.5" "echo 'Symphony Monitor'; echo ''; watch -n 5 'date; echo; if [ -d .symphony/tasks ]; then find .symphony/tasks -name \"PROGRESS.md\" -exec echo \"--- {} ---\" \\; -exec cat {} \\; -exec echo \\; 2>/dev/null | head -50; else echo \"No active tasks\"; fi'" Enter
    
    echo -e "${GREEN}✓ tmux session created with layout${NC}"
}

# Start orchestrator in main pane
start_orchestrator() {
    local task_id="$1"
    local task_desc="$2"
    
    echo -e "${BLUE}Starting orchestrator agent...${NC}"
    
    # Switch to orchestrator pane and start Claude
    tmux select-pane -t "$SESSION_NAME:0.0"
    tmux send-keys -t "$SESSION_NAME:0.0" "clear" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "echo 'Symphony Orchestrator - Task $task_id'" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "echo 'Task: $task_desc'" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "echo ''" Enter
    
    # Generate orchestrator prompt
    local orchestrator_prompt
    orchestrator_prompt=$(generate_orchestrator_prompt "$task_id" "$task_desc")
    
    # Start Claude Code with orchestrator prompt
    tmux send-keys -t "$SESSION_NAME:0.0" "claude --task '$orchestrator_prompt'" Enter
    
    echo -e "${GREEN}✓ Orchestrator agent started${NC}"
}

# Show interactive prompt in orchestrator pane
show_orchestrator_prompt() {
    echo -e "${BLUE}Setting up orchestrator console...${NC}"
    
    # Switch to orchestrator pane
    tmux select-pane -t "$SESSION_NAME:0.0"
    tmux send-keys -t "$SESSION_NAME:0.0" "clear" Enter
    
    # Start the interactive console script
    if [[ -f "$SYMPHONY_BIN/symphony-console.sh" ]]; then
        tmux send-keys -t "$SESSION_NAME:0.0" "$SYMPHONY_BIN/symphony-console.sh" Enter
    else
        # Fallback if console script doesn't exist
        tmux send-keys -t "$SESSION_NAME:0.0" "echo '🎼 Symphony Orchestrator Console'" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo '================================'" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo ''" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo 'Welcome to Symphony! The tmux session is ready.'" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo ''" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo 'Console script not found. Please check installation.'" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "echo ''" Enter
        tmux send-keys -t "$SESSION_NAME:0.0" "bash" Enter
    fi
    
    echo -e "${GREEN}✓ Orchestrator console ready${NC}"
}

# Generate orchestrator prompt
generate_orchestrator_prompt() {
    local task_id="$1"
    local task_desc="$2"
    
    cat << EOF
You are the Symphony Orchestrator agent. Your role is to analyze tasks and coordinate multiple Claude Code agents working in parallel.

TASK: $task_desc
TASK_ID: $task_id

Your responsibilities:
1. Analyze the task and determine which agents are needed (frontend, backend, database, test, etc.)
2. Read symphony.config.yml to understand agent lane assignments
3. Create git worktrees for each agent using symphony-spawn-agent.sh
4. Monitor agent progress by reading PROGRESS.md files
5. Coordinate integration when agents complete their work
6. Manage human approval gates

Current working directory: $(pwd)
Task directory: .symphony/tasks/${task_id}_task/

Start by:
1. Reading symphony.config.yml to understand the project structure
2. Analyzing what directories will be affected by: $task_desc
3. Creating a detailed plan for agent assignments
4. Asking for human approval before spawning agents

Write your analysis and plan to .symphony/tasks/${task_id}_task/STATE.json when ready.
EOF
}

# Main orchestrator flow
main() {
    # Optional task description from command line
    local initial_task="$1"
    
    # Check if already running
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Symphony session already exists${NC}"
        echo "Attaching to existing session..."
        exec tmux attach-session -t "$SESSION_NAME"
    fi
    
    echo -e "${BLUE}🎼 Symphony Orchestrator Starting${NC}"
    if [[ -n "$initial_task" ]]; then
        echo "Initial task provided: $initial_task"
        echo "(You can start this task from the orchestrator console)"
    fi
    echo
    
    # Create tmux session
    create_session
    
    # Show interactive prompt instead of starting orchestrator
    show_orchestrator_prompt
    
    # If initial task was provided, prepare the start command in the prompt
    if [[ -n "$initial_task" ]]; then
        # Wait a moment for console to load, then pre-fill the command
        sleep 1
        tmux send-keys -t "$SESSION_NAME:0.0" "start \"$initial_task\""
        echo
        echo -e "${YELLOW}Task command prepared in orchestrator console.${NC}"
        echo "Press Enter in the orchestrator pane to start the task."
    fi
    
    echo
    echo -e "${GREEN}🎉 Symphony session created!${NC}"
    echo
    echo "Commands:"
    echo "  symphony attach   - Attach to tmux session"
    echo "  symphony status   - Check status"
    echo "  symphony stop     - Stop orchestrator"
    echo
    echo "The orchestrator console is ready and waiting for your commands."
    echo "Use 'symphony attach' to interact with the orchestrator."
    
    # Keep script running briefly
    sleep 2
}

main "$@"