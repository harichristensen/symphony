#!/bin/bash

# Symphony Progress Parser
# Functions for parsing and analyzing agent progress from PROGRESS.md files

# Parse a single PROGRESS.md file
parse_progress_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "ERROR: Progress file not found: $file_path" >&2
        return 1
    fi
    
    local status=$(grep "^Status:" "$file_path" 2>/dev/null | cut -d: -f2- | xargs)
    local progress=$(grep "^Progress:" "$file_path" 2>/dev/null | cut -d: -f2- | xargs | tr -d '%' | grep -o '[0-9]*')
    local current=$(grep "^Current:" "$file_path" 2>/dev/null | cut -d: -f2- | xargs)
    local updated=$(grep "^Last Updated:" "$file_path" 2>/dev/null | cut -d: -f2- | xargs)
    
    # Default values
    status="${status:-UNKNOWN}"
    progress="${progress:-0}"
    current="${current:-No current activity}"
    updated="${updated:-Never}"
    
    # Return JSON
    cat << EOF
{
    "status": "$status",
    "progress": $progress,
    "current": "$current",
    "updated": "$updated",
    "file": "$file_path"
}
EOF
}

# Parse progress for all agents in a task
parse_task_progress() {
    local task_id="$1"
    local task_dir=".symphony/tasks/${task_id}_task"
    
    if [[ ! -d "$task_dir" ]]; then
        echo "ERROR: Task directory not found: $task_dir" >&2
        return 1
    fi
    
    echo "{"
    echo "  \"task_id\": \"$task_id\","
    echo "  \"agents\": ["
    
    local first=true
    for agent_dir in "$task_dir/agents/"*/; do
        if [[ -d "$agent_dir" ]]; then
            local agent_name=$(basename "$agent_dir")
            local progress_file="$agent_dir/PROGRESS.md"
            
            [[ "$first" == false ]] && echo ","
            
            if [[ -f "$progress_file" ]]; then
                local agent_progress=$(parse_progress_file "$progress_file")
                echo "    {"
                echo "      \"name\": \"$agent_name\","
                echo "      \"progress\": $agent_progress"
                echo -n "    }"
            else
                echo "    {"
                echo "      \"name\": \"$agent_name\","
                echo "      \"progress\": {"
                echo "        \"status\": \"NO_PROGRESS_FILE\","
                echo "        \"progress\": 0,"
                echo "        \"current\": \"No progress file found\","
                echo "        \"updated\": \"Never\","
                echo "        \"file\": \"$progress_file\""
                echo "      }"
                echo -n "    }"
            fi
            first=false
        fi
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Get overall task statistics
get_task_stats() {
    local task_id="$1"
    local progress_data=$(parse_task_progress "$task_id")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local total_agents=$(echo "$progress_data" | jq '.agents | length')
    local completed_agents=$(echo "$progress_data" | jq '[.agents[].progress.status] | map(select(. == "COMPLETE")) | length')
    local failed_agents=$(echo "$progress_data" | jq '[.agents[].progress.status] | map(select(. == "FAILED")) | length')
    local blocked_agents=$(echo "$progress_data" | jq '[.agents[].progress.status] | map(select(. == "BLOCKED")) | length')
    local active_agents=$(echo "$progress_data" | jq '[.agents[].progress.status] | map(select(. == "IN_PROGRESS")) | length')
    
    # Calculate average progress
    local avg_progress=0
    if [[ "$total_agents" -gt 0 ]]; then
        avg_progress=$(echo "$progress_data" | jq '[.agents[].progress.progress] | add / length')
    fi
    
    cat << EOF
{
    "task_id": "$task_id",
    "total_agents": $total_agents,
    "completed_agents": $completed_agents,
    "failed_agents": $failed_agents,
    "blocked_agents": $blocked_agents,
    "active_agents": $active_agents,
    "average_progress": $avg_progress,
    "overall_status": "$(get_overall_status "$completed_agents" "$failed_agents" "$blocked_agents" "$total_agents")"
}
EOF
}

# Determine overall task status
get_overall_status() {
    local completed="$1"
    local failed="$2"
    local blocked="$3"
    local total="$4"
    
    if [[ "$total" -eq 0 ]]; then
        echo "NO_AGENTS"
    elif [[ "$failed" -gt 0 ]]; then
        echo "FAILED"
    elif [[ "$blocked" -gt 0 ]]; then
        echo "BLOCKED"
    elif [[ "$completed" -eq "$total" ]]; then
        echo "COMPLETE"
    elif [[ "$completed" -gt 0 ]]; then
        echo "IN_PROGRESS"
    else
        echo "PENDING"
    fi
}

# Check if agent is stale (no updates for too long)
check_agent_staleness() {
    local progress_file="$1"
    local timeout_minutes="${2:-30}"  # Default 30 minute timeout
    
    if [[ ! -f "$progress_file" ]]; then
        echo "STALE"
        return
    fi
    
    local updated=$(grep "^Last Updated:" "$progress_file" 2>/dev/null | cut -d: -f2- | xargs)
    
    if [[ -z "$updated" ]]; then
        echo "STALE"
        return
    fi
    
    # Convert to epoch time for comparison
    local updated_epoch
    if command -v gdate >/dev/null 2>&1; then
        # macOS with GNU coreutils
        updated_epoch=$(gdate -d "$updated" +%s 2>/dev/null)
    else
        # Linux date
        updated_epoch=$(date -d "$updated" +%s 2>/dev/null)
    fi
    
    if [[ -z "$updated_epoch" ]]; then
        echo "STALE"
        return
    fi
    
    local current_epoch=$(date +%s)
    local diff_minutes=$(( (current_epoch - updated_epoch) / 60 ))
    
    if [[ "$diff_minutes" -gt "$timeout_minutes" ]]; then
        echo "STALE"
    else
        echo "ACTIVE"
    fi
}

# Find stale agents across all tasks
find_stale_agents() {
    local timeout_minutes="${1:-30}"
    
    echo "{"
    echo "  \"stale_agents\": ["
    
    local first=true
    for task_dir in .symphony/tasks/*/; do
        if [[ -d "$task_dir" ]]; then
            local task_id=$(basename "$task_dir" | sed 's/_task$//')
            
            for agent_dir in "$task_dir/agents/"*/; do
                if [[ -d "$agent_dir" ]]; then
                    local agent_name=$(basename "$agent_dir")
                    local progress_file="$agent_dir/PROGRESS.md"
                    local staleness=$(check_agent_staleness "$progress_file" "$timeout_minutes")
                    
                    if [[ "$staleness" == "STALE" ]]; then
                        [[ "$first" == false ]] && echo ","
                        echo "    {"
                        echo "      \"task_id\": \"$task_id\","
                        echo "      \"agent_name\": \"$agent_name\","
                        echo "      \"progress_file\": \"$progress_file\","
                        echo "      \"timeout_minutes\": $timeout_minutes"
                        echo -n "    }"
                        first=false
                    fi
                fi
            done
        fi
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Extract specific sections from progress file
extract_progress_section() {
    local file_path="$1"
    local section="$2"  # completed, in_progress, next_steps, blockers, notes
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    case "$section" in
        "completed")
            sed -n '/^## Completed/,/^## /p' "$file_path" | sed '1d;$d' | sed 's/^- //'
            ;;
        "in_progress")
            sed -n '/^## In Progress/,/^## /p' "$file_path" | sed '1d;$d' | sed 's/^- //'
            ;;
        "next_steps")
            sed -n '/^## Next Steps/,/^## /p' "$file_path" | sed '1d;$d' | sed 's/^- //'
            ;;
        "blockers")
            sed -n '/^## Blockers/,/^## /p' "$file_path" | sed '1d;$d' | sed 's/^- //'
            ;;
        "notes")
            sed -n '/^## Notes/,/^## /p' "$file_path" | sed '1d;$d' | sed 's/^- //'
            ;;
        *)
            echo "Unknown section: $section"
            return 1
            ;;
    esac
}

