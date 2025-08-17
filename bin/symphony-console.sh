#!/bin/bash

# Symphony Console - Interactive command handler for orchestrator pane

set -e

SESSION_NAME="symphony"
SYMPHONY_BIN="$HOME/.symphony/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize task for 'start' command
init_task() {
    local task_desc="$1"
    local task_id
    task_id=$(date +%s)
    local task_dir=".symphony/tasks/${task_id}_task"
    
    mkdir -p "$task_dir/agents"
    
    # Create task file
    cat > "$task_dir/TASK.md" << EOF
# Task: $task_desc

**Created:** $(date -Iseconds)
**ID:** $task_id

## Description
$task_desc

## Status
Planning phase - analyzing requirements and determining agent assignments.
EOF
    
    # Update state
    echo "{\"id\": \"$task_id\", \"state\": \"PLANNING\", \"started\": \"$(date -Iseconds)\", \"agents\": []}" > .symphony/state/CURRENT_TASK.json
    
    echo "$task_id"
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

# Handle 'start' command
handle_start() {
    local task_desc="$1"
    
    if [[ -z "$task_desc" ]]; then
        echo -e "${RED}Error: Please provide a task description${NC}"
        echo "Usage: start \"Your task description here\""
        return 1
    fi
    
    echo -e "${BLUE}Starting orchestrator with task: $task_desc${NC}"
    
    # Initialize task
    local task_id
    task_id=$(init_task "$task_desc")
    echo -e "${GREEN}✓ Task initialized with ID: $task_id${NC}"
    
    # Generate orchestrator prompt
    local orchestrator_prompt
    orchestrator_prompt=$(generate_orchestrator_prompt "$task_id" "$task_desc")
    
    # Start Claude Code with orchestrator prompt
    echo -e "${BLUE}Launching Claude Code orchestrator...${NC}"
    claude --task "$orchestrator_prompt"
}

# Handle 'analyze' command
handle_analyze() {
    echo -e "${BLUE}Analyzing repository structure...${NC}"
    
    local analyze_prompt="Analyze the current git repository structure and symphony.config.yml. 
Provide a summary of:
1. Project structure and main directories
2. Agent lane assignments from symphony.config.yml
3. Technology stack detected
4. Suggestions for task decomposition

Do not start any tasks, just provide analysis."
    
    claude --task "$analyze_prompt"
}

# Show help
show_help() {
    echo -e "${BLUE}🎼 Symphony Console Commands${NC}"
    echo
    echo "Available commands:"
    echo "  start <task>    - Start orchestrator with a task description"
    echo "  analyze         - Analyze the current repository"
    echo "  help            - Show this help message"
    echo "  exit            - Exit Symphony console"
    echo
    echo "Examples:"
    echo "  start \"Add user authentication system\""
    echo "  start \"Fix bug in payment processing\""
    echo "  analyze"
}

# Main console loop
main() {
    echo -e "${BLUE}🎼 Symphony Orchestrator Console${NC}"
    echo "================================"
    echo
    echo "Welcome to Symphony! The tmux session is ready."
    echo
    show_help
    echo
    
    while true; do
        echo -n "symphony> "
        read -r cmd args
        
        case "$cmd" in
            "start")
                # Get everything after 'start' as the task description
                # Remove leading/trailing quotes if present
                task_desc="${args#\"}"
                task_desc="${task_desc%\"}"
                handle_start "$task_desc"
                ;;
            "analyze")
                handle_analyze
                ;;
            "help")
                show_help
                ;;
            "exit"|"quit")
                echo "Exiting Symphony console..."
                exit 0
                ;;
            "")
                # Empty command, just show prompt again
                ;;
            *)
                echo -e "${RED}Unknown command: $cmd${NC}"
                echo "Type 'help' for available commands"
                ;;
        esac
    done
}

main "$@"