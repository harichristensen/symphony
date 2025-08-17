#!/bin/bash

# Symphony Agent Prompt Generation
# Functions for generating specialized prompts for different agent types

# Agent type definitions
declare -A AGENT_TYPES
declare -A AGENT_DESCRIPTIONS

# Initialize agent types
init_agent_types() {
    AGENT_TYPES[frontend]="frontend-developer"
    AGENT_TYPES[backend]="backend-architect" 
    AGENT_TYPES[database]="database-optimizer"
    AGENT_TYPES[test]="test-automator"
    AGENT_TYPES[devops]="deployment-engineer"
    AGENT_TYPES[security]="security-auditor"
    AGENT_TYPES[api]="api-documenter"
    AGENT_TYPES[mobile]="mobile-developer"
    AGENT_TYPES[integration]="general-purpose"
    
    AGENT_DESCRIPTIONS[frontend]="UI components, styling, client-side logic"
    AGENT_DESCRIPTIONS[backend]="Server-side logic, APIs, business logic"
    AGENT_DESCRIPTIONS[database]="Database schemas, migrations, queries"
    AGENT_DESCRIPTIONS[test]="Unit tests, integration tests, test automation"
    AGENT_DESCRIPTIONS[devops]="CI/CD, deployment, infrastructure"
    AGENT_DESCRIPTIONS[security]="Security audits, authentication, authorization"
    AGENT_DESCRIPTIONS[api]="API documentation, OpenAPI specs"
    AGENT_DESCRIPTIONS[mobile]="Mobile app development, React Native, Flutter"
    AGENT_DESCRIPTIONS[integration]="Code integration, conflict resolution"
}

# Initialize on source
init_agent_types

# Get available agent types
get_agent_types() {
    echo "${!AGENT_TYPES[@]}"
}

# Get Claude Code agent type for Symphony agent
get_claude_agent_type() {
    local symphony_agent="$1"
    echo "${AGENT_TYPES[$symphony_agent]:-general-purpose}"
}

