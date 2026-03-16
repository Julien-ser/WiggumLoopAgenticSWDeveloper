# 🎭 Wiggum Agent Team

The Wiggum Agent Team is a collection of specialized AI agent personalities designed to drive your projects from concept to production. Each agent has distinct expertise, workflows, and success metrics.

## The Team

### 1. 🚀 [DevOps Automation Engineer](agents/devops-engineer.md)
**Specialty**: Infrastructure, CI/CD, deployment automation

- Builds and maintains GitHub Actions workflows
- Sets up staging/production environments
- Manages deployment infrastructure
- Implements monitoring and health checks
- **When to activate**: Setting up CI/CD, creating deployment pipelines

### 2. 🧪 [QA & Testing Specialist](agents/qa-specialist.md)
**Specialty**: Testing, quality assurance, quality gates

- Creates and maintains test suites
- Automates testing in CI pipeline
- Validates code quality
- Documents and tracks bugs
- **When to activate**: Building test suite, before any production deployment

### 3. 📦 [Release Manager](agents/release-manager.md)
**Specialty**: Versioning, releases, deployment coordination

- Manages semantic versioning
- Coordinates releases across teams
- Creates release notes and documentation
- Manages rollback procedures
- **When to activate**: Preparing for production release, version management

### 4. 🎯 [Project Orchestrator](agents/project-orchestrator.md)
**Specialty**: Coordination, workflow management, blocking issue resolution

- Orchestrates work across specialist agents
- Tracks progress and identifies blockers
- Manages priorities and dependencies
- Communicates status to stakeholders
- **When to activate**: At project kickoff, for complex multi-phase projects

### 5. 📝 [Documentation & Communications Specialist](agents/documentation-specialist.md)
**Specialty**: Technical writing, documentation, stakeholder communication

- Maintains README and technical docs
- Documents decisions and rationale
- Creates troubleshooting guides
- Communicates project status
- **When to activate**: Project start, at each phase completion

## How to Use the Agents

### Option 1: Choose a Single Agent (Recommended for Focused Work)

```bash
# Step 1: Pick which agent you need
cd /path/to/your/project

# Step 2: Read their personality file
cat /path/to/Free-Wiggum-opencode/agents/devops-engineer.md

# Step 3: Activate them in Claude Code
# Copy the agent content and paste into Claude or use:
# "Activate DevOps Automation Engineer mode"

# Step 4: Give them work
# Provide task in their specialty area
```

### Option 2: Multi-Agent Coordination (For Complex Projects)

```bash
# 1. Start with Project Orchestrator
# They'll coordinate the others and understand dependencies

# 2. DevOps Engineer sets up infrastructure
# "Set up GitHub Actions workflows for testing and deployment"

# 3. QA Specialist builds test suite
# "Create comprehensive test suite with 80%+ coverage"

# 4. Release Manager handles versioning
# "Prepare v1.0.0 release and deployment plan"

# 5. Documentation Specialist keeps everyone informed
# "Update README with new features and create runbooks"
```

### Option 3: Use as Claude Code Custom Instructions

You can copy any agent file directly to `~/.claude/agents/` for Claude Code integration:

```bash
# Copy agent to Claude Code
cp agents/devops-engineer.md ~/.claude/agents/devops-engineer.md

# Then in Claude Code, reference them:
# "@devops-engineer Set up GitHub Actions for our project"
```

## Quick Reference: Who Does What?

| Task | Agent | Time | Effort |
|------|-------|------|--------|
| Setup CI/CD pipeline | DevOps Engineer | 1-2 hours | High |
| Write test suite | QA Specialist | 2-4 hours | High |
| Version and release | Release Manager | 30-45 min | Medium |
| Coordinate multiple tasks | Project Orchestrator | 15 min + | Low |
| Document architecture | Documentation Specialist | 1-2 hours | Medium |
| Fix broken tests | QA Specialist | 30-60 min | Medium |
| Troubleshoot deployment | DevOps Engineer | Variable | High |
| What to do next? | Project Orchestrator | 10 min | Low |

## Common Workflows

### 🚀 Launch a New Project

```
1. Project Orchestrator: Plan the work
   ↓
2. DevOps Engineer: Setup CI/CD
   ↓
3. Developer: Build features
   ↓
4. QA Specialist: Write tests
   ↓
5. Documentation Specialist: Write README & guides
   ↓
6. Release Manager: Prepare v1.0.0
   ↓
7. DevOps Engineer: Deploy to production
   ↓
8. Documentation Specialist: Announce release
```

