#!/bin/bash
# 🤖 Free Wiggum Master - OpenCode Multi-Project Orchestrator
# Project creation, GitHub setup, and worker management

MASTER_DIR="/home/julien/Desktop/Free-Wiggum-opencode"
PROJECTS_DIR="${MASTER_DIR}/projects"
LOGS_DIR="${MASTER_DIR}/logs"
TEMPLATE_DIR="${MASTER_DIR}/project_template"
PIDS_FILE="${LOGS_DIR}/.wiggum_pids.json"
GITHUB_USER="${GITHUB_USER:-$(git config user.name 2>/dev/null || echo 'your-github-username')}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize
mkdir -p "$PROJECTS_DIR" "$LOGS_DIR"

# Load environment variables
if [ -f "${MASTER_DIR}/.env" ]; then
    export $(cat "${MASTER_DIR}/.env" | grep -v '#' | xargs)
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Initialize or load PIDs file
init_pids_file() {
    if [ ! -f "$PIDS_FILE" ]; then
        echo "{}" > "$PIDS_FILE"
    fi
}

# Register a worker process
register_worker() {
    local project_name="$1"
    local pid="$2"
    init_pids_file
    
    # Simple JSON update (requires jq or we'll use a workaround)
    echo "{\"$project_name\": {\"pid\": $pid, \"started\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" >> "$PIDS_FILE"
}

# List active workers
list_workers() {
    log "Active Wiggum Workers:"
    echo ""
    ps aux | grep "wiggum_worker.sh" | grep -v grep | while read -r line; do
        pid=$(echo "$line" | awk '{print $2}')
        project_path=$(echo "$line" | awk -F'/' '{print $(NF-1)"/"$NF}')
        log "  PID: $pid | Project: $(basename $project_path)"
    done
    echo ""
}

# Stop a specific worker
stop_worker() {
    local project_name="$1"
    local pids=$(pgrep -f "wiggum_worker.sh.*$project_name" || echo "")
    
    if [ -z "$pids" ]; then
        warning "No running worker found for: $project_name"
        return 1
    fi
    
    # Kill each matching process
    for pid in $pids; do
        kill -9 "$pid" 2>/dev/null || true
    done
    
    success "Stopped worker for $project_name"
}

# Generate a unique TASKS.md using OpenCode based on project description
generate_tasks_md() {
    local project_path="$1"
    local project_name="$2"
    local description="$3"
    
    if [ -z "$description" ]; then
        description="Implement the $project_name project"
    fi
    
    log "Generating TASKS.md using OpenCode..."
    
    if ! command -v opencode &> /dev/null; then
        warning "OpenCode not installed. Using default template"
        cat > "${project_path}/TASKS.md" << TASKS_EOF
# $project_name

**Mission:** $description

- [ ] Setup and initialize project
- [ ] Implement core features  
- [ ] Testing and validation
- [ ] Documentation and deployment

**Created:** $(date)
TASKS_EOF
        return
    fi
    
    # Build simple, direct prompt
    local prompt="You are an expert software architect. Generate a detailed TASKS.md file for this project.

PROJECT: $project_name
DESCRIPTION: $description

Requirements:
1. Create actionable, specific tasks (not generic)
2. Include libraries/technologies mentioned in the description
3. Break into 4 phases with 3-4 tasks each
4. Each task should have concrete deliverables
5. Output ONLY the markdown file, nothing else

Format:
# $project_name
**Mission:** $description

## Phase 1: Planning & Setup
- [ ] Task 1 description
- [ ] Task 2 description

(Continue with Phases 2-4...)"
    
    # Call OpenCode and capture output
    local temp_output="/tmp/wiggum_tasks_$$.md"
    opencode run --model "${WIGGUM_MODEL:-openrouter/google/gemini-2.0-flash-exp:free}" "$prompt" > "$temp_output" 2>&1
    
    # Check if we got markdown output
    if grep -q "^#" "$temp_output" 2>/dev/null; then
        # Extract markdown section
        sed -n '/^#/,$p' "$temp_output" > "${project_path}/TASKS.md"
        success "Generated TASKS.md for $project_name"
    elif [ -s "$temp_output" ] && ! grep -q "Error\|error\|not found" "$temp_output"; then
        # Output looks valid but no header, save as-is
        cat "$temp_output" > "${project_path}/TASKS.md"
        success "Generated TASKS.md for $project_name"
    else
        # Failed, use fallback
        warning "OpenCode generation failed. Using template"
        cat > "${project_path}/TASKS.md" << TASKS_EOF
# $project_name

**Mission:** $description

## Phase 1: Setup & Planning
- [ ] Review requirements and design architecture
- [ ] Set up development environment and dependencies
- [ ] Create project structure

## Phase 2: Core Implementation  
- [ ] Implement main features
- [ ] Integrate APIs and libraries
- [ ] Build core logic

## Phase 3: Testing
- [ ] Write and run tests
- [ ] Integration testing
- [ ] Bug fixes

## Phase 4: Documentation & Deployment
- [ ] Write documentation
- [ ] Prepare deployment
- [ ] Deploy and validate

**Created:** $(date)
**Mission:** $description
TASKS_EOF
    fi
    
    rm -f "$temp_output"
}



