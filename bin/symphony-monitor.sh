#!/bin/bash

# Symphony Monitor - Monitor agent progress and system status

set -e

SESSION_NAME="symphony"
MONITOR_INTERVAL=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Show usage
usage() {
    echo "Usage: symphony-monitor.sh [OPTIONS]"
    echo "Options:"
    echo "  --interval N    Monitor interval in seconds (default: 5)"
    echo "  --once         Run once and exit"
    echo "  --json         Output JSON format"
    echo "  --help         Show this help"
}

# Parse arguments
ONCE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            MONITOR_INTERVAL="$2"
            shift 2
            ;;
        --once)
            ONCE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
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

# Get current task info
get_current_task() {
    if [[ -f ".symphony/state/CURRENT_TASK.json" ]]; then
        cat .symphony/state/CURRENT_TASK.json
    else
        echo '{"id": null, "state": "NONE"}'
    fi
}

# Get agent registry
get_agents() {
    if [[ -f ".symphony/state/REGISTRY.json" ]]; then
        cat .symphony/state/REGISTRY.json
    else
        echo '[]'
    fi
}

# Parse progress from PROGRESS.md file
parse_progress() {
    local progress_file="$1"
    
    if [[ ! -f "$progress_file" ]]; then
        echo '{"status": "UNKNOWN", "progress": 0, "current": "No progress file", "updated": ""}'
        return
    fi
    
    local status=$(grep "^Status:" "$progress_file" 2>/dev/null | cut -d: -f2- | xargs || echo "UNKNOWN")
    local progress=$(grep "^Progress:" "$progress_file" 2>/dev/null | cut -d: -f2- | xargs | tr -d '%' || echo "0")
    local current=$(grep "^Current:" "$progress_file" 2>/dev/null | cut -d: -f2- | xargs || echo "No current activity")
    local updated=$(grep "^Last Updated:" "$progress_file" 2>/dev/null | cut -d: -f2- | xargs || echo "")
    
    # Clean up progress number
    progress=$(echo "$progress" | grep -o '[0-9]*' | head -1)
    [[ -z "$progress" ]] && progress=0
    
    # JSON output
    cat << EOF
{
    "status": "$status",
    "progress": $progress,
    "current": "$current", 
    "updated": "$updated"
}
EOF
}

# Get all agent progress
get_all_progress() {
    local agents=$(get_agents)
    local task=$(get_current_task)
    local task_id=$(echo "$task" | jq -r '.id // "none"')
    
    echo "{"
    echo "  \"task\": $task,"
    echo "  \"agents\": ["
    
    local first=true
    if [[ "$task_id" != "none" && "$task_id" != "null" ]]; then
        for agent_dir in .symphony/tasks/${task_id}_task/agents/*/; do
            if [[ -d "$agent_dir" ]]; then
                local agent_name=$(basename "$agent_dir")
                local progress_file="$agent_dir/PROGRESS.md"
                local progress=$(parse_progress "$progress_file")
                
                [[ "$first" == false ]] && echo ","
                echo "    {"
                echo "      \"name\": \"$agent_name\","
                echo "      \"progress\": $progress"
                echo -n "    }"
                first=false
            fi
        done
    fi
    
    echo ""
    echo "  ],"
    
    # Add tmux session info
    local session_active=false
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        session_active=true
    fi
    
    echo "  \"session\": {"
    echo "    \"active\": $session_active,"
    echo "    \"name\": \"$SESSION_NAME\""
    echo "  }"
    echo "}"
}

# Display progress in human-readable format
display_progress() {
    local data=$(get_all_progress)
    local task_state=$(echo "$data" | jq -r '.task.state // "NONE"')
    local task_id=$(echo "$data" | jq -r '.task.id // "none"')
    local session_active=$(echo "$data" | jq -r '.session.active')
    
    clear
    echo -e "${BLUE}🎼 Symphony Monitor${NC} - $(date)"
    echo "================================================"
    
    # Session status
    if [[ "$session_active" == "true" ]]; then
        echo -e "Session: ${GREEN}✓ Active${NC}"
    else
        echo -e "Session: ${RED}✗ Inactive${NC}"
        echo "Run 'symphony start' to begin orchestration"
        return
    fi
    
    # Task status
    echo "Task: $task_id ($task_state)"
    echo
    
    # Agent progress
    local agent_count=$(echo "$data" | jq '.agents | length')
    if [[ "$agent_count" -gt 0 ]]; then
        echo -e "${YELLOW}Agent Progress:${NC}"
        echo "$data" | jq -r '.agents[] | "  \(.name): \(.progress.status) (\(.progress.progress)%) - \(.progress.current)"'
        echo
        
        # Overall progress
        local total_progress=$(echo "$data" | jq '[.agents[].progress.progress] | add / length')
        local completed_agents=$(echo "$data" | jq '[.agents[].progress.status] | map(select(. == "COMPLETE")) | length')
        
        echo -e "${BLUE}Overall Progress: ${total_progress}% (${completed_agents}/${agent_count} agents complete)${NC}"
    else
        echo "No active agents"
    fi
    
    echo
    echo "Last updated: $(date)"
    echo "Press Ctrl+C to exit monitor"
}

# Monitor continuously 
monitor_continuous() {
    while true; do
        if [[ "$JSON_OUTPUT" == true ]]; then
            get_all_progress
        else
            display_progress
        fi
        
        [[ "$ONCE" == true ]] && break
        sleep "$MONITOR_INTERVAL"
    done
}

# Check if we're in a git repository
if [[ ! -d ".git" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "Symphony requires a git repository to monitor."
    exit 1
fi

# Main execution
if [[ "$JSON_OUTPUT" == true ]]; then
    get_all_progress
elif [[ "$ONCE" == true ]]; then
    display_progress
else
    # Trap Ctrl+C for clean exit
    trap 'echo -e "\n${YELLOW}Monitor stopped${NC}"; exit 0' INT
    monitor_continuous
fi