### 🐛 Fix a Bug & Release

```
1. Developer: Fix the bug
   ↓
2. QA Specialist: Verify fix, add test
   ↓
3. Release Manager: Bump patch version (x.y.Z)
   ↓
4. DevOps Engineer: Deploy to production
   ↓
5. Documentation Specialist: Update changelog
```

### 📈 Add Major Feature

```
1. Project Orchestrator: Break into phases
   ↓
2. Developer: Build feature
   ↓
3. QA Specialist: Test thoroughly
   ↓
4. Documentation Specialist: Update README & guides
   ↓
5. Release Manager: Bump minor version (x.Y.z)
   ↓
6. DevOps Engineer: Deploy to production
```

### 🔧 Setup Deployment to Staging/Prod

```
1. DevOps Engineer: Create CI/CD workflows
   ↓
2. QA Specialist: Add smoke tests
   ↓
3. Release Manager: Document deployment procedure
   ↓
4. Documentation Specialist: Create runbooks
   ↓
5. DevOps Engineer: Test full deployment flow
```

## Activation Examples

### In Claude Code (or Claude AI)

```
"I need to set up GitHub Actions for my project. Can you activate DevOps Automation Engineer mode?"

[Agency will load the agent personality and expertise]

"Great! Here's what I need:
- Automated tests on push
- Staging deployment on develop branch
- Manual production deployment with approval gates"
```

### For a Specific Task

```
"@devops-engineer Help me create a deployment workflow that:
1. Runs tests on every push
2. Deploys to staging on develop
3. Requires approval before production"
```

### For Coordination

```
"@project-orchestrator We need to launch v2.0. Break down the work and tell me:
1. What order should tasks happen?
2. Who (which agent) should do what?
3. What are the critical path items?"
```

## Agent Interaction Patterns

### Sequential (One hands off to next)
```
Developer → QA → Release Manager → DevOps Engineer → Documentation
```

### Parallel (Multiple agents work simultaneously)
```
         ┌─ DevOps Engineer (CI/CD)
Project ─┼─ QA Specialist (Tests)
        └─ Documentation (Docs)
```

### Coordinated (One orchestrates, others execute)
```
         ┌─ DevOps Engineer
         ├─ QA Specialist
Project ─┤─ Release Manager ─ (coordinated by orchestrator)
         ├─ Documentation
         └─ Developer
```

## Success Criteria

✅ **Each agent is activated with clear scope** ("Build test suite for user auth module")
✅ **Agent owns complete workflow** (not "write one test")
✅ **Clear handoff points** (QA says "ready for release", Release Manager takes over)
✅ **Success metrics defined** (DevOps: "deployments < 5 min", QA: "coverage > 80%")
✅ **Communication is documented** (in TASKS.md, decision logs, etc.)

## Troubleshooting

### "Agent doesn't seem to understand the task"
- Make sure task is in their specialty area
- Provide more context about the project
- Reference their personality file for how they work

### "Two agents are stepping on each other"
- Use Project Orchestrator to coordinate
- Define clear ownership boundaries
- Use TASKS.md to track who owns what

### "Agent seems to be repeating work"
- Check if work already exists (in docs, code, etc.)
- Provide explicit instructions to review existing work first
- Clarify what the improvement/change should be

## Integration with Wiggum System

These agents work alongside the Wiggum worker system:

```
OpenCode Worker (runs continuously)
          ↓
    Processes TASKS.md
          ↓
   Invokes specialized agents
          ↓
  (DevOps, QA, Release Mgr, etc)
          ↓
    Completes tasks & commits
          ↓
   GitHub Actions validates
          ↓
    Deploys automatically
```

Using both systems:
- **Workers**: Autonomous, continuous task processing
- **Agents**: Specialized expertise for specific domains
- **Together**: Autonomous agents with specialized intelligence

## Next Steps

1. **Pick an agent** based on your current need
2. **Read their personality file** to understand how they think
3. **Activate them** in your IDE (Claude Code, Cursor, etc.)
4. **Give them clear scope** and success criteria
5. **Let them work** - they're specialists

---

**Your Wiggum team is ready to work. Which specialist do you need first?**
