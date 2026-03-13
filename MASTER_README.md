# Free Wiggum OpenCode: Master System Architecture

A centralized master orchestration system for managing multiple autonomous OpenCode agent projects.

## Architecture

```
Free-Wiggum-opencode/              # Master system repo (GitHub)
├── wiggum.sh                       # System master loop (OpenCode)
├── wiggum_master.sh                # Project management CLI
├── voice_server.py                 # Web dashboard (optional)
├── prompt.txt                      # System instructions
├── TASKS.md                        # System-level task tracking
├── AGENTS.md                       # System context (auto-generated)
├── .env                            # OpenRouter API key config
├── project_template/               # Template for new projects
│   ├── README.md
│   ├── TASKS.md
│   ├── prompt.txt
│   └── src/
└── projects/                       # All projects (each has own repo)
    ├── project-1/                  # Separate GitHub repo
    │   ├── wiggum.sh               # Project-specific agent loop
    │   ├── TASKS.md                # Project task tracking
    │   ├── prompt.txt              # Project instructions
    │   ├── AGENTS.md               # Project context
    │   └── src/                    # Project source code
    └── project-2/
        └── ...
```

## Master vs. Project Repos

**Master Repo (This Repo)**
- Central orchestration and system management
- Voice server dashboard
- Project template and creation tools
- System-level TASKS.md
- GitHub: `github.com/yourname/Free-Wiggum-opencode`

**Project Repos**
- Each project in `projects/my-project/` is a separate GitHub repository
- Independent development and deployment
- GitHub: `github.com/yourname/my-project`
- Each has its own OpenCode agent loop

## Quick Start

### 1. Initialize Master System

```bash
cd /home/julien/Desktop/Free-Wiggum-opencode
npm i -g opencode-ai
cat > .env << 'EOF'
OPENROUTER_API_KEY=sk-or-v1-...
WIGGUM_MODEL=openrouter/google/gemini-2.0-flash-exp:free
EOF
opencode /init --yes
```

### 2. Create First Project

```bash
bash wiggum_master.sh create "my-api" "Build a REST API server"
```

This:
- Creates `projects/my-api/`
- Initializes from `project_template/`
- Sets up Git remote to GitHub
- Ready for agent to start working

### 3. Start Master Loop

```bash
bash wiggum.sh
```

Or interactive control panel:

```bash
bash wiggum_master.sh
```

## How It Works

### System-Level Loop (wiggum.sh)
1. Reads system TASKS.md
2. Completes system-level tasks (project creation, infrastructure)
3. Delegates project work to individual project agents
4. Updates system state

### Project-Level Loop (projects/*/wiggum.sh)
1. Each project has its own OpenCode agent
2. Agent reads project TASKS.md
3. Implements features independently
4. Pushes commits to project's GitHub repo

### Example System Task

```markdown
- [ ] Create new project "payment-processor" with Node.js + Express backend
```

When completed:
1. Master agent creates `projects/payment-processor/`
2. Updates GitHub remote
3. Project is ready for autonomous development
4. Master updates TASKS.md with [x]

## Command-Line Interface

```bash
# List all projects
bash wiggum_master.sh list

# Create new project
bash wiggum_master.sh create "project-name" "description"

# Start project agent loop
bash wiggum_master.sh start "project-name"

# View project status
bash wiggum_master.sh status "project-name"

# Stop a project
bash wiggum_master.sh stop "project-name"

# Launch voice server dashboard
bash wiggum_master.sh voice
```

## Multi-Repo Git Strategy

### Master Repo Structure
```bash
git remote add origin https://github.com/yourname/Free-Wiggum-opencode
git push origin main        # Pushes master system code
```

### Project Repos
Each project auto-initializes:
```bash
cd projects/my-project
git init
git remote add origin https://github.com/yourname/my-project
git add .
git commit -m "Initial project template"
git push -u origin main
```

Agent handles all commits within project repo independently.

## System Capabilities