# Generate progress summary for display
generate_progress_summary() {
    local task_id="$1"
    local format="${2:-text}"  # text or json
    
    local stats=$(get_task_stats "$task_id")
    local progress_data=$(parse_task_progress "$task_id")
    
    if [[ "$format" == "json" ]]; then
        echo "{"
        echo "  \"stats\": $stats,"
        echo "  \"agents\": $(echo "$progress_data" | jq '.agents')"
        echo "}"
    else
        # Text format
        local total=$(echo "$stats" | jq -r '.total_agents')
        local completed=$(echo "$stats" | jq -r '.completed_agents')
        local avg_progress=$(echo "$stats" | jq -r '.average_progress')
        local overall_status=$(echo "$stats" | jq -r '.overall_status')
        
        echo "Task $task_id Progress Summary"
        echo "Status: $overall_status"
        echo "Agents: $completed/$total complete"
        echo "Average Progress: ${avg_progress}%"
        echo
        echo "Agent Details:"
        echo "$progress_data" | jq -r '.agents[] | "  \(.name): \(.progress.status) (\(.progress.progress)%) - \(.progress.current)"'
    fi
}

# Validate progress file format
validate_progress_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "ERROR: File does not exist"
        return 1
    fi
    
    local errors=()
    
    # Check required fields
    if ! grep -q "^Status:" "$file_path"; then
        errors+=("Missing 'Status:' field")
    fi
    
    if ! grep -q "^Progress:" "$file_path"; then
        errors+=("Missing 'Progress:' field")
    fi
    
    if ! grep -q "^Current:" "$file_path"; then
        errors+=("Missing 'Current:' field")
    fi
    
    if ! grep -q "^Last Updated:" "$file_path"; then
        errors+=("Missing 'Last Updated:' field")
    fi
    
    # Check status value
    local status=$(grep "^Status:" "$file_path" | cut -d: -f2- | xargs)
    if [[ ! "$status" =~ ^(PENDING|IN_PROGRESS|COMPLETE|BLOCKED|FAILED)$ ]]; then
        errors+=("Invalid status value: '$status'")
    fi
    
    # Check progress value
    local progress=$(grep "^Progress:" "$file_path" | cut -d: -f2- | xargs | tr -d '%')
    if ! [[ "$progress" =~ ^[0-9]+$ ]] || [[ "$progress" -lt 0 ]] || [[ "$progress" -gt 100 ]]; then
        errors+=("Invalid progress value: '$progress'")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        echo "VALID"
        return 0
    else
        echo "INVALID"
        printf '%s\n' "${errors[@]}"
        return 1
    fi
}