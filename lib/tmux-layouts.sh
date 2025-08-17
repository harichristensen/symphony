#!/bin/bash

# Symphony tmux Layout Management
# Functions for creating and managing tmux layouts for different agent configurations

# Layout configurations
declare -A LAYOUTS

# Default 4-agent layout
LAYOUTS[default]="
# Layout: Orchestrator (top) + 4 agents (grid) + Monitor (right)
# Panes: 0=Orchestrator, 1-4=Agents, 5=Monitor
layout_default() {
    local session=\$1
    
    # Create main window
    tmux rename-window -t \"\$session:0\" \"Symphony\"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t \"\$session:0\" -h -p 25
    
    # Split main area: orchestrator (20% top) + agents (80% bottom)
    tmux split-window -t \"\$session:0.0\" -v -p 20
    
    # Split agent area into 2x2 grid
    tmux split-window -t \"\$session:0.1\" -h -p 50    # Split horizontally
    tmux split-window -t \"\$session:0.1\" -v -p 50    # Split left half vertically
    tmux split-window -t \"\$session:0.3\" -v -p 50    # Split right half vertically
    
    # Set pane titles
    tmux select-pane -t \"\$session:0.0\" -T \"Orchestrator\"
    tmux select-pane -t \"\$session:0.1\" -T \"Agent-1\"
    tmux select-pane -t \"\$session:0.2\" -T \"Agent-2\"
    tmux select-pane -t \"\$session:0.3\" -T \"Agent-3\"
    tmux select-pane -t \"\$session:0.4\" -T \"Agent-4\"
    tmux select-pane -t \"\$session:0.5\" -T \"Monitor\"
}
"

# 2-agent layout
LAYOUTS[two_agent]="
# Layout: Orchestrator (top) + 2 agents (side by side) + Monitor (right)
layout_two_agent() {
    local session=\$1
    
    tmux rename-window -t \"\$session:0\" \"Symphony\"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t \"\$session:0\" -h -p 25
    
    # Split main area: orchestrator (25% top) + agents (75% bottom)
    tmux split-window -t \"\$session:0.0\" -v -p 25
    
    # Split agent area horizontally
    tmux split-window -t \"\$session:0.1\" -h -p 50
    
    # Set pane titles
    tmux select-pane -t \"\$session:0.0\" -T \"Orchestrator\"
    tmux select-pane -t \"\$session:0.1\" -T \"Agent-1\"
    tmux select-pane -t \"\$session:0.2\" -T \"Agent-2\"
    tmux select-pane -t \"\$session:0.3\" -T \"Monitor\"
}
"

# 6-agent layout
LAYOUTS[six_agent]="
# Layout: Orchestrator (top) + 6 agents (3x2 grid) + Monitor (right)
layout_six_agent() {
    local session=\$1
    
    tmux rename-window -t \"\$session:0\" \"Symphony\"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t \"\$session:0\" -h -p 25
    
    # Split main area: orchestrator (15% top) + agents (85% bottom)
    tmux split-window -t \"\$session:0.0\" -v -p 15
    
    # Create 3x2 grid for agents
    # First row: split into 3 columns
    tmux split-window -t \"\$session:0.1\" -h -p 67    # 1/3
    tmux split-window -t \"\$session:0.2\" -h -p 50    # 1/2 of remaining
    
    # Second row: split each column vertically
    tmux split-window -t \"\$session:0.1\" -v -p 50
    tmux split-window -t \"\$session:0.2\" -v -p 50
    tmux split-window -t \"\$session:0.4\" -v -p 50
    
    # Set pane titles
    tmux select-pane -t \"\$session:0.0\" -T \"Orchestrator\"
    tmux select-pane -t \"\$session:0.1\" -T \"Agent-1\"
    tmux select-pane -t \"\$session:0.2\" -T \"Agent-2\"
    tmux select-pane -t \"\$session:0.3\" -T \"Agent-3\"
    tmux select-pane -t \"\$session:0.4\" -T \"Agent-4\"
    tmux select-pane -t \"\$session:0.5\" -T \"Agent-5\"
    tmux select-pane -t \"\$session:0.6\" -T \"Agent-6\"
    tmux select-pane -t \"\$session:0.7\" -T \"Monitor\"
}
"

# Simple layout (orchestrator + monitor only)
LAYOUTS[simple]="
# Layout: Just orchestrator and monitor
layout_simple() {
    local session=\$1
    
    tmux rename-window -t \"\$session:0\" \"Symphony\"
    
    # Split: orchestrator (70%) + monitor (30% right)
    tmux split-window -t \"\$session:0\" -h -p 30
    
    # Set pane titles
    tmux select-pane -t \"\$session:0.0\" -T \"Orchestrator\"
    tmux select-pane -t \"\$session:0.1\" -T \"Monitor\"
}
"

# Get available layouts
get_available_layouts() {
    echo "default two_agent six_agent simple"
}

# Apply layout by name
apply_layout() {
    local session="$1"
    local layout_name="${2:-default}"
    
    # Check if layout exists
    if [[ ! " $(get_available_layouts) " =~ " $layout_name " ]]; then
        echo "Error: Unknown layout '$layout_name'"
        echo "Available layouts: $(get_available_layouts)"
        return 1
    fi
    
    # Apply the layout
    case "$layout_name" in
        "default")
            layout_default "$session"
            ;;
        "two_agent")
            layout_two_agent "$session"
            ;;
        "six_agent")
            layout_six_agent "$session"
            ;;
        "simple")
            layout_simple "$session"
            ;;
    esac
    
    echo "Applied layout: $layout_name"
}