# Create a new project from template
create_project() {
    local project_name="$1"
    local task_description="$2"
    
    if [ -z "$project_name" ]; then
        error "Project name is required"
        return 1
    fi
    
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    if [ -d "$project_path" ]; then
        warning "Project already exists: $project_path"
        return 1
    fi
    
    log "Creating new project: $project_name"
    
    # Copy template
    cp -r "$TEMPLATE_DIR" "$project_path"
    
    # Copy GitHub Actions workflows
    if [ -d "${MASTER_DIR}/.github/workflows" ]; then
        mkdir -p "${project_path}/.github/workflows"
        cp "${MASTER_DIR}/.github/workflows"/*.yml "${project_path}/.github/workflows/" 2>/dev/null || true
        success "Copied GitHub Actions workflows"
    fi
    
    # Generate unique TASKS.md based on description
    generate_tasks_md "$project_path" "$project_name" "$task_description"
    
    # NOTE: Do NOT copy .env from master - worker will handle .env setup
    # This prevents credential leaks and lets each project manage its own
    rm -f "$project_path/.env"  # Remove template .env if present
    
    # Initialize git repo
    log "Initializing git repository..."
    cd "$project_path"
    git init --initial-branch=main >/dev/null 2>&1
    git config user.email "wiggum@bot.local" >/dev/null 2>&1
    git config user.name "Wiggum Bot" >/dev/null 2>&1
    git add -A >/dev/null 2>&1
    git commit -m "Initial project template" >/dev/null 2>&1
    
    # Set up GitHub remote
    log "Setting up GitHub remote..."
    local github_repo="https://github.com/${GITHUB_USER}/${project_name}.git"
    git remote add origin "$github_repo" 2>/dev/null || git remote set-url origin "$github_repo"
    
    # Initialize OpenCode context
    log "Initializing OpenCode context..."
    if ! command -v opencode &> /dev/null; then
        warning "OpenCode not installed. Skipping AGENTS.md generation."
    else
        opencode /init --yes 2>/dev/null || warning "Could not generate AGENTS.md"
    fi
    
    # Set default agent role (can be overridden on start)
    echo "project-orchestrator" > "${project_path}/.agent_role"
    success "Project initialized with project-orchestrator agent"
    
    success "Project created: $project_path"
    log "GitHub repo setup: ${github_repo}"
    
    # Verify TASKS.md was actually created before starting worker
    if [ ! -f "${project_path}/TASKS.md" ]; then
        error "TASKS.md was not created. Worker not started."
        return 1
    fi
    
    # Remove stale TASKS_original.md so worker creates a fresh backup
    rm -f "${project_path}/TASKS_original.md"
    
    # Auto-start worker (with a short delay to ensure git operations complete)
    sleep 1
    log "Starting worker automatically..."
    cd "${MASTER_DIR}"
    nohup bash wiggum_worker.sh "$project_path" >> "${LOGS_DIR}/${project_name}.log" 2>&1 &
    local pid=$!
    register_worker "$project_name" "$pid"
    success "Worker started (PID: $pid)"
    log "Logs: ${LOGS_DIR}/${project_name}.log"
    echo ""
}

# Start a project worker with optional agent role
start_project() {
    local project_name="$1"
    local agent_role="${2:-generic}"  # Optional second parameter for agent role
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    if [ ! -d "$project_path" ]; then
        error "Project not found: $project_path"
        return 1
    fi
    
    log "Starting worker for: $project_name"
    [ "$agent_role" != "generic" ] && log "  Agent Role: $agent_role"
    
    # Check if already running
    if pgrep -f "wiggum_worker.sh.*$project_name" > /dev/null; then
        warning "Worker already running for: $project_name"
        return 1
    fi
    
    # Start worker in background with nohup to survive terminal close
    cd "$MASTER_DIR"
    if [ "$agent_role" = "generic" ]; then
        nohup bash wiggum_worker.sh "$project_path" > /dev/null 2>&1 &
    else
        nohup bash wiggum_worker.sh "$project_path" --agent "$agent_role" > /dev/null 2>&1 &
    fi
    local pid=$!
    
    register_worker "$project_name" "$pid"
    success "Worker started for $project_name (PID: $pid) with $agent_role agent"
    log "Logs available at: ${LOGS_DIR}/${project_name}.log"
    echo ""
}

# View project status
view_project_status() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"
    local log_file="${LOGS_DIR}/${project_name}.log"
    
    if [ ! -d "$project_path" ]; then
        error "Project not found: $project_path"
        return 1
    fi
    
    log "Status for project: $project_name"
    echo ""
    
    # Check if running
    if pgrep -f "wiggum_worker.sh.*$project_name" > /dev/null; then
        success "Worker is RUNNING"
    else
        warning "Worker is STOPPED"
    fi
    
    # Show task progress
    if [ -f "$project_path/TASKS.md" ]; then
        echo ""
        log "Task Progress:"
        completed=$(grep -c '^- \[x\]' "$project_path/TASKS.md" || echo "0")
        total=$(grep -c '^- \[' "$project_path/TASKS.md" || echo "0")
        echo "  Completed: $completed / $total"
        
        # Show current task
        current=$(grep -m1 '^\- \[ \]' "$project_path/TASKS.md" | sed 's/^- \[ \] //')
        if [ -n "$current" ]; then
            echo "  Current: $current"
        fi
    fi
    
    # Show recent log
    if [ -f "$log_file" ]; then
        echo ""
        log "Recent logs (last 10 lines):"
        tail -10 "$log_file" | sed 's/^/    /'
    fi
    
    echo ""
}

# View worker logs in real-time
tail_logs() {
    local project_name="$1"
    local log_file="${LOGS_DIR}/${project_name}.log"
    
    if [ ! -f "$log_file" ]; then
        error "Log file not found: $log_file"
        return 1
    fi
    
    log "Tailing logs for: $project_name (Ctrl+C to exit)"
    tail -f "$log_file"
}

# List all projects
list_projects() {
    log "All Wiggum Projects:"
    echo ""
    
    if [ ! -d "$PROJECTS_DIR" ] || [ -z "$(ls -A $PROJECTS_DIR)" ]; then
        warning "No projects found"
        return 0
    fi
    
    for project_path in "$PROJECTS_DIR"/*; do
        if [ -d "$project_path" ]; then
            project_name=$(basename "$project_path")
            
            # Check if running
            if pgrep -f "wiggum_worker.sh.*$project_name" > /dev/null; then
                status="${GREEN}[RUNNING]${NC}"
            else
                status="${YELLOW}[STOPPED]${NC}"
            fi
            
            # Get task progress
            if [ -f "$project_path/TASKS.md" ]; then
                completed=$(grep -c '^- \[x\]' "$project_path/TASKS.md" || echo "0")
                total=$(grep -c '^- \[' "$project_path/TASKS.md" || echo "0")
                progress="$completed/$total"
            else
                progress="N/A"
            fi
            
            echo -e "  ${BLUE}$project_name${NC} - $status - Tasks: $progress"
        fi
    done
    
    echo ""
}

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

show_menu() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       🐳 WIGGUM MASTER CONTROL         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "  1) Create a new project"
    echo "  2) Start a project worker"
    echo "  3) Stop a project worker"
    echo "  4) View project status"
    echo "  5) Tail project logs"
    echo "  6) List all projects"
    echo "  7) List running workers"
    echo "  8) Stop all workers"
    echo "  9) Launch voice server (localhost:5000)"
    echo "  0) Exit"
    echo ""
}

# ============================================================================
# VOICE SERVER (Flask)
# ============================================================================

start_voice_server() {
    log "Starting web server..."
    
    local server_script="${MASTER_DIR}/server.py"
    
    if [ ! -f "$server_script" ]; then
        error "voice_server.py not found. Creating it..."
        create_voice_server_script
    fi
    
    # Check if already running
    if pgrep -f "server.py" > /dev/null; then
        warning "Web server is already running on localhost:5000"
        return 1
    fi
    
    # Start server
    cd "$MASTER_DIR"
    nohup python3 server.py > "${LOGS_DIR}/server.log" 2>&1 &
    local pid=$!
    
    sleep 2
    if pgrep -f "server.py" > /dev/null; then
        success "Web server started (PID: $pid)"
        log "Open http://localhost:5000 in your browser"
    else
        error "Failed to start web server"
    fi
    
    echo ""
}

create_voice_server_script() {
    cat > "${MASTER_DIR}/voice_server.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Wiggum Voice Input Server
Simple web interface for recording voice and creating projects
"""

import os
import json
import subprocess
from datetime import datetime
from flask import Flask, render_template, request, jsonify

app = Flask(__name__)
MASTER_DIR = "/home/julien/Desktop/Free-Wiggum"

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/projects', methods=['GET'])
def get_projects():
    """Get list of all projects"""
    projects_dir = os.path.join(MASTER_DIR, 'projects')
    projects = []
    
    if os.path.exists(projects_dir):
        for project_name in os.listdir(projects_dir):
            project_path = os.path.join(projects_dir, project_name)
            if os.path.isdir(project_path):
                tasks_file = os.path.join(project_path, 'TASKS.md')
                if os.path.exists(tasks_file):
                    with open(tasks_file, 'r') as f:
                        content = f.read()
                        completed = content.count('- [x]')
                        total = content.count('- [')
                        projects.append({
                            'name': project_name,
                            'completed': completed,
                            'total': total
                        })
    
    return jsonify(projects)

@app.route('/api/workers', methods=['GET'])
def get_workers():
    """Get list of running workers"""
    import subprocess
    workers = {}
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'wiggum_worker.sh'],
            capture_output=True,
            text=True
        )
        pids = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        for pid in pids:
            if pid:
                try:
                    proc_result = subprocess.run(
                        ['ps', '-p', pid, '-o', 'cmd='],
                        capture_output=True,
                        text=True
                    )
                    cmd = proc_result.stdout.strip()
                    if 'wiggum_worker.sh' in cmd:
                        parts = cmd.split('/')
                        for i, part in enumerate(parts):
                            if part == 'projects' and i+1 < len(parts):
                                project_name = parts[i+1]
                                workers[project_name] = {'pid': int(pid), 'running': True}
                except:
                    pass
    except:
        pass
    
    return jsonify(workers)

@app.route('/api/create-project', methods=['POST'])
def create_project():
    """Create a new project"""
    data = request.json
    project_name = data.get('name', '').strip()
    description = data.get('description', '').strip()
    
    if not project_name:
        return jsonify({'error': 'Project name is required'}), 400
    
    # Sanitize project name
    project_name = ''.join(c for c in project_name if c.isalnum() or c in ('-', '_'))
    
    project_path = os.path.join(MASTER_DIR, 'projects', project_name)
    if os.path.exists(project_path):
        return jsonify({'error': 'Project already exists'}), 400
    
    try:
        # Call master script to create project
        result = subprocess.run(
            ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 
             'create', project_name, description],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            return jsonify({'error': 'Failed to create project'}), 500
        
        return jsonify({'success': True, 'message': f'Project {project_name} created'})
    
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Project creation timed out'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/start-project/<project_name>', methods=['POST'])
def start_project(project_name):
    """Start a project worker"""
    try:
        result = subprocess.run(
            ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 
             'start', project_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return jsonify({'error': 'Failed to start project'}), 500
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
@app.route('/api/stop-project/<project_name>', methods=['POST'])
def stop_project(project_name):
    \"\"\"Stop a project worker\"\"\"
    try:
        result = subprocess.run(
            ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 
             'stop', project_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return jsonify({'error': 'Failed to stop project'}), 500
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
if __name__ == '__main__':
    # Create templates directory if needed
    templates_dir = os.path.join(MASTER_DIR, 'templates')
    os.makedirs(templates_dir, exist_ok=True)
    
    app.run(debug=False, host='127.0.0.1', port=5000)

PYTHON_EOF
    
    chmod +x "${MASTER_DIR}/voice_server.py"
    success "Created voice_server.py"
}

# Create HTML template
create_html_template() {
    local templates_dir="${MASTER_DIR}/templates"
    mkdir -p "$templates_dir"
    
    cat > "${templates_dir}/index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wiggum Master Control</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Monaco', 'Courier New', monospace;
            background: linear-gradient(135deg, #1a1a2e, #16213e);
            color: #eee;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            border-bottom: 2px solid #00ff00;
        }
        h1 { color: #00ff00; font-size: 2em; margin-bottom: 10px; }
        .section {
            background: #0f3460;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            border-left: 4px solid #00ff00;
        }
        .section h2 { color: #00ff00; margin-bottom: 15px; font-size: 1.3em; }
        .form-group {
            margin-bottom: 15px;
        }
        label { display: block; margin-bottom: 5px; color: #00ccff; font-weight: bold; }
        input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            background: #1a1a2e;
            border: 1px solid #00ff00;
            color: #eee;
            border-radius: 4px;
            font-family: inherit;
        }
        button {
            background: #00ff00;
            color: #1a1a2e;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-weight: bold;
            margin-right: 10px;
            margin-top: 10px;
        }
        button:hover { background: #00ccff; }
        .projects-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 15px;
        }
        .project-card {
            background: #16213e;
            border: 1px solid #00ff00;
            padding: 15px;
            border-radius: 4px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .project-card:hover {
            background: #0f3460;
            box-shadow: 0 0 10px #00ff00;
        }
        .project-name { color: #00ff00; font-weight: bold; margin-bottom: 10px; }
        .project-progress { color: #00ccff; font-size: 0.9em; margin-bottom: 5px; }
        .project-status { color: #ffaa00; font-size: 0.85em; margin-bottom: 10px; font-weight: bold; }
        .status {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 0.8em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .status.running { background: #00ff00; color: #1a1a2e; }
        .status.stopped { background: #ff6600; color: #fff; }
        .success { color: #00ff00; }
        .error { color: #ff3333; }
        .message {
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 4px;
            border-left: 3px solid;
        }
        .message.success { background: #0a2f0a; border-color: #00ff00; color: #00ff00; }
        .message.error { background: #2f0a0a; border-color: #ff3333; color: #ff3333; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🐳 Wiggum Master Control Panel</h1>
            <p>Orchestrate multiple project workers from one dashboard</p>
        </header>

        <div class="section">
            <h2>Create New Project</h2>
            <div id="message"></div>
            <div class="form-group">
                <label for="projectName">Project Name:</label>
                <input type="text" id="projectName" placeholder="my-awesome-project">
            </div>
            <div class="form-group">
                <label for="projectDesc">Initial Task Description:</label>
                <textarea id="projectDesc" placeholder="What should Wiggum work on first?" rows="3"></textarea>
            </div>
            <button onclick="createProject()">Create & Start Project</button>
        </div>

        <div class="section">
            <h2>Active & Recent Projects</h2>
            <div class="projects-list" id="projectsList">
                <p>Loading projects...</p>
            </div>
        </div>
    </div>

    <script>
        const API_BASE = '/api';

        async function loadProjects() {
            try {
                const response = await fetch(`${API_BASE}/projects`);
                const projects = await response.json();
                
                const projectsList = document.getElementById('projectsList');
                if (projects.length === 0) {
                    projectsList.innerHTML = '<p>No projects yet. Create one above!</p>';
                    return;
                }

                projectsList.innerHTML = projects.map(p => `
                    <div class="project-card">
                        <div class="project-name">${p.name}</div>
                        <div class="project-progress">
                            Tasks: ${p.completed}/${p.total}
                        </div>
                        <div id="status-${p.name}" class="project-status">Checking...</div>
                        <div style="display: flex; gap: 5px; margin-top: 10px;">
                            <button id="btn-${p.name}" style="flex: 1;" onclick="toggleProject('${p.name}')">Start Worker</button>
                            <button style="flex: 0.5; background: #ff6600;" onclick="stopProject('${p.name}')">Stop</button>
                        </div>
                    </div>
                `).join('');
                
                // Check which projects are running
                projects.forEach(p => {
                    checkProjectStatus(p.name);
                });
            } catch (error) {
                console.error('Error loading projects:', error);
            }
        }

        async function createProject() {
            const name = document.getElementById('projectName').value.trim();
            const description = document.getElementById('projectDesc').value.trim();
            const messageDiv = document.getElementById('message');

            if (!name) {
                showMessage('Project name is required', 'error');
                return;
            }

            try {
                const response = await fetch(`${API_BASE}/create-project`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name, description })
                });

                const result = await response.json();
                if (response.ok) {
                    showMessage(`✓ Project "${name}" created!`, 'success');
                    document.getElementById('projectName').value = '';
                    document.getElementById('projectDesc').value = '';
                    loadProjects();
                } else {
                    showMessage(`✗ ${result.error}`, 'error');
                }
            } catch (error) {
                showMessage(`✗ ${error.message}`, 'error');
            }
        }

        async function checkProjectStatus(projectName) {
            try {
                const response = await fetch(`${API_BASE}/workers`);
                const workers = await response.json();
                
                const statusEl = document.getElementById(`status-${projectName}`);
                const btnEl = document.getElementById(`btn-${projectName}`);
                
                if (workers[projectName] && workers[projectName].running) {
                    if (statusEl) statusEl.innerHTML = '<span style="color: #00ff00;">● Running</span>';
                    if (btnEl) {
                        btnEl.textContent = 'Stop';
                        btnEl.onclick = () => stopProject(projectName);
                    }
                } else {
                    if (statusEl) statusEl.innerHTML = '<span style="color: #ffaa00;">● Stopped</span>';
                    if (btnEl) {
                        btnEl.textContent = 'Start';
                        btnEl.onclick = () => startProject(projectName);
                    }
                }
            } catch (error) {
                console.error('Error checking status:', error);
            }
        }

        async function toggleProject(projectName) {
            // Check current state and toggle
            const btnEl = document.getElementById(`btn-${projectName}`);
            const btnText = btnEl.textContent.trim();
            
            if (btnText === 'Start Worker' || btnText === 'Start') {
                startProject(projectName);
            } else {
                stopProject(projectName);
            }
        }

        async function startProject(projectName) {
            try {
                const response = await fetch(`${API_BASE}/start-project/${projectName}`, {
                    method: 'POST'
                });

                if (response.ok) {
                    showMessage(`✓ Started worker for "${projectName}"`, 'success');
                    setTimeout(() => {
                        loadProjects();
                        checkProjectStatus(projectName);
                    }, 1000);
                } else {
                    const result = await response.json();
                    showMessage(`✗ ${result.error}`, 'error');
                }
            } catch (error) {
                showMessage(`✗ ${error.message}`, 'error');
            }
        }

        async function stopProject(projectName) {
            try {
                const response = await fetch(`${API_BASE}/stop-project/${projectName}`, {
                    method: 'POST'
                });

                if (response.ok) {
                    showMessage(`✓ Stopped worker for "${projectName}"`, 'success');
                    setTimeout(() => {
                        loadProjects();
                        checkProjectStatus(projectName);
                    }, 500);
                } else {
                    const result = await response.json();
                    showMessage(`✗ ${result.error}`, 'error');
                }
            } catch (error) {
                showMessage(`✗ ${error.message}`, 'error');
            }
        }

        function showMessage(text, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.className = `message ${type}`;
            messageDiv.textContent = text;
        }

        // Load projects on page load
        loadProjects();
        // Refresh project list every 5 seconds
        setInterval(loadProjects, 5000);
        // Check worker status every 2 seconds for live updates
        setInterval(() => {
            document.querySelectorAll('.project-card .project-name').forEach(card => {
                const projectName = card.textContent.trim();
                checkProjectStatus(projectName);
            });
        }, 2000);
    </script>
</body>
</html>
HTML_EOF

    success "Created HTML template"
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    init_pids_file
    
    if [ $# -gt 0 ]; then
        # Command-line mode
        case "$1" in
            create)
                create_project "$2" "$3"
                ;;
            start)
                start_project "$2"
                ;;
            stop)
                stop_worker "$2"
                ;;
            status)
                view_project_status "$2"
                ;;
            list)
                list_projects
                ;;
            running)
                list_workers
                ;;
            stop-all)
                stop_all_workers
                ;;
            voice)
                start_voice_server
                ;;
            *)
                echo "Unknown command: $1"
                echo "Usage: $0 [create|start|stop|status|list|running|stop-all|voice]"
                exit 1
                ;;
        esac
    else
        # Interactive mode
        while true; do
            show_menu
            read -p "➜ Select option: " choice
            
            case $choice in
                1)
                    read -p "Enter project name: " proj_name
                    read -p "Enter initial task (optional): " task_desc
                    create_project "$proj_name" "$task_desc"
                    ;;
                2)
                    list_projects
                    read -p "Enter project name to start: " proj_name
                    start_project "$proj_name"
                    ;;
                3)
                    list_projects
                    read -p "Enter project name to stop: " proj_name
                    stop_worker "$proj_name"
                    ;;
                4)
                    read -p "Enter project name: " proj_name
                    view_project_status "$proj_name"
                    ;;
                5)
                    read -p "Enter project name: " proj_name
                    tail_logs "$proj_name"
                    ;;
                6)
                    list_projects
                    ;;
                7)
                    list_workers
                    ;;
                8)
                    read -p "Are you sure? (y/n): " confirm
                    [ "$confirm" = "y" ] && stop_all_workers
                    ;;
                9)
                    create_html_template
                    start_voice_server
                    ;;
                0)
                    log "Exiting..."
                    exit 0
                    ;;
                *)
                    error "Invalid option"
                    ;;
            esac
            
            read -p "Press Enter to continue..."
        done
    fi
}

# Run main function
main "$@"