- ✅ Unlimited projects (one master system, many autonomous agents)
- ✅ No Python venvs required (only if technically necessary)
- ✅ Multi-repo GitHub management (master + individual projects)
- ✅ Autonomous agents (no human intervention)
- ✅ Voice server for monitoring (optional)
- ✅ 64k token budget per iteration
- ✅ Zero cost (OpenRouter free tier)

## Architecture

```
Free-Wiggum/
├── wiggum_master.sh          # Main orchestrator (interactive CLI + command-line mode)
├── wiggum_worker.sh          # Individual project worker (runs in background)
├── voice_server.py           # Flask web server for voice input & project creation
├── project_template/         # Template for new projects
│   ├── .env.template
│   ├── TASKS.md
│   └── prompt.txt
├── projects/                 # All project directories created here
│   ├── project_1/
│   │   ├── .env
│   │   ├── TASKS.md
│   │   ├── prompt.txt
│   │   ├── venv_wiggum/      # Isolated Python environment
│   │   └── prompt-*.md       # Iteration logs
│   └── project_2/
│       └── ...
├── logs/                     # Output logs from all workers
│   ├── project_1.log
│   ├── project_2.log
│   └── voice_server.log
└── README.md                 # This file
```

## Quick Start

### 1. Setup Master Environment

```bash
cd /home/julien/Desktop/Free-Wiggum

# Install Flask for voice server (optional, if you want the web UI)
python3 -m pip install -r requirements-master.txt
```

### 2. Interactive Control Panel (Recommended)

```bash
bash wiggum_master.sh
```

This opens an interactive menu with options:
- Create new projects
- Start/stop individual workers
- View project status
- Tail live logs
- Launch voice server

### 3. Command-Line Mode (For Scripts/Automation)

```bash
# Create a new project
bash wiggum_master.sh create "my-project" "Build a REST API"

# Start a worker for a project
bash wiggum_master.sh start "my-project"

# View project status
bash wiggum_master.sh status "my-project"

# List all projects
bash wiggum_master.sh list

# List running workers
bash wiggum_master.sh running

# Stop a project
bash wiggum_master.sh stop "my-project"

# Stop all workers
bash wiggum_master.sh stop-all

# Start voice input server
bash wiggum_master.sh voice
```

### 4. Voice Input Server (Optional)

```bash
bash wiggum_master.sh voice
```

Opens a web dashboard at **http://localhost:5000** where you can:
- View all projects and their progress
- Create new projects with voice input
- Start workers directly from the dashboard
- Monitor real-time task completion

## How It Works

### Worker Lifecycle

1. **Project Creation** (`wiggum_master.sh create`)
   - Copies template files to `projects/<name>/`
   - Creates isolated Python venv
   - Initializes `.env` with API key
   - Sets up initial TASKS.md

2. **Worker Start** (`wiggum_master.sh start`)
   - Launches `wiggum_worker.sh` in background
   - Worker activates venv
   - Loads environment variables
   - Begins iteration loop (same as original Wiggum)

3. **Iteration Loop** (in worker process)
   - Reads next incomplete task from TASKS.md
   - Builds dynamic prompt with project context
   - Calls aider with OpenRouter API
   - Marks completed tasks with `[x]`
   - Continues until MISSION ACCOMPLISHED

4. **Output & Logs**
   - All output captured to `logs/<project_name>.log`
   - One log file per project
   - Iteration prompts saved as `prompt-N.md` in project dir
   - Can be tailed in real-time: `tail -f logs/project_name.log`

## Configuration

### Project-Level Configuration

Each project has a `.env` file:
```bash
OPENROUTER_API_KEY=sk_...
WIGGUM_MODEL=openrouter/stepfun/step-3.5-flash:free
```

Customize the model by editing `.env` in individual project folder.

### Global Environment Variable

Set `OPENROUTER_API_KEY` before running master to auto-populate all new projects:
```bash
export OPENROUTER_API_KEY="your_key_here"
bash wiggum_master.sh
```

## Monitoring & Debugging

### View Active Workers
```bash
bash wiggum_master.sh running
```

### Check Project Status
```bash
bash wiggum_master.sh status "my-project"
```

