# Symphony with tmux for Parallel Agent Execution

I'll implement Symphony using tmux to enable true simultaneous execution of multiple Claude Code agents. Here's the implementation plan:

## Phase 1: Core tmux Orchestration Scripts

### 1. Create symphony orchestration scripts:
- `symphony-orchestrator.sh` - Main orchestrator that manages tmux sessions
- `symphony-spawn-agent.sh` - Helper to spawn individual agents in tmux panes
- `symphony-monitor.sh` - Monitor agent progress across all panes
- `symphony-cleanup.sh` - Clean up tmux sessions and worktrees

### 2. Implement tmux session management:
Create main symphony session with layout:
- Pane 0: Orchestrator (top)
- Pane 1-4: Agent panes (bottom grid)
- Pane 5: Monitor/logs (right side)

### 3. Create agent spawning logic:
- Parse task to determine required agents
- Create git worktrees for each agent
- Launch Claude Code in separate tmux panes
- Pass agent-specific prompts and working directories

## Phase 2: Symphony Command Interface

### 4. Build symphony CLI commands:
- `symphony init` - Initialize tmux session and config
- `symphony start <task>` - Start parallel agents for a task
- `symphony status` - Show status of all running agents
- `symphony attach` - Attach to tmux session to view agents
- `symphony stop` - Gracefully stop all agents
- `symphony logs <agent>` - View specific agent output

### 5. Implement configuration loader:
- Parse `symphony.config.yml` for agent lanes
- Determine agent assignments based on directories
- Configure tmux layout based on number of agents

## Phase 3: Agent Communication System

### 6. Create file-based communication:
- Agents write to `PROGRESS.md` files
- Orchestrator monitors these files for updates
- State synchronization through `STATE.json`
- Lock files to prevent race conditions

### 7. Build progress monitoring:
- File watcher for `PROGRESS.md` changes
- Parse progress percentages and status
- Display aggregated progress in monitor pane
- Detect agent completion/failure

## Phase 4: Integration with spec-workflow-mcp

### 8. Connect to spec-workflow tools:
- Read spec documents for task details
- Use approval system for human gates
- Extend dashboard to show tmux session status
- Create MCP tools for symphony control

### 9. Add dashboard integration:
- WebSocket server to broadcast tmux status
- Real-time agent progress visualization
- Terminal output streaming (optional)
- Control buttons for symphony commands

## Phase 5: Conflict Resolution & Merging

### 10. Implement integration workflow:
- Detect when all agents complete
- Launch integration agent in new pane
- Review diffs from all worktrees
- Merge changes to main branch
- Handle conflicts with human escalation

## File Structure

```
symphony/
├── bin/                           # Executable scripts
│   ├── symphony                   # Main CLI entry point
│   ├── symphony-orchestrator.sh
│   ├── symphony-spawn-agent.sh
│   ├── symphony-monitor.sh
│   └── symphony-cleanup.sh
├── lib/                           # Supporting scripts
│   ├── tmux-layouts.sh            # Predefined tmux layouts
│   ├── agent-prompts.sh           # Generate agent prompts
│   ├── progress-parser.sh         # Parse PROGRESS.md files
│   └── git-operations.sh          # Worktree management
├── config/
│   └── symphony.config.yml        # User configuration
└── .symphony/                     # Runtime directory
    ├── sessions/                  # Active tmux sessions
    ├── worktrees/                 # Git worktrees
    ├── state/                     # State files
    └── logs/                      # Agent logs
```

## Key Implementation Details

### tmux Session Structure

```bash
# Main session with organized panes
tmux new-session -d -s symphony-$TASK_ID
tmux split-window -h -p 30   # Monitor pane on right
tmux select-pane -t 0
tmux split-window -v -p 80   # Orchestrator on top
tmux select-pane -t 2
tmux split-window -h          # Agent panes in grid
tmux split-window -v
tmux select-pane -t 3
tmux split-window -v
```

### Agent Launching

```bash
# Launch Claude Code for each agent type
tmux send-keys -t symphony:1 "claude --task 'Frontend agent: $TASK'" Enter
tmux send-keys -t symphony:2 "claude --task 'Backend agent: $TASK'" Enter
```

### Progress Monitoring

```bash
# Continuous monitoring in monitor pane
watch -n 2 'cat .symphony/tasks/*/agents/*/PROGRESS.md'
```

## Benefits

This approach will give us:
- True parallel execution of multiple agents
- Visual feedback through tmux panes
- Clean session management
- Integration with existing spec-workflow
- Easy debugging by attaching to tmux session