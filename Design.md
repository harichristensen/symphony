# Claude Orchestration System Design

The Claude Orchestration System enables developers to use Claude Code to the fullest in software projects. The system handles task delegation, conflict resolution, and real-time coordination between agents through an interface.

## Claude Code Integration

**Native Claude Code Command Extension**

### Command Interface
```bash
/symphony init                    # Initialize orchestrator, creates symphony.config.yml
/symphony start                   # Start processing task queue
/symphony add <issue-url>         # Add GitHub issue to queue
/symphony status                  # Show current task and agents
/symphony queue                   # Display task queue
/symphony approve                 # Approve current plan/implementation
/symphony reject <reason>         # Reject with feedback
/symphony resolve                 # Continue after manual conflict resolution
/symphony pause                   # Pause orchestrator
/symphony resume                  # Resume orchestrator
/symphony clean                   # Clean up worktrees and state
```

### Orchestrator Invocation
- **Within Claude Code**: Orchestrator runs as Claude Code agent via `/symphony` commands
- **Self-Spawning**: Orchestrator agent uses Task tool to spawn worker agents
- **Persistent Context**: Orchestrator maintains context across commands via state files
- **No External Process**: Everything runs within Claude Code environment

## Configuration

**Project-Specific Configuration via symphony.config.yml**

### Configuration File
```yaml
# symphony.config.yml (at project root)
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
      - '/middleware/'
  database-agent:
    directories:
      - '/migrations/'
      - '/schemas/'
      - '/models/'
  test-agent:
    directories:
      - '/tests/'
      - '/__tests__/'

shared_directories:
  - '/shared/'
  - '/types/'

orchestrator:
  retry_count: 3
  timeout_minutes: 10
  polling_interval_seconds: 30
  
task_processing:
  max_parallel_agents: 4
  require_human_approval: true
  auto_merge_strategy: 'conservative'  # conservative | aggressive | manual

pre_flight:
  enabled: true
  checks:
    - dependency_analysis
    - directory_structure
    - conflict_prediction
```

### Configuration Usage
- **Agent Lane Enforcement**: Orchestrator reads config to determine which agent can edit which directories
- **Dynamic Parameters**: Timeout, retry counts, polling intervals from config instead of hardcoded
- **Project-Specific Rules**: Each project can have different agent assignments and rules
- **Validation**: Orchestrator validates config on startup, fails early if misconfigured

## 1. Multi-Agent Coordination

**Hybrid Model: Central Delegation + Peer Parallelization**

### Orchestrator Role
- **Task Analysis**: Analyzes which directories will be edited to determine if task can be split
- **Agent Selection**: Leverages Claude Code's built-in agent selection based on prompts
- **Task Splitting**: Splits tasks by development domain (frontend/backend/database/etc.)
- **Source of Truth**: Makes all delegation decisions, prevents implementation conflicts

### Agent Coordination Patterns
- **Parallel Execution**: Agents work simultaneously on different parts (Decided by Claude Code)
- **No Overlap**: Orchestrator ensures agents never work on same implementation to avoid conflicts
- **Clear Boundaries**: Each agent gets distinct directories/files to modify

### Progress Tracking
- **Individual Reporting**: Each agent reports progress to `.symphony/tasks/<N>_task/PROGRESS.md`
- **Orchestrator Monitoring**: Orchestrator tracks overall task completion across all agents
- **No Peer Negotiation**: Agents don't coordinate implementation details - orchestrator handles interfaces

### Example Flow
1. Github Issue Created: "Add user authentication with login UI"
2. Orchestrator analyzes: affects `/src/components/` (frontend) and `/api/auth/` (backend)
3. Orchestrator spawns: frontend-agent for UI, backend-agent for API
4. Agents work in parallel, report to separate PROGRESS.md files
5. Orchestrator monitors completion and integration

## 2. Task Distribution

**Sequential Processing with On-Demand Agents**

### Task Sources
- **GitHub Issues** (Default/Automated): Orchestrator monitors repo issues and automatically processes them
- **CLI Commands**: Direct task submission via command line interface  
- **Dashboard** (Future): Eventually a web UI for monitoring (not MVP)

### Agent Lifecycle Management
- **On-Demand Creation**: Orchestrator spawns agents whenever needed for specific tasks
- **Progress Monitoring**: Tracks agent status by reading `.symphony/tasks/<N>_task/PROGRESS.md` files
- **Completion Signal**: Agents write "Status: COMPLETE" to PROGRESS.md when done
- **Automatic Cleanup**: Destroys agents immediately after subtask completion

### Pre-flight Checks (Before PLANNING)
```bash
# Orchestrator runs before task planning:
1. npm list --depth=0        # Dependency inventory
2. tree -d -L 3              # Directory structure analysis
3. git diff --name-only main # Files changed from main
4. grep -r "TODO\|FIXME"     # Outstanding technical debt
```

