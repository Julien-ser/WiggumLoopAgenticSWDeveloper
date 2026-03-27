#!/usr/bin/env python3
"""
Wiggum Web Server - Simple text-based control panel
Web interface for creating and managing projects
"""

import os
import json
import subprocess
import re
import tempfile
from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename

# File parsing imports
try:
    from docx import Document
except ImportError:
    Document = None

try:
    import PyPDF2
except ImportError:
    PyPDF2 = None

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024  # 10MB max
MASTER_DIR = "/home/julien/Desktop/Free-Wiggum-opencode"
ALLOWED_EXTENSIONS = {'txt', 'pdf', 'docx'}

@app.route('/')
def index():
    """Main dashboard"""
    return render_template('index.html')

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def extract_text_from_file(file_path):
    """Extract text from txt, docx, or pdf files"""
    file_ext = file_path.rsplit('.', 1)[1].lower()
    
    try:
        if file_ext == 'txt':
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        
        elif file_ext == 'docx':
            if not Document:
                return f"Error: python-docx not installed. Install with: pip install python-docx"
            doc = Document(file_path)
            text = '\n'.join([paragraph.text for paragraph in doc.paragraphs])
            return text
        
        elif file_ext == 'pdf':
            if not PyPDF2:
                return f"Error: PyPDF2 not installed. Install with: pip install PyPDF2"
            text = []
            with open(file_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                for page in reader.pages:
                    text.append(page.extract_text())
            return '\n'.join(text)
        
        else:
            return f"Unsupported file type: {file_ext}"
    
    except Exception as e:
        return f"Error extracting text: {str(e)}"

@app.route('/api/extract-text', methods=['POST'])
def extract_text():
    """Extract text from uploaded file"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if not allowed_file(file.filename):
        return jsonify({'error': 'File type not allowed. Use txt, docx, or pdf'}), 400
    
    try:
        # Save temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file.filename.rsplit('.', 1)[1]}") as tmp:
            file.save(tmp.name)
            
            # Extract text
            text = extract_text_from_file(tmp.name)
            
            # Clean up
            os.unlink(tmp.name)
            
            # Check if it's an error message
            if text.startswith('Error'):
                return jsonify({'error': text}), 500
            
            return jsonify({'text': text.strip()})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/projects', methods=['GET'])
def get_projects():
    """Get list of all projects with status and agent role"""
    projects_dir = os.path.join(MASTER_DIR, 'projects')
    active_projects = []
    completed_projects = []
    
    if os.path.exists(projects_dir):
        for project_name in sorted(os.listdir(projects_dir)):
            project_path = os.path.join(projects_dir, project_name)
            if os.path.isdir(project_path):
                tasks_file = os.path.join(project_path, 'TASKS.md')
                
                # Check if worker is running
                try:
                    result = subprocess.run(
                        ['pgrep', '-f', f'wiggum_worker.sh.*{project_name}'],
                        capture_output=True
                    )
                    is_running = result.returncode == 0
                except:
                    is_running = False
                
                # Get active agent role
                agent_role = 'generic'
                agent_file = os.path.join(project_path, '.agent_role')
                if os.path.exists(agent_file):
                    try:
                        with open(agent_file, 'r') as f:
                            agent_role = f.read().strip()
                    except:
                        agent_role = 'generic'
                
                # Get task progress
                completed = 0
                total = 0
                current_task = ""
                is_completed = False
                iteration = 0
                
                if os.path.exists(tasks_file):
                    with open(tasks_file, 'r') as f:
                        content = f.read()
                        completed = content.count('- [x]')
                        total = content.count('- [')
                        
                        # Check if all tasks are done
                        is_completed = (total > 0 and completed == total)
                        
                        # Get current task
                        if not is_completed:
                            for line in content.split('\n'):
                                if line.startswith('- [ ]'):
                                    current_task = line.replace('- [ ] ', '').strip()
                                    break
                
                # Get latest iteration number from logs
                logs_dir = os.path.join(project_path, 'logs')
                if os.path.exists(logs_dir):
                    import glob
                    iteration_files = glob.glob(os.path.join(logs_dir, 'iteration-*.md'))
                    if iteration_files:
                        for f in iteration_files:
                            match = re.search(r'iteration-(\d+)', f)
                            if match:
                                iter_num = int(match.group(1))
                                iteration = max(iteration, iter_num)
                
                project_data = {
                    'name': project_name,
                    'completed': completed,
                    'total': total,
                    'is_running': is_running,
                    'current_task': current_task,
                    'is_completed': is_completed,
                    'iteration': iteration,
                    'agent_role': agent_role
                }
                
                if is_completed:
                    completed_projects.append(project_data)
                else:
                    active_projects.append(project_data)
    
    return jsonify({
        'active': active_projects,
        'completed': completed_projects
    })

@app.route('/api/create-project', methods=['POST'])
def create_project():
    """Create a new project from text input"""
    data = request.json
    project_name = data.get('name', '').strip()
    description = data.get('description', '').strip()
    auto_start = data.get('auto_start', True)
    
    if not project_name:
        return jsonify({'error': 'Project name is required'}), 400
    
    # Sanitize project name
    project_name = re.sub(r'[^a-zA-Z0-9\-_]', '-', project_name)
    project_name = project_name.lower().strip('-')
    
    if not project_name:
        return jsonify({'error': 'Invalid project name'}), 400
    
    project_path = os.path.join(MASTER_DIR, 'projects', project_name)
    if os.path.exists(project_path):
        return jsonify({'error': f'Project "{project_name}" already exists'}), 400
    
    try:
        # Call master script to create project
        result = subprocess.run(
            ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 
             'create', project_name, description],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            error_msg = result.stderr if result.stderr else 'Failed to create project'
            return jsonify({'error': error_msg}), 500
        
        # Auto-start if requested
        if auto_start:
            subprocess.run(
                ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 
                 'start', project_name],
                capture_output=True,
                timeout=10
            )
        
        return jsonify({
            'success': True, 
            'message': f'✓ Project "{project_name}" created',
            'name': project_name
        })
    
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Project creation timed out'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/start-project/<project_name>', methods=['POST'])
def start_project(project_name):
    """Start a project worker with optional agent role"""
    data = request.json or {}
    agent_role = data.get('agent_role', 'generic')
    
    try:
        # Get worker mode preference (persistent by default in new version)
        persistent = data.get('persistent', False)  # Optional flag
        
        cmd = ['bash', os.path.join(MASTER_DIR, 'wiggum_master.sh'), 'start', project_name, agent_role]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return jsonify({'error': 'Failed to start project'}), 500
        
        mode_str = 'persistent' if persistent else 'session'
        return jsonify({'success': True, 'message': f'Started {mode_str} worker for {project_name} with {agent_role} agent'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stop-project/<project_name>', methods=['POST'])
def stop_project(project_name):
    """Stop a project worker"""
    try:
        import subprocess
        
        # Find PIDs for this project
        result = subprocess.run(
            ['pgrep', '-f', f'wiggum_worker.sh.*{project_name}'],
            capture_output=True,
            text=True
        )
        
        if result.stdout.strip():
            # Kill all matching processes with SIGKILL (-9)
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid:
                    try:
                        subprocess.run(['kill', '-9', pid], timeout=5)
                    except:
                        pass
            return jsonify({'success': True, 'message': f'Stopped worker for {project_name}'})
        else:
            return jsonify({'success': False, 'message': 'No running worker found'}), 400
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/push-project/<project_name>', methods=['POST'])
def push_project(project_name):
    """Run checks and push for completed projects"""
    project_path = os.path.join(MASTER_DIR, 'projects', project_name)
    
    if not os.path.exists(project_path):
        return jsonify({'error': f'Project "{project_name}" not found'}), 404
    
    try:
        # Run worker in background to ensure push
        result = subprocess.Popen(
            ['bash', os.path.join(MASTER_DIR, 'wiggum_worker.sh'), project_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        return jsonify({
            'success': True, 
            'message': f'Running verification and push for {project_name}',
            'pid': result.pid
        })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/project/<project_name>/trigger_coderabbit', methods=['POST'])
def trigger_coderabbit(project_name):
    """Trigger a CodeRabbit review by appending a timestamp to a touch file and pushing to PR branch"""
    project_path = os.path.join(MASTER_DIR, 'projects', project_name)
    if not os.path.exists(project_path):
        return jsonify({'error': f'Project "{project_name}" not found'}), 404
    try:
        # Find open PR's head branch for this repo
        result = subprocess.run(
            ['gh', 'pr', 'list', '--repo', f'Julien-ser/{project_name}', '--json', 'headRefName', '-q', '.[0].headRefName'],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=10
        )
        head_ref = result.stdout.strip()
        if not head_ref:
            return jsonify({'error': 'No open PR found'}), 404
        # Checkout that branch
        subprocess.run(['git', 'checkout', head_ref], cwd=project_path, check=True, capture_output=True)
        # Append timestamp to a trigger file to ensure code change
        trigger_file = os.path.join(project_path, '.coderabbit_trigger.log')
        with open(trigger_file, 'a') as f:
            f.write(f"Triggered at: {subprocess.run(['date'], capture_output=True, text=True).stdout}")
        subprocess.run(['git', 'add', trigger_file], cwd=project_path, check=True, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'Trigger CodeRabbit review'], cwd=project_path, check=True, capture_output=True)
        subprocess.run(['git', 'push', 'origin', head_ref], cwd=project_path, check=True, capture_output=True)
        return jsonify({'status': 'triggered', 'branch': head_ref})
    except subprocess.CalledProcessError as e:
        return jsonify({'error': str(e), 'details': e.stderr}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/<project_name>', methods=['GET'])
def get_logs(project_name):
    """Get iteration logs for a project"""
    import glob
    
    logs_dir = os.path.join(MASTER_DIR, 'projects', project_name, 'logs')
    logs = []
    
    # Debug: Check if directory exists
    if not os.path.exists(logs_dir):
        return jsonify({
            'logs': [],
            'debug': f'logs directory not found: {logs_dir}'
        })
    
    # Get all iteration files
    iteration_files = glob.glob(os.path.join(logs_dir, 'iteration-*.md'))
    
    # If no files found, try with different log names
    if not iteration_files:
        iteration_files = glob.glob(os.path.join(logs_dir, '*.md'))
    
    # Sort numerically by iteration number (not lexicographically)
    def get_iteration_number(filepath):
        filename = os.path.basename(filepath)
        match = re.search(r'iteration-(\d+)', filename)
        return int(match.group(1)) if match else 0
    
    iteration_files = sorted(iteration_files, key=get_iteration_number)
    
    # Return newest iterations first (reverse order)
    for log_file in reversed(iteration_files[-10:]):  # Last 10 iterations, newest first
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                content = f.read()
                # Extract iteration number from filename
                iteration = os.path.basename(log_file).replace('iteration-', '').replace('.md', '')
                
                logs.append({
                    'iteration': iteration,
                    'content': content,  # Return full content
                    'filename': os.path.basename(log_file)
                })
        except Exception as e:
            logs.append({
                'iteration': 'error',
                'content': f'Error reading {os.path.basename(log_file)}: {str(e)}',
                'filename': os.path.basename(log_file)
            })
    
    return jsonify({
        'logs': logs,
        'total': len(iteration_files),
        'logs_dir': logs_dir
    })

@app.route('/api/project-details/<project_name>', methods=['GET'])
def get_project_details(project_name):
    """Get detailed information about a project including pipeline status, agents, config, and logs"""
    project_path = os.path.join(MASTER_DIR, 'projects', project_name)
    
    if not os.path.exists(project_path):
        return jsonify({'error': f'Project "{project_name}" not found'}), 404
    
    try:
        # Determine pipeline status based on tasks and logs
        tasks_file = os.path.join(project_path, 'TASKS.md')
        pipeline_status = {
            'setup': False,
            'development': False,
            'testing': False,
            'staging': False,
            'production': False,
            'current': 'setup'
        }
        
        # Read TASKS.md to determine progress
        completed_tasks = 0
        total_tasks = 0
        
        if os.path.exists(tasks_file):
            with open(tasks_file, 'r') as f:
                content = f.read()
                completed_tasks = content.count('- [x]')
                total_tasks = content.count('- [')
        
        # Simple heuristic: based on completion percentage, determine pipeline stage
        if total_tasks > 0:
            completion_pct = (completed_tasks / total_tasks) * 100
            
            if completion_pct >= 100:
                pipeline_status['production'] = True
                pipeline_status['staging'] = True
                pipeline_status['testing'] = True
                pipeline_status['development'] = True
                pipeline_status['setup'] = True
                pipeline_status['current'] = 'production'
            elif completion_pct >= 80:
                pipeline_status['staging'] = True
                pipeline_status['testing'] = True
                pipeline_status['development'] = True
                pipeline_status['setup'] = True
                pipeline_status['current'] = 'staging'
            elif completion_pct >= 60:
                pipeline_status['testing'] = True
                pipeline_status['development'] = True
                pipeline_status['setup'] = True
                pipeline_status['current'] = 'testing'
            elif completion_pct >= 30:
                pipeline_status['development'] = True
                pipeline_status['setup'] = True
                pipeline_status['current'] = 'development'
            else:
                pipeline_status['setup'] = True
                pipeline_status['current'] = 'setup'
        else:
            pipeline_status['setup'] = True
            pipeline_status['current'] = 'setup'
        
        # Get assigned agents based on what we know
        agents = [
            {
                'name': 'Project Orchestrator',
                'role': 'Multi-Agent Coordinator',
                'active': True
            },
            {
                'name': 'QA Specialist',
                'role': 'Testing & Quality',
                'active': completed_tasks > 0
            },
            {
                'name': 'DevOps Engineer',
                'role': 'Infrastructure & CI/CD',
                'active': completion_pct >= 60 if total_tasks > 0 else False
            },
            {
                'name': 'Release Manager',
                'role': 'Release Coordination',
                'active': completion_pct >= 80 if total_tasks > 0 else False
            },
            {
                'name': 'Documentation Specialist',
                'role': 'Docs & Communication',
                'active': True
            }
        ]
        
        # Get currently active agent role
        active_agent_role = 'generic'
        agent_file = os.path.join(project_path, '.agent_role')
        if os.path.exists(agent_file):
            try:
                with open(agent_file, 'r') as f:
                    active_agent_role = f.read().strip()
            except:
                pass
        
        # Get configuration
        config_items = [
            {'key': 'Project Name', 'value': project_name},
            {'key': 'Status', 'value': f'{completed_tasks}/{total_tasks} tasks'},
            {'key': 'Completion', 'value': f'{(completed_tasks / total_tasks * 100):.1f}%' if total_tasks > 0 else '0%'},
            {'key': 'Stage', 'value': pipeline_status['current'].title()},
            {'key': 'Project Path', 'value': f'projects/{project_name}'},
            {'key': 'Created', 'value': 'OpenCode AI'},
            {'key': 'Git Remote', 'value': 'github.com (configured)'},
            {'key': 'Worker Status', 'value': 'Running' if is_project_running(project_name) else 'Stopped'}
        ]
        
        # Get latest log content
        logs_dir = os.path.join(project_path, 'logs')
        latest_log_content = ""
        latest_iteration = 0
        
        if os.path.exists(logs_dir):
            import glob
            iteration_files = glob.glob(os.path.join(logs_dir, 'iteration-*.md'))
            
            if iteration_files:
                # Find the latest iteration
                latest_file = None
                for f in iteration_files:
                    match = re.search(r'iteration-(\d+)', f)
                    if match:
                        iter_num = int(match.group(1))
                        if iter_num > latest_iteration:
                            latest_iteration = iter_num
                            latest_file = f
                
                if latest_file:
                    try:
                        with open(latest_file, 'r', encoding='utf-8') as f:
                            latest_log_content = f.read()
                    except:
                        latest_log_content = "(Could not read latest log)"
        
        if not latest_log_content:
            latest_log_content = "No logs available yet. Worker may not have started."
        
        return jsonify({
            'project_name': project_name,
            'pipeline': {
                'setup': pipeline_status['setup'],
                'development': pipeline_status['development'],
                'testing': pipeline_status['testing'],
                'staging': pipeline_status['staging'],
                'production': pipeline_status['production'],
                'current': pipeline_status['current']
            },
            'agents': agents,
            'active_agent_role': active_agent_role,
            'config': config_items,
            'latest_log': latest_log_content,
            'latest_iteration': latest_iteration
        })
    
    except Exception as e:
        return jsonify({'error': f'Error getting project details: {str(e)}'}), 500

def is_project_running(project_name):
    """Check if a project worker is currently running"""
    try:
        result = subprocess.run(
            ['pgrep', '-f', f'wiggum_worker.sh.*{project_name}'],
            capture_output=True
        )
        return result.returncode == 0
    except:
        return False

if __name__ == '__main__':
    # Create templates directory if needed
    templates_dir = os.path.join(MASTER_DIR, 'templates')
    os.makedirs(templates_dir, exist_ok=True)
    
    print("🌐 Wiggum Web Server starting...")
    print("📍 http://localhost:5000")
    print("")
    
    app.run(debug=False, host='0.0.0.0', port=5000, threaded=True)
