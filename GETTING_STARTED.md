# 🎭 Wiggum System: Getting Started

You now have a complete autonomous agent orchestration system with specialized team members. Here's everything you just got:

## What You Have

### ✅ Persistent Worker System
- **`wiggum_worker_persistent.sh`** - Continuous task worker that runs indefinitely
- **`wiggum_worker_manager.sh`** - Control panel for starting/stopping/monitoring workers
- Health checks and automatic recovery
- Session restarts every hour with graceful handoff

### ✅ GitHub Actions CI/CD Pipeline
- **Test workflow** - Runs on every push (tests, linting, security)
- **Staging deployment** - Automatic on develop branch
- **Production deployment** - Manual with approval gates
- **System health checks** - Hourly validation of entire system
- Deployment records for audit trail

### ✅ Specialized Agent Team
- 🚀 **DevOps Engineer** - Infrastructure & deployment
- 🧪 **QA Specialist** - Testing & quality assurance
- 📦 **Release Manager** - Versioning & releases
- 🎯 **Project Orchestrator** - Coordination & workflow
- 📝 **Documentation Specialist** - Docs & communication

## Quick Start (5 minutes)

### 1. Verify Everything Is Installed

```bash
cd /home/julien/Desktop/Free-Wiggum-opencode

# Check node/npm (needed for opencode)
npm --version

# Check git
git --version

# Check Python
python3 --version
```

### 2. Make Scripts Executable

```bash
chmod +x wiggum_worker.sh
chmod +x wiggum_master.sh
chmod +x wiggum_worker_persistent.sh
chmod +x wiggum_worker_manager.sh
```

### 3. Start a Persistent Worker

For an existing project:
```bash
# Start worker for a specific project
bash wiggum_worker_manager.sh start agentic-founders-finding

# Check status
bash wiggum_worker_manager.sh status agentic-founders-finding

# View logs
bash wiggum_worker_manager.sh logs agentic-founders-finding
```

Or create a new project:
```bash
# Create new project with template
bash wiggum_master.sh create my-new-project "Description here"

# Start worker
bash wiggum_worker_manager.sh start my-new-project
```

### 4. Access the Agents

Use in Claude Code, Cursor, or any IDE:

```
Option 1: Direct mention (in Claude Code)
"@devops-engineer Set up GitHub Actions for tests on push"

Option 2: Activate mode
"Switch to DevOps Engineer mode"

Option 3: Copy to local agents
cp agents/devops-engineer.md ~/.claude/agents/
Then reference in Claude Code
```

## Typical Workflows

### Starting a New Project

```bash
# 1. Create project
bash wiggum_master.sh create my-startup "AI-powered SaaS platform"

# 2. Start persistent worker
bash wiggum_worker_manager.sh start my-startup

# 3. Project Orchestrator: Plan the work
# Activate: @project-orchestrator 
# Task: "Break down v1.0 launch into phases"

# 4. DevOps Engineer: Setup CI/CD
# Activate: @devops-engineer
# Task: "Create GitHub Actions workflows for testing and staging"

# 5. Worker runs continuously on TASKS.md
# Monitor with:
bash wiggum_worker_manager.sh status my-startup
```

### Managing Existing Projects

```bash
# Start all workers
bash wiggum_worker_manager.sh start

# List all projects and status
bash wiggum_worker_manager.sh list

# Check on one project
bash wiggum_worker_manager.sh status portfolio-website

# View last 50 lines of logs
bash wiggum_worker_manager.sh logs portfolio-website

# Stop a worker
bash wiggum_worker_manager.sh stop portfolio-website
```

### Deploying to Production

```bash
# 1. Release Manager: Prepare release
# Activate: @release-manager
# Task: "Prepare v1.0.0 release: update version, create release notes"

# 2. Create git tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 3. Use GitHub Actions to deploy
# Go to: Actions > Deploy to Production > Run Workflow
# Select version: v1.0.0
# Approve when prompted
```

