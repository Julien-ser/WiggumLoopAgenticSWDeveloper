# Agent Role Integration

The Wiggum system now supports specialized agent roles for autonomous project workers. Each role has its own expertise and personality, enabling more targeted and efficient task completion.

## Available Roles

The following agent roles are available in the `agents/` directory:

- **devops-engineer.md** - Infrastructure, CI/CD, deployment automation
- **qa-specialist.md** - Testing, quality assurance, quality gates
- **release-manager.md** - Versioning, releases, deployment coordination
- **project-orchestrator.md** - Coordination, workflow management, blocking issue resolution
- **documentation-specialist.md** - Technical writing, documentation, stakeholder communication
- **generic** - Default multi-purpose developer (used when no specific role assigned)

## How It Works

### Backend Integration

1. **wiggum_worker.sh** - Now accepts an optional `--agent ROLE` parameter
   ```bash
   bash wiggum_worker.sh /path/to/project --agent devops-engineer
   ```

2. **wiggum_master.sh** - `start` command passes agent role to worker
   ```bash
   bash wiggum_master.sh start project-name qa-specialist
   ```

3. **server.py** - REST API accepts `agent_role` in start-project requests
   ```python
   POST /api/start-project/{name}
   { "agent_role": "devops-engineer" }
   ```

### Agent Selection Process

When a worker starts with an agent role:

1. Worker stores active role in `.agent_role` file in project root
2. Worker loads role-specific prompt from `agents/{role}.md`
3. OpenCode invokes specialized agent personality
4. Agent completes tasks using specialized expertise
5. UI displays active agent role on project cards and details

### Frontend Integration

**Project Cards** - Show active agent role (if not generic):
```
portfolio-website-terminal
🟢 RUNNING
🎭 devops-engineer  ← Shows here
Tasks: 3/16
```

**Project Details** - Display in configuration section:
```
Active Agent: devops-engineer
```

## Using Agent Roles

### Via Frontend

1. Create a project
2. Click Start (currently starts with generic role)
3. To change agent, stop the worker and restart with desired role

### Via CLI

```bash
# Start project with specific agent
bash /path/to/Free-Wiggum-opencode/wiggum_master.sh start my-project devops-engineer

# Or directly with worker
bash wiggum_worker.sh /path/to/projects/my-project --agent qa-specialist
```

### Via REST API

```bash
curl -X POST http://localhost:5000/api/start-project/my-project \
  -H "Content-Type: application/json" \
  -d '{"agent_role": "release-manager"}'
```

## Example Workflows

### Phase 1: Initial Development
**Agent**: project-orchestrator
- Breaks down requirements into tasks
- Identifies dependencies
- Creates initial TASKS.md

### Phase 2: Implementation
**Agent**: generic or specialized (e.g., devops-engineer for infra)
- Completes feature development
- Sets up infrastructure
- Creates initial test cases

### Phase 3: Quality Assurance
**Agent**: qa-specialist
- Builds comprehensive test suite
- Validates edge cases
- Documents bugs and fixes

### Phase 4: Release
**Agent**: release-manager
- Bumps version numbers
- Creates release notes
- Coordinates deployment

### Phase 5: Documentation
**Agent**: documentation-specialist
- Updates README
- Creates runbooks
- Documents architecture

## Agent Personality Files

Each agent file contains:
- Specialized instructions tailored to their role
- Success criteria specific to their domain
- Technical expertise and best practices
- Examples and patterns relevant to their specialty

Edit these files to customize agent behavior for your workflow.

## Technical Details

### File Structure

```
project-root/
├── .agent_role          # Stores current active agent role
├── TASKS.md            # Tasks to complete
├── prompt.txt          # Project-specific instructions (optional)
└── ...

agents/
├── devops-engineer.md
├── qa-specialist.md
├── release-manager.md
├── project-orchestrator.md
└── documentation-specialist.md
```

### How Agent Role Affects Worker

1. **Prompt Construction**: Worker loads agent-specific prompt instead of generic
2. **Context**: Agent personality informs decision-making and approach
3. **Focus**: Agent specializes in tasks relevant to their domain
4. **Communication**: Output style and documentation reflect agent expertise

### Agent Role Persistence

- Active role stored in `.agent_role` file
- Persists across worker restarts
- Can be changed by restarting worker with different role
- UI reflects current active role

## Future Enhancements

- [ ] Frontend UI to select agent role before starting
- [ ] Multi-agent coordination (agents working in sequence)
- [ ] Agent-specific metrics and success tracking
- [ ] Role-based task filtering (e.g., only QA tasks to qa-specialist)
- [ ] Dynamic agent selection based on current project phase
- [ ] Custom agent creation and training

## Troubleshooting

**Agent not loading**:
- Check `.agent_role` file exists in project
- Verify agent file exists in `agents/{role}.md`
- Check OpenCode can read the file

**Wrong agent appearing**:
- Stop worker (kill the PID)
- Check `.agent_role` file contents
- Restart with correct agent

**Agent seems generic**:
- Verify agent was started with `--agent` flag
- Check `.agent_role` matches agent filename
- Reload project details in web UI

---

**Wiggum Agent System Ready**: Pick your specialist and get to work! 🎭