**Analysis Results Feed Into Planning**:
- **Dependency Tree**: Identifies which packages each agent might need
- **Directory Structure**: Maps actual project layout to agent lanes
- **Change Detection**: Highlights areas already modified (potential conflicts)
- **Tech Debt**: Warns about fragile code areas

### Task Processing Strategy
- **Sequential Execution**: Process one task at a time to avoid dependencies (initial implementation)
- **Claude Code Intelligence**: Leverage existing agent selection via intelligent prompting
- **Parallelization Prompt**: Enhanced with pre-flight analysis data

### Shared Code Coordination
- **Skeleton Approach**: Agent creates skeleton functions in `/shared/` directory first
- **Parallel Implementation**: Other agents work on their specific domains
- **Integration Phase**: Agents return to implement shared components after domain work

### Example Flow
1. GitHub issue detected: "Add shopping cart functionality"
2. Orchestrator creates task: `.symphony/tasks/001_shopping_cart/`
3. Orchestrator prompts Claude Code for optimal agent parallelization and implementation plan
** Human agrees with implementation plan **
4. Agents w/ worktrees created based on Claude's analysis (frontend, backend, database)
5. Shared interfaces/types created in `/shared/`
6. Agents work in parallel on their domains
7. Agents continuously give progress updates
8. Review --> Fix --> Review loop
9. Integration and cleanup phase
10. Review --> Fix --> Review loop
11. Agents destroyed upon completion of their sub-task
** Human accepts implementation **

## 3. Real-time Communication

**Claude Code Native Communication with Git Worktrees**

### Orchestrator as Agent
- **Orchestrator = Claude Code Agent**: Uses Task tool to spawn worker agents
- **Worktree Isolation**: Each agent works in isolated git worktree
- **Native File Operations**: All agents use standard Read/Write tools
- **Conflict Resolution**: Review diffs and merge best implementations

### Unified Directory Structure
```
/project-root/                    # Main branch
.symphony/
├── state/                        # Orchestrator state management
│   ├── QUEUE.json               # Persistent task queue
│   ├── CURRENT_TASK.json        # Currently active task
│   └── agents/
│       └── REGISTRY.json        # Active agents and worktrees
├── worktrees/                    # Git worktrees for agent isolation
│   ├── frontend-agent/          # Git worktree for frontend
│   ├── backend-agent/           # Git worktree for backend
│   └── integration-agent/       # Git worktree for merging
└── tasks/
    └── <N>_task/                # Per-task directory
        ├── TASK.md              # Task requirements from issue/CLI
        ├── STATE.json           # Current state + plan + assignments
        └── agents/
            ├── frontend/
            │   └── PROGRESS.md  # Frontend agent progress
            └── backend/
                └── PROGRESS.md  # Backend agent progress
```

### Communication Pattern
1. **Orchestrator Agent** reads task (GitHub issue/CLI)
2. **Creates Worktrees** for each agent:
   ```bash
   git worktree add .symphony/worktrees/frontend-agent
   git worktree add .symphony/worktrees/backend-agent
   ```
3. **Spawns Worker Agents** with prompts:
   ```
   "You are a frontend agent. Your workspace is .symphony/worktrees/frontend-agent/
    Read task from .symphony/tasks/N_task/TASK.md
    Report progress to .symphony/tasks/N_task/agents/frontend/PROGRESS.md"
   ```
4. **Agents Work Independently** in their worktrees (can edit same files!)
5. **Integration Phase**: Orchestrator or integration-agent:
   - Reviews git diffs from each worktree
   - Chooses best implementation or merges both
   - Applies to main branch

### Conflict Resolution Benefits
- **No File Locks**: Agents freely edit any file in their worktree
- **Best Solution Wins**: Compare implementations, pick superior one
- **Hybrid Merging**: Combine best parts from multiple agents
- **Clear History**: Git tracks who did what

### Agent Cleanup
```bash
git worktree remove .symphony/worktrees/frontend-agent
```

## 4. State Management

**Simple State with Clean Restart Strategy**

*Directory structure defined in Section 3 - Real-time Communication*

### Task Lifecycle States
```
PENDING → PLANNING → WAITING_APPROVAL → ACTIVE → REVIEW → WAITING_FINAL → COMPLETE
                           ↓                 ↓        ↓           ↓
                       [CANCELLED]    [TEST_FAILED] [FAILED]  [REJECTED]
                                            ↓
                                   [NEEDS_HUMAN_INTEGRATION]
```

### State Files

**QUEUE.json** (Persistent)
```json
{
  "tasks": [
    {"id": "001", "source": "github#123", "title": "Add authentication"},
    {"id": "002", "source": "cli", "title": "Refactor database"}
  ],
  "current": "001",
  "completed": ["000"]
}
```