### Adding Features

```bash
# 1. Create TASKS.md entries for new features
# Edit projects/my-project/TASKS.md
# Add tasks under "## Phase N: [Feature Name]"

# 2. Worker automatically processes new tasks
# No restart needed - picks up new tasks next iteration

# 3. QA Specialist: Review test coverage
# Activate: @qa-specialist
# Task: "Add tests for [new feature], aim for 80% coverage"

# 4. When complete, Release Manager adds to next version
```

## Directory Structure

```
Free-Wiggum-opencode/
├── wiggum_worker.sh                    # Single-iteration worker
├── wiggum_worker_persistent.sh         # NEW: Continuous worker
├── wiggum_worker_manager.sh            # NEW: Worker control panel
├── wiggum_master.sh                    # Project management
├── server.py                           # Web dashboard (optional)
├── .github/workflows/                  # NEW: CI/CD automation
│   ├── test.yml
│   ├── deploy-staging.yml
│   ├── deploy-production.yml
│   └── wiggum-system-check.yml
├── agents/                             # NEW: Specialist agent personalities
│   ├── AGENTS.md                       # Master guide
│   ├── devops-engineer.md
│   ├── qa-specialist.md
│   ├── release-manager.md
│   ├── project-orchestrator.md
│   └── documentation-specialist.md
├── projects/                           # Project folders
│   ├── my-project/
│   │   ├── TASKS.md                    # Project tasks
│   │   ├── src/                        # Source code
│   │   └── logs/                       # Worker logs
│   └── another-project/
└── logs/                               # Master system logs
```

## Monitoring & Health

### Check Worker Status

```bash
# View all workers
bash wiggum_worker_manager.sh list

# Example output:
# Active Projects & Worker Status
# ════════════════════════════════════════════════════════
#   agentic-founders-finding      🟢 RUNNING [45/60]
#   causal-model                  ⚫ STOPPED [8/12]
#   portfolio-website             🟢 RUNNING [12/20]
# ════════════════════════════════════════════════════════
```

### Check Individual Project

```bash
bash wiggum_worker_manager.sh status portfolio-website

# Example output:
# ════════════════════════════════════════════════════════
# Worker Status: portfolio-website
# Status: 🟢 RUNNING (PID: 12345)
# Tasks: 12/20 completed
# Recent Activity:
#   [10:30] Iteration 15: Feature A complete
#   [10:25] Iteration 14: Working on Feature B
#   [10:20] Tests passed
# ════════════════════════════════════════════════════════
```

### View Worker Logs

```bash
# Last 50 lines of session log
bash wiggum_worker_manager.sh logs portfolio-website

# Full log investigation
tail -200 projects/portfolio-website/logs/worker-sessions.log

# Iteration details
cat projects/portfolio-website/logs/iteration-23.md
```

## Using the Agent Team

### For Infrastructure Work

```
Activate: @devops-engineer

Ask them to:
- "Create GitHub Actions testing workflow"
- "Setup staging deployment on develop"
- "Create production deployment checklist"
```

### For Quality Assurance

```
Activate: @qa-specialist

Ask them to:
- "Design test suite for user auth"
- "Add integration tests"
- "Improve test coverage from 60% to 80%"
```

### For Releases

```
Activate: @release-manager

Ask them to:
- "Prepare v1.0.0 for release"
- "Create release notes"
- "Version bump and tagging"
```

### For Coordination

```
Activate: @project-orchestrator

Ask them to:
- "Break down v2.0 into phases"
- "What's blocking our progress?"
- "Create work schedule for launch"
```

### For Documentation

```
Activate: @documentation-specialist

Ask them to:
- "Update README for [feature]"
- "Create deployment runbook"
- "Document architecture decisions"
```

## Common Issues & Solutions

### "Worker not starting"

