# 🎼 Symphony

**Claude Code Orchestration System with tmux**

Symphony enables true parallel execution of multiple Claude Code agents using tmux sessions and git worktrees. Each agent works independently on different parts of your codebase simultaneously, with intelligent coordination and conflict resolution.

## ✨ Features

- **Parallel Agent Execution**: Multiple Claude Code agents working simultaneously
- **tmux Integration**: Visual real-time monitoring of all agents
- **Git Worktree Isolation**: Each agent works in isolated git worktrees
- **Intelligent Coordination**: Agents assigned to specific directories to prevent conflicts
- **Human Approval Gates**: Review and approve plans before execution
- **Real-time Monitoring**: Live progress tracking and logs
- **Conflict Resolution**: Automated integration with human escalation when needed

## 🚀 Quick Start

### Installation

```bash
# One-line install
curl -sSL https://raw.githubusercontent.com/harichristensen/symphony/main/install.sh | bash

# Restart your shell or source your profile
source ~/.zshrc  # or ~/.bashrc
```

### Initialize in Your Project

```bash
# Navigate to your git repository
cd your-project

# Initialize Symphony
symphony init

# Edit configuration (optional)
nano symphony.config.yml

# Start orchestrating!
symphony start "Add user authentication system"
```

### View Progress

```bash
# Attach to the tmux session to see all agents working
symphony attach

# Check status from command line
symphony status

# View logs
symphony logs
```

## 📋 Requirements

- **tmux** >= 3.0
- **git** with worktree support
- **claude** - Claude Code CLI
- **jq** (for JSON parsing)

## 🎯 How It Works

1. **Task Analysis**: The orchestrator analyzes your task and project structure
2. **Agent Planning**: Determines which agents are needed (frontend, backend, database, etc.)
3. **Human Approval**: You review and approve the implementation plan
4. **Parallel Execution**: Agents spawn in tmux panes with isolated git worktrees
5. **Real-time Monitoring**: Watch progress in real-time through tmux
6. **Integration**: Automated merging with conflict resolution

## 🏗️ Architecture

```
┌─────────────────┬──────────────────────┐
│ Orchestrator    │ Monitor              │
├─────────────────┼──────────────────────│
│ Frontend Agent  │ Backend Agent        │
├─────────────────┼──────────────────────│
│ Database Agent  │ Test Agent           │
└─────────────────┴──────────────────────┘
```

Each agent works in its own:
- **tmux pane** for isolated terminal sessions
- **git worktree** for isolated file operations
- **assigned directories** to prevent conflicts

## ⚙️ Configuration

Symphony uses `symphony.config.yml` to define agent lanes and project structure:

```yaml
version: 1.0

agent_lanes:
  frontend-agent:
    directories:
      - '/src/components/'
      - '/src/pages/'
      - '/public/'
  
  backend-agent:
    directories:
      - '/api/'
      - '/server/'
      - '/lib/'

shared_directories:
  - '/shared/'
  - '/types/'

orchestrator:
  retry_count: 3
  timeout_minutes: 30
  max_parallel_agents: 4

task_processing:
  require_human_approval: true
  auto_merge_strategy: 'conservative'
```

## 🛠️ Commands

### Core Commands

```bash
symphony init                    # Initialize Symphony in current repo
symphony start [task]           # Start orchestrator with task
symphony attach                 # Attach to tmux session
symphony status                 # Show current status
symphony stop                   # Stop all agents
symphony clean                  # Clean up worktrees and sessions
```

### Monitoring Commands

```bash
symphony logs                   # Show all agent logs
symphony logs [agent]           # Show specific agent logs
symphony config                 # Show current configuration
```

### Advanced Commands

```bash
symphony clean --all            # Clean everything
symphony clean --worktrees     # Clean only worktrees
symphony clean --sessions      # Clean only tmux sessions
```

## 📖 Usage Examples

### Web Application Development

```bash
# Full-stack feature development
symphony start "Add user authentication with login UI and API"

# Frontend-only task
symphony start "Redesign the dashboard with new components"

# Backend-only task  
symphony start "Add rate limiting and API security"
```

### Database Operations

```bash
# Database schema changes
symphony start "Add user profiles table with migration"

# Performance optimization
symphony start "Optimize database queries for user dashboard"
```

### Testing and DevOps

```bash
# Comprehensive testing
symphony start "Add unit tests for authentication system"

# CI/CD setup
symphony start "Set up GitHub Actions for automated testing"
```

## 🎮 tmux Key Bindings

When attached to the Symphony session:

- **Ctrl+B, D** - Detach from session (keep agents running)
- **Ctrl+B, Arrow Keys** - Navigate between panes
- **Ctrl+B, Z** - Zoom into current pane
- **Ctrl+B, [** - Enter scroll mode (use arrow keys, Q to exit)

## 🔧 Troubleshooting

### Common Issues

**Symphony session not found**
```bash
symphony clean --sessions
symphony start "your task"
```

**Git worktree errors**
```bash
symphony clean --worktrees
git worktree prune
```

**Agent timeout**
```bash
# Check agent progress
symphony status

# View agent logs
symphony logs [agent-name]

# Restart if needed
symphony stop
symphony start "your task"
```

### Debug Mode

```bash
# Enable verbose logging
export SYMPHONY_DEBUG=1
symphony start "your task"
```

### Check Installation

```bash
symphony version
tmux -V
claude --version
git --version
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📁 Project Structure

```
symphony/
├── bin/                          # Executable scripts
│   ├── symphony                  # Main CLI entry point
│   ├── symphony-orchestrator.sh  # Orchestrator script
│   ├── symphony-spawn-agent.sh   # Agent spawner
│   ├── symphony-monitor.sh       # Progress monitor
│   └── symphony-cleanup.sh       # Cleanup utility
├── lib/                          # Supporting libraries
│   ├── tmux-layouts.sh          # tmux layout management
│   ├── agent-prompts.sh         # Agent prompt generation
│   ├── progress-parser.sh       # Progress file parsing
│   └── git-operations.sh        # Git worktree operations
├── config/
│   └── symphony.config.yml.example
├── install.sh                   # Installation script
└── README.md
```

## 🐛 Known Issues

- **macOS**: Some tmux layouts may not display correctly on smaller terminal windows
- **Windows**: Not currently supported (WSL recommended)
- **Git < 2.15**: Worktree support may be limited

## 🔮 Roadmap

- [ ] Web dashboard for monitoring
- [ ] Slack/Discord notifications
- [ ] Agent performance metrics
- [ ] Custom agent types
- [ ] Integration with GitHub Issues
- [ ] Multi-repository support

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for [Claude Code](https://docs.anthropic.com/claude-code)
- Inspired by tmux session management
- Uses git worktrees for isolation

---

**Need help?** 
- 📖 [Documentation](https://github.com/harichristensen/symphony/wiki)
- 🐛 [Report Issues](https://github.com/harichristensen/symphony/issues)
- 💬 [Discussions](https://github.com/harichristensen/symphony/discussions)

Happy orchestrating! 🎼✨