Shows:
- Running status
- Task progress
- Current task
- Recent logs

### Tail Project Logs in Real-Time
```bash
tail -f logs/my-project.log
```

### Check Iteration Details
Each iteration saves its prompt:
```bash
cat projects/my-project/prompt-42.md
```

### Find Errors in Logs
```bash
grep -n "Error\|error\|ERROR" logs/my-project.log
```

## Best Practices

1. **Descriptive Project Names**
   - Use hyphens: `api-backend`, `scraper-bot`, `data-pipeline`
   - Avoid spaces and special characters

2. **Clear Initial Task Descriptions**
   - Be specific about what you want done
   - Include context about goals and constraints
   - Example: "Create a Python FastAPI server with CRUD endpoints for a todo list"

3. **Update TASKS.md Manually**
   - If a worker gets stuck, manually edit `projects/<name>/TASKS.md`
   - Break down stuck tasks into smaller steps
   - Remove and re-add problematic tasks

4. **Monitor Multiple Projects**
   - Use `list_projects` regularly to check progress
   - Start simple projects first to validate setup
   - Scale up to concurrent workers once comfortable

5. **Clean Up Old Projects**
   ```bash
   rm -rf projects/old-project
   ```

## Troubleshooting

### Worker Not Starting

Check if venv setup failed:
```bash
cd projects/my-project
python3.12 -m venv venv_wiggum
source venv_wiggum/bin/activate
pip install aider-chat
```

### "Virtual environment not found" Error

The worker auto-creates it, but verify:
```bash
ls -la projects/my-project/venv_wiggum/
```

### API Key Issues

Verify `.env` is set correctly:
```bash
cat projects/my-project/.env | grep OPENROUTER
```

### Worker Stuck on Task

1. View iteration details:
   ```bash
   tail -20 projects/my-project/prompt-*.md
   ```

2. Check the error in logs:
   ```bash
   tail -50 logs/my-project.log | grep -A5 "Error"
   ```

3. Manually edit TASKS.md to split the task or skip it:
   ```bash
   vim projects/my-project/TASKS.md
   ```

4. Restart the worker:
   ```bash
   bash wiggum_master.sh stop "my-project"
   bash wiggum_master.sh start "my-project"
   ```

### Multiple Workers Running

Check what's running:
```bash
ps aux | grep wiggum_worker
```

Stop all safely:
```bash
bash wiggum_master.sh stop-all
```

## Advanced Usage

### Parallel Project Execution

Start multiple workers for different projects:
```bash
bash wiggum_master.sh start "project-1" &
bash wiggum_master.sh start "project-2" &
bash wiggum_master.sh start "project-3" &
```

Each runs independently with isolated environments and logs.

### Custom Prompt Template

Edit `project_template/prompt.txt` to change agent behavior for all future projects.

### Integration with Scripts

```bash
#!/bin/bash
# auto_start.sh - Automatically start workers for all projects

for project in /home/julien/Desktop/Free-Wiggum/projects/*/; do
    project_name=$(basename "$project")
    bash /home/julien/Desktop/Free-Wiggum/wiggum_master.sh start "$project_name"
done
```

## Files Reference

| File | Purpose |
|------|---------|
| `wiggum_master.sh` | Main orchestrator with CLI and interactive menu |
| `wiggum_worker.sh` | Individual project worker (run as subprocess) |
| `voice_server.py` | Flask web server for voice input & dashboard |
| `project_template/.env.template` | Template for API credentials |
| `project_template/TASKS.md` | Template for task lists |
| `project_template/prompt.txt` | Template for agent instructions |

## Future Enhancements

- [ ] Voice transcription integration (Whisper, Ollama)
- [ ] Web dashboard for monitoring all workers
- [ ] Email notifications on task completion
- [ ] Database for tracking project history
- [ ] Integration with version control (git auto-commit)
- [ ] Metrics & reporting dashboard
- [ ] Support for different AI models per project
- [ ] Scheduled job execution (run projects on cron)

---

**Wiggum Master** - Autonomous workforce orchestration 🐳