```bash
# Check if opencode-ai is installed
npm list -g opencode-ai

# Install if missing
npm install -g opencode-ai

# Verify installation
opencode --version

# Check .env has API key
cat /path/to/Free-Wiggum-opencode/.env | grep OPENROUTER_API_KEY
```

### "Worker started but not making progress"

```bash
# Check logs
bash wiggum_worker_manager.sh logs my-project

# Most common: TASKS.md has no uncompleted tasks
# Check:
grep '^- \[ \]' projects/my-project/TASKS.md

# Add tasks if none exist
echo "- [ ] My first task" >> projects/my-project/TASKS.md

# Restart worker
bash wiggum_worker_manager.sh stop my-project
bash wiggum_worker_manager.sh start my-project
```

### "GitHub Actions not triggering"

```bash
# Check .github/workflows/ files
ls -la .github/workflows/

# Verify workflow syntax
# Go to: GitHub > Actions > Check for errors

# Common fix: Push to main/develop branch
git push origin develop  # Triggers deploy-staging.yml

# Verify workflows can access secrets
# Go to: GitHub > Settings > Secrets and variables
# Check: OPENROUTER_API_KEY, GITHUB_TOKEN exist
```

### "Too many worker restarts"

```bash
# Check what's happening
tail -50 projects/my-project/logs/worker-sessions.log

# Common causes:
# 1. TASKS.md has no valid tasks
# 2. API key expired or invalid
# 3. Network connectivity issues

# Fix and restart
bash wiggum_worker_manager.sh stop my-project
# Make fixes
bash wiggum_worker_manager.sh start my-project
```

## Next Steps

### 1. Immediate (Next 30 minutes)
- [ ] Start persistent worker for one project
- [ ] Monitor status for a few iterations
- [ ] Check logs to verify it's working

### 2. This Week
- [ ] Activate one specialist agent (start with DevOps or QA)
- [ ] Have them improve your CI/CD or tests
- [ ] Create deployment to staging

### 3. This Month
- [ ] Setup full team (all 5 agents)
- [ ] Prepare and do first production release
- [ ] Document your deployment procedures

### 4. Ongoing
- [ ] Keep workers running continuously
- [ ] Use agents for specialized work
- [ ] Monitor GitHub Actions and project health
- [ ] Iterate and improve workflows

## Resources

- **Workflow Reference**: [.github/workflows/](Free-Wiggum-opencode/.github/workflows/)
- **Agent Personalities**: [agents/AGENTS.md](agents/AGENTS.md)
- **Individual Agents**: [agents/](agents/)
- **Worker Docs**: See `wiggum_worker_manager.sh list` and `--help`

## Performance Expectations

| Component | Performance |
|-----------|-------------|
| Persistent Worker | Runs continuously, restarts every hour |
| Test Suite | Completes in 2-5 minutes |
| Staging Deploy | 3-5 minutes from push to live |
| Prod Deploy | 5-10 minutes (includes approval wait) |
| Health Check | Every hour (configurable) |
| Agent Activation | Instant |

## Getting Help

### If a worker is stuck:
```bash
bash wiggum_worker_manager.sh logs project-name
# Read last 50 lines to find error
# Common: task too complex, needs breakdown by QA specialist
```

### If you're not sure what to do:
```bash
# Activate the orchestrator
# @project-orchestrator
# "What should we work on next?"
```

### If CI/CD isn't working:
```bash
# Check GitHub Actions in browser
# github.com/your-username/Free-Wiggum-opencode/actions

# Check workflow files
ls .github/workflows/
cat .github/workflows/test.yml
```

---

## You Now Have:

✅ Autonomous agent system that runs continuously
✅ Full CI/CD pipeline (test → stage → production)
✅ Specialized team of 5 agents
✅ Health monitoring and auto-recovery
✅ Deployment automation
✅ Git-based audit trail

**Start with a single worker and expand from there. Your Wiggum team is ready to work.**