**CURRENT_TASK.json** (Transient)
```json
{
  "id": "001",
  "state": "ACTIVE",
  "started": "2025-01-17T10:00:00Z",
  "agents": ["frontend-01", "backend-01"]
}
```

**REGISTRY.json** (Agent tracking)
```json
{
  "agents": [
    {
      "id": "frontend-01",
      "type": "frontend-developer",
      "worktree": ".symphony/worktrees/frontend-01",
      "task": "001",
      "subtask": "implement-login-ui",
      "last_activity": "2025-01-17T10:30:00Z"
    }
  ]
}
```

### Atomic State Updates
**Preventing Corruption with Write-Rename Pattern**

```python
# Pseudo-code for atomic writes
def atomic_write(filepath, data):
    temp_path = f"{filepath}.tmp"
    write_json(temp_path, data)
    os.rename(temp_path, filepath)  # Atomic on POSIX systems
```

**All State Files Use Atomic Updates**:
- Write to `.tmp` file first
- Validate JSON structure
- Atomic rename to final destination
- Never leaves partial/corrupt state

### Crash Recovery Protocol
1. **On Orchestrator Start**:
   - Clean up all worktrees: `git worktree prune`
   - Clear CURRENT_TASK.json and REGISTRY.json
   - Read QUEUE.json (guaranteed valid due to atomic writes)
   - Restart current task from PLANNING phase
   
2. **State Transitions**:
   - **PLANNING**: Orchestrator creates implementation plan
   - **WAITING_APPROVAL**: Human reviews plan
   - **ACTIVE**: Agents working
   - **REVIEW**: Code review phase
   - **WAITING_FINAL**: Human final approval
   - **COMPLETE**: Merged to main

### Human Approval Gates
- After PLANNING → Must approve implementation strategy
- After REVIEW → Must approve code changes
- Rejections send back to PLANNING or ACTIVE respectively

## 5. Conflict Resolution

**Lane-Based Development with Integration Agent**

### Conflict Prevention (Primary Strategy)
- **Config-Driven Lanes**: Agent lanes defined in `symphony.config.yml`
- **Shared Code**: Only through directories marked in config
- **No Cross-Lane Edits**: Enforced by orchestrator based on config

### Integration Flow
```
agent-worktree → commit → human-review → integration-branch → testing → main
```

1. **Agent Completion**:
   - Agent commits changes in worktree
   - Marks subtask as COMPLETE
   - Waits for human review

2. **Human Review Gate**:
   - Review agent's implementation in worktree
   - Approve or request changes
   - Multiple agents can await review in parallel

3. **Integration Agent**:
   - Spawned after human approvals
   - Cherry-picks approved commits to issue branch
   - Handles rare merge conflicts intelligently:
     ```bash
     git cherry-pick frontend-agent-commit
     git cherry-pick backend-agent-commit
     # If conflict: analyze context, choose performant solution
     ```

4. **Conflict Resolution Strategy**:
   - **Automated**: Integration-agent attempts resolution based on:
     - Performance implications
     - Code context and patterns
     - Existing architecture
   - **Explicit Fallback**: When conflicts cannot be auto-resolved:
     - Halts immediately
     - Sets task state to `NEEDS_HUMAN_INTEGRATION`
     - Creates detailed conflict report:
     ```markdown
     # CONFLICT.md
     Task: 001_authentication
     State: NEEDS_HUMAN_INTEGRATION
     
     ## Conflicting Files
     - /shared/types.ts
       - frontend-agent: Added UserProfile interface (commit: abc123)
       - backend-agent: Added UserData interface (commit: def456)
     
     ## Conflict Details
     Both agents created similar but incompatible user interfaces.
     
     ## Suggested Resolution
     1. Review both implementations
     2. Merge interfaces or choose one
     3. Run `/symphony resolve` after manual fix
     ```

### Branch Strategy
```
main
  └── issue-123-authentication    # Created at task start
      ├── frontend-worktree       # Agent worktree (based on issue branch)
      ├── backend-worktree        # Agent worktree (based on issue branch)
      └── [merged commits]        # Cherry-picked after approval
```

### Example Flow
1. Task: "Add user authentication"
2. Frontend-agent implements login UI → commits → human approves
3. Backend-agent implements auth API → commits → human approves
4. Database-agent adds user tables → commits → human approves
5. Integration-agent:
   - Cherry-picks all commits to issue branch
   - Resolves any `/shared/types.ts` conflicts
   - Runs tests on issue branch
6. Human final approval → merge to main

## 6. Progress Tracking

**Comprehensive Monitoring with Dashboard & CLI**