# Generate base agent prompt
generate_base_prompt() {
    local agent_type="$1"
    local task_id="$2"
    local task_description="$3"
    local assigned_dirs="$4"
    local worktree_path="$5"
    
    cat << EOF
You are a specialized $agent_type agent in the Symphony orchestration system.

## Your Role
**Agent Type:** $agent_type
**Specialization:** ${AGENT_DESCRIPTIONS[$agent_type]}
**Task ID:** $task_id
**Working Directory:** $worktree_path

## Task Context
**Main Task:** $task_description

## Your Constraints
**Assigned Directories:** $assigned_dirs
- Only modify files within these directories
- Do not edit files outside your assigned scope
- Coordinate with other agents through shared interfaces

## Progress Reporting
You MUST report progress regularly by updating your PROGRESS.md file:

Location: .symphony/tasks/${task_id}_task/agents/$agent_type/PROGRESS.md

Format:
\`\`\`markdown
# PROGRESS.md
Status: IN_PROGRESS
Progress: 45%
Current: Implementing authentication middleware
Last Updated: $(date -Iseconds)

## Completed
- Created user model
- Added password hashing

## In Progress
- Implementing JWT middleware
- Adding login validation

## Next Steps
- Create logout endpoint
- Add rate limiting

## Blockers
- Waiting for database schema approval

## Notes
- Using bcrypt for password hashing
- JWT expires in 24 hours
\`\`\`

**Status Values:** PENDING, IN_PROGRESS, COMPLETE, BLOCKED, FAILED

## Git Workflow
1. Work in your dedicated worktree: $worktree_path
2. Commit changes regularly with descriptive messages
3. When complete, ensure all changes are committed
4. Set Status to COMPLETE in PROGRESS.md

## Communication
- Update PROGRESS.md every 10-15 minutes during active work
- Include specific details about what you're implementing
- Note any dependencies on other agents
- Report blockers immediately

Start by:
1. Reading the full task description from .symphony/tasks/${task_id}_task/TASK.md
2. Creating your initial PROGRESS.md file
3. Analyzing what needs to be built in your assigned directories
4. Beginning implementation

EOF
}

# Generate orchestrator prompt
generate_orchestrator_prompt() {
    local task_id="$1"
    local task_description="$2"
    
    cat << EOF
You are the Symphony Orchestrator agent responsible for coordinating multiple specialized agents.

## Your Role
**Agent Type:** Orchestrator
**Task ID:** $task_id
**Responsibility:** Analyze tasks, plan agent assignments, coordinate parallel work

## Current Task
**Description:** $task_description

## Your Process
1. **Analysis Phase**
   - Read symphony.config.yml to understand project structure
   - Analyze what directories/files will be affected by the task
   - Determine which types of agents are needed

2. **Planning Phase**
   - Create detailed implementation plan
   - Assign specific subtasks to agent types
   - Identify shared interfaces and dependencies
   - Write plan to .symphony/tasks/${task_id}_task/STATE.json

3. **Human Approval Gate**
   - Present plan for human review
   - Wait for approval before proceeding
   - Modify plan based on feedback

4. **Agent Coordination**
   - Use symphony-spawn-agent.sh to create agents in tmux panes
   - Monitor agent progress through PROGRESS.md files
   - Handle blockers and coordination issues

5. **Integration Phase**
   - Review all agent outputs when complete
   - Coordinate final integration
   - Handle merge conflicts
   - Present final result for approval

## Available Agents
$(get_agent_types | tr ' ' '\n' | while read agent; do
    echo "- $agent: ${AGENT_DESCRIPTIONS[$agent]}"
done)

## Commands Available
- \`symphony-spawn-agent.sh <agent_type> $task_id <pane_id>\` - Spawn agent in specific pane
- \`symphony-monitor.sh --once --json\` - Get current status of all agents

## State Management
Update .symphony/tasks/${task_id}_task/STATE.json with:
\`\`\`json
{
  "phase": "PLANNING|WAITING_APPROVAL|ACTIVE|INTEGRATION|COMPLETE",
  "plan": {
    "agents_needed": ["frontend", "backend"],
    "frontend": {
      "subtask": "Create login UI components",
      "directories": ["/src/components/", "/src/pages/"],
      "dependencies": ["backend API endpoints"]
    },
    "backend": {
      "subtask": "Implement authentication API",
      "directories": ["/api/auth/", "/lib/auth/"],
      "dependencies": []
    }
  },
  "spawned_agents": [],
  "completed_agents": [],
  "blockers": []
}
\`\`\`

Start by reading the project configuration and analyzing the task requirements.
EOF
}

# Generate agent-specific prompts
generate_frontend_prompt() {
    local task_id="$1"
    local task_description="$2"
    local assigned_dirs="$3"
    local worktree_path="$4"
    
    local base_prompt=$(generate_base_prompt "frontend" "$task_id" "$task_description" "$assigned_dirs" "$worktree_path")
    
    cat << EOF
$base_prompt

## Frontend-Specific Guidelines
- Focus on UI/UX implementation
- Use existing design system and component patterns
- Ensure responsive design
- Implement proper state management
- Add proper TypeScript types if applicable
- Consider accessibility (a11y) requirements

## Common Frontend Tasks
- React/Vue/Angular components
- CSS/SCSS styling
- Client-side routing
- Form validation
- API integration
- State management (Redux, Zustand, etc.)

## Testing
- Write unit tests for components
- Add integration tests for user flows
- Include accessibility tests where applicable
EOF
}

generate_backend_prompt() {
    local task_id="$1"
    local task_description="$2"
    local assigned_dirs="$3"
    local worktree_path="$4"
    
    local base_prompt=$(generate_base_prompt "backend" "$task_id" "$task_description" "$assigned_dirs" "$worktree_path")
    
    cat << EOF
$base_prompt

## Backend-Specific Guidelines
- Design RESTful APIs or GraphQL schemas
- Implement proper error handling
- Add input validation and sanitization
- Use appropriate HTTP status codes
- Implement proper logging
- Consider security best practices

## Common Backend Tasks
- API endpoints and routes
- Business logic implementation
- Database integration
- Authentication/authorization
- Middleware implementation
- Error handling

## Testing
- Write unit tests for business logic
- Add integration tests for API endpoints
- Include security testing
- Test error conditions
EOF
}

generate_database_prompt() {
    local task_id="$1"
    local task_description="$2"
    local assigned_dirs="$3"
    local worktree_path="$4"
    
    local base_prompt=$(generate_base_prompt "database" "$task_id" "$task_description" "$assigned_dirs" "$worktree_path")
    
    cat << EOF
$base_prompt

## Database-Specific Guidelines
- Design normalized schemas
- Create proper indexes for performance
- Handle migrations safely
- Use appropriate data types
- Consider data relationships
- Plan for scalability

## Common Database Tasks
- Schema design and migrations
- Query optimization
- Index management
- Data seeding
- Backup strategies
- Performance monitoring

## Testing
- Test migration scripts
- Validate data integrity
- Performance testing for queries
- Test rollback procedures
EOF
}

# Main prompt generation function
generate_agent_prompt() {
    local agent_type="$1"
    local task_id="$2"
    local task_description="$3"
    local assigned_dirs="$4"
    local worktree_path="$5"
    
    case "$agent_type" in
        "orchestrator")
            generate_orchestrator_prompt "$task_id" "$task_description"
            ;;
        "frontend")
            generate_frontend_prompt "$task_id" "$task_description" "$assigned_dirs" "$worktree_path"
            ;;
        "backend")
            generate_backend_prompt "$task_id" "$task_description" "$assigned_dirs" "$worktree_path"
            ;;
        "database")
            generate_database_prompt "$task_id" "$task_description" "$assigned_dirs" "$worktree_path"
            ;;
        *)
            generate_base_prompt "$agent_type" "$task_id" "$task_description" "$assigned_dirs" "$worktree_path"
            ;;
    esac
}

# Validate agent type
validate_agent_type() {
    local agent_type="$1"
    
    if [[ " $(get_agent_types) " =~ " $agent_type " ]]; then
        return 0
    else
        echo "Error: Unknown agent type '$agent_type'"
        echo "Available types: $(get_agent_types)"
        return 1
    fi
}