# Auto-detect optimal layout based on agent count
auto_layout() {
    local session="$1"
    local agent_count="$2"
    
    local layout="default"
    
    case "$agent_count" in
        0|1)
            layout="simple"
            ;;
        2)
            layout="two_agent"
            ;;
        3|4)
            layout="default"
            ;;
        5|6)
            layout="six_agent"
            ;;
        *)
            layout="default"
            echo "Warning: $agent_count agents requested, using default 4-agent layout"
            ;;
    esac
    
    apply_layout "$session" "$layout"
    echo "Auto-selected layout '$layout' for $agent_count agents"
}

# Get agent pane IDs for a layout
get_agent_panes() {
    local layout_name="${1:-default}"
    
    case "$layout_name" in
        "simple")
            echo ""  # No agent panes
            ;;
        "two_agent")
            echo "1 2"
            ;;
        "default")
            echo "1 2 3 4"
            ;;
        "six_agent")
            echo "1 2 3 4 5 6"
            ;;
        *)
            echo "1 2 3 4"  # Default
            ;;
    esac
}

# Get monitor pane ID for a layout
get_monitor_pane() {
    local layout_name="${1:-default}"
    
    case "$layout_name" in
        "simple")
            echo "1"
            ;;
        "two_agent")
            echo "3"
            ;;
        "default")
            echo "5"
            ;;
        "six_agent")
            echo "7"
            ;;
        *)
            echo "5"  # Default
            ;;
    esac
}

# Layout utility functions
layout_default() {
    local session="$1"
    
    tmux rename-window -t "$session:0" "Symphony"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t "$session:0" -h -p 25
    
    # Split main area: orchestrator (20% top) + agents (80% bottom)
    tmux split-window -t "$session:0.0" -v -p 20
    
    # Split agent area into 2x2 grid
    tmux split-window -t "$session:0.1" -h -p 50    # Split horizontally
    tmux split-window -t "$session:0.1" -v -p 50    # Split left half vertically
    tmux split-window -t "$session:0.3" -v -p 50    # Split right half vertically
    
    # Set pane titles
    tmux select-pane -t "$session:0.0" -T "Orchestrator"
    tmux select-pane -t "$session:0.1" -T "Agent-1"
    tmux select-pane -t "$session:0.2" -T "Agent-2"
    tmux select-pane -t "$session:0.3" -T "Agent-3"
    tmux select-pane -t "$session:0.4" -T "Agent-4"
    tmux select-pane -t "$session:0.5" -T "Monitor"
}

layout_two_agent() {
    local session="$1"
    
    tmux rename-window -t "$session:0" "Symphony"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t "$session:0" -h -p 25
    
    # Split main area: orchestrator (25% top) + agents (75% bottom)
    tmux split-window -t "$session:0.0" -v -p 25
    
    # Split agent area horizontally
    tmux split-window -t "$session:0.1" -h -p 50
    
    # Set pane titles
    tmux select-pane -t "$session:0.0" -T "Orchestrator"
    tmux select-pane -t "$session:0.1" -T "Agent-1"
    tmux select-pane -t "$session:0.2" -T "Agent-2"
    tmux select-pane -t "$session:0.3" -T "Monitor"
}

layout_six_agent() {
    local session="$1"
    
    tmux rename-window -t "$session:0" "Symphony"
    
    # Split: main area (75%) + monitor (25% right)
    tmux split-window -t "$session:0" -h -p 25
    
    # Split main area: orchestrator (15% top) + agents (85% bottom)
    tmux split-window -t "$session:0.0" -v -p 15
    
    # Create 3x2 grid for agents
    # First row: split into 3 columns
    tmux split-window -t "$session:0.1" -h -p 67    # 1/3
    tmux split-window -t "$session:0.2" -h -p 50    # 1/2 of remaining
    
    # Second row: split each column vertically
    tmux split-window -t "$session:0.1" -v -p 50
    tmux split-window -t "$session:0.2" -v -p 50
    tmux split-window -t "$session:0.4" -v -p 50
    
    # Set pane titles
    tmux select-pane -t "$session:0.0" -T "Orchestrator"
    tmux select-pane -t "$session:0.1" -T "Agent-1"
    tmux select-pane -t "$session:0.2" -T "Agent-2"
    tmux select-pane -t "$session:0.3" -T "Agent-3"
    tmux select-pane -t "$session:0.4" -T "Agent-4"
    tmux select-pane -t "$session:0.5" -T "Agent-5"
    tmux select-pane -t "$session:0.6" -T "Agent-6"
    tmux select-pane -t "$session:0.7" -T "Monitor"
}

layout_simple() {
    local session="$1"
    
    tmux rename-window -t "$session:0" "Symphony"
    
    # Split: orchestrator (70%) + monitor (30% right)
    tmux split-window -t "$session:0" -h -p 30
    
    # Set pane titles
    tmux select-pane -t "$session:0.0" -T "Orchestrator"
    tmux select-pane -t "$session:0.1" -T "Monitor"
}