### Progress Data Sources
- **PROGRESS.md Files**: Each agent writes structured progress updates
- **Git Activity**: Commits, branches, diffs from worktrees  
- **State Files**: Task states, agent registry, queue status
- **Timestamps**: All activities tracked with ISO timestamps

### Agent Progress Format
```markdown
# PROGRESS.md
Status: IN_PROGRESS
Progress: 65%
Current: Implementing JWT middleware
Last Updated: 2025-01-17T10:30:45Z
```

### Dashboard (Local Web UI)
- **Real-time Updates**: WebSocket or polling file changes
- **Multi-pane View**:
  - Task queue and current task state
  - Active agents with progress bars
  - Live agent logs/outputs
  - Git commit timeline
  - File change previews
- **Interactive Controls**:
  - Approve/reject implementations
  - Pause/resume agents
  - View diffs between worktrees

### CLI Interface
```bash
symphony status          # Current task and agents
symphony queue           # Show task queue
symphony agents          # List active agents
symphony task <id>       # Detailed task info
symphony history         # Completed tasks
```

*Historical tracking and metrics: Future enhancement after MVP*

## 7. Error Recovery

**Clean Restart with Retry Escalation**

### Failure Detection
- **Timeout Monitoring**: Agent considered failed if no PROGRESS.md update for timeout defined in config
- **Test Failures**: Detected via test runner exit codes
- **Health Check**: Orchestrator polls agent progress files per config interval

### Test Failure Analysis
**Error-Finder Agent for Root Cause Analysis**

When tests fail, orchestrator spawns specialized `error-finder` agent:
```
"You are an error-finder agent. Analyze the test failure at:
.symphony/tasks/N/test-output.log
Identify the root cause, not symptoms.
Avoid bandaid fixes. Write analysis to ROOT_CAUSE.md"
```

**Error-Finder Process**:
1. Analyzes test output and stack traces
2. Examines recent code changes
3. Identifies patterns (null checks, type mismatches, logic errors)
4. Writes detailed analysis:
```markdown
# ROOT_CAUSE.md
## Test Failure: auth.test.js
### Surface Error
TypeError: Cannot read property 'id' of undefined

### Root Cause
Missing validation in auth middleware before accessing user object.
Not a null check issue - authentication flow isn't populating user.

### Proper Fix
Add authentication verification step in middleware, not just null check.
```
5. Orchestrator uses analysis to re-prompt fixing agent

### Recovery Protocol
1. **Detection**: No progress update within timeout window
2. **Clean Slate**:
   ```bash
   git worktree remove .symphony/worktrees/failed-agent
   rm -rf .symphony/tasks/N/agents/failed-agent/
   ```
3. **Error Logging**:
   ```
   .symphony/
   └── errors/
       └── 001_task/
           └── attempt_1/
               ├── ERROR.md      # What failed
               ├── ANALYSIS.md   # Why it likely failed
               └── LAST_STATE.md # Last known progress
   ```
4. **Retry**: Spawn new agent with same prompt and task

### Retry Strategy
- **Maximum Attempts**: 3 retries per subtask
- **Same Agent Type**: Use same specialized agent type
- **Fresh Context**: Each retry starts completely fresh
- **Escalation**: After 3 failures → human intervention required

### Error Log Format
```markdown
# ERROR.md
Task: 001_authentication
Agent: frontend-agent-01
Subtask: implement-login-ui
Attempt: 1
Timeout: No progress for 10 minutes
Last Activity: 2025-01-17T10:30:00Z
Last Known State: Creating form components
```

### Orchestrator Failure
- **Manual Recovery**: 
- **State Preserved**: QUEUE.json persists, allowing clean restart
- **Recovery**: As defined in State Management - restart current task from PLANNING

### Escalation to Human
```markdown
# ESCALATION.md
Task 001 subtask 'implement-login-ui' failed 3 times.

Failure Pattern: Timeout after form component creation
Likely Cause: Circular dependency or infinite loop

Action Required:
1. Review error logs in .symphony/errors/001_task/
2. Manually implement or provide guidance
3. Run '/symphony retry' with modified prompt or '/symphony skip' to continue
```

## Implementation Summary

**Leveraging Claude Code Native Capabilities**

### Core Principles
- **Orchestrator = Claude Code Agent**: No external processes or servers
- **File-Based Communication**: Simple, reliable, debuggable
- **Git Worktrees**: Perfect isolation and conflict resolution
- **Human-in-the-Loop**: Approval gates at critical points
- **Clean Failures**: Full restart with comprehensive logging

### Why This Works
- **No Infrastructure**: Everything Uses Claude-Code
- **Natural Agent Behavior**: Agents read/write files using standard tools
- **Git-Native**: Leverages git's powerful branching and merging
- **Simple State**: Just files and directories, easy to debug
- **Claude Intelligence**: Claude Code's agent selection and task handling

