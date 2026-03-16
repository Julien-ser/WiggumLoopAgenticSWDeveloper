#!/bin/bash
# 🎮 Wiggum Worker Manager - Start/stop/monitor persistent workers
# Usage: bash wiggum_worker_manager.sh [start|stop|status|list|logs] [project-name]

MASTER_DIR="/home/julien/Desktop/Free-Wiggum-opencode"
PROJECTS_DIR="$MASTER_DIR/projects"
LOGS_DIR="$MASTER_DIR/logs"
STATE_DIR="$MASTER_DIR/.wiggum-state"

mkdir -p "$STATE_DIR" "$LOGS_DIR"

GREENTEXT='\033[0;32m'
REDTEXT='\033[0;31m'
YELLOWTEXT='\033[1;33m'
BLUETEXT='\033[0;34m'
NOCOLOR='\033[0m'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() { echo -e "${BLUETEXT}[$(date '+%H:%M:%S')]${NOCOLOR} $1"; }
success() { echo -e "${GREENTEXT}✓${NOCOLOR} $1"; }
error() { echo -e "${REDTEXT}✗${NOCOLOR} $1"; }
warning() { echo -e "${YELLOWTEXT}!${NOCOLOR} $1"; }

WORKER_SCRIPT="$MASTER_DIR/wiggum_worker_persistent.sh"

if [ ! -f "$WORKER_SCRIPT" ]; then
    error "Worker script not found: $WORKER_SCRIPT"
    exit 1
fi

# ============================================================================
# COMMANDS
# ============================================================================

cmd_start() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        # Start all projects that have TASKS.md
        for proj_dir in "$PROJECTS_DIR"/*; do
            if [ -d "$proj_dir" ] && [ -f "$proj_dir/TASKS.md" ]; then
                proj_name=$(basename "$proj_dir")
                cmd_start "$proj_name"
            fi
        done
        return
    fi
    
    local project_dir="$PROJECTS_DIR/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        error "Project not found: $project_name"
        return 1
    fi
    
    local pid_file="$STATE_DIR/${project_name}.pid"
    
    # Check if already running
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            warning "Worker already running for '$project_name' (PID: $old_pid)"
            return 1
        else
            log "Stale PID file found - cleaning up"
            rm "$pid_file"
        fi
    fi
    
    # Start worker in background
    log "Starting persistent worker for: $project_name"
    nohup bash "$WORKER_SCRIPT" "$project_dir" > "$LOGS_DIR/worker-$project_name.output.log" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$pid_file"
    
    success "Worker started (PID: $new_pid)"
    log "Output: $LOGS_DIR/worker-$project_name.output.log"
    log "Session log: $project_dir/logs/worker-sessions.log"
}

cmd_stop() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        # Stop all workers
        for pid_file in "$STATE_DIR"/*.pid; do
            if [ -f "$pid_file" ]; then
                proj_name=$(basename "$pid_file" .pid)
                cmd_stop "$proj_name"
            fi
        done
        return
    fi
    
    local pid_file="$STATE_DIR/${project_name}.pid"
    
    if [ ! -f "$pid_file" ]; then
        warning "No worker found for: $project_name"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        warning "Process $pid not running - removing stale PID file"
        rm "$pid_file"
        return
    fi
    
    log "Stopping worker for: $project_name (PID: $pid)"
    kill -TERM "$pid"
    
    # Wait for graceful shutdown (10 seconds)
    local count=0
    while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        warning "Graceful shutdown timed out - force killing"
        kill -9 "$pid"
    fi
    
    rm "$pid_file"
    success "Worker stopped: $project_name"
}

cmd_status() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        cmd_list
        return
    fi
    
    local pid_file="$STATE_DIR/${project_name}.pid"
    local session_log="$PROJECTS_DIR/$project_name/logs/worker-sessions.log"
    
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "Worker Status: $project_name"
    echo "════════════════════════════════════════════════════════"
    
    if [ ! -f "$pid_file" ]; then
        echo "Status: 🔴 STOPPED"
    else
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: 🟢 RUNNING (PID: $pid)"
        else
            echo "Status: 🔴 STOPPED (stale PID: $pid)"
        fi
    fi
    
    if [ -f "$PROJECTS_DIR/$project_name/TASKS.md" ]; then
        local completed=$(grep -c '^- \[x\]' "$PROJECTS_DIR/$project_name/TASKS.md" 2>/dev/null || echo "0")
        local uncompleted=$(grep -c '^- \[ \]' "$PROJECTS_DIR/$project_name/TASKS.md" 2>/dev/null || echo "0")
        local total=$((completed + uncompleted))
        echo "Tasks: $completed/$total completed"
    fi
    
    if [ -f "$session_log" ]; then
        echo ""
        echo "Recent Activity:"
        tail -5 "$session_log" | sed 's/^/  /'
    fi
    
    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_list() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "Available Projects & Worker Status"
    echo "════════════════════════════════════════════════════════"
    
    for project_dir in "$PROJECTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            proj_name=$(basename "$project_dir")
            pid_file="$STATE_DIR/${proj_name}.pid"
            
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    status="🟢 RUNNING"
                else
                    status="🔴 STOPPED (stale)"
                fi
            else
                status="⚫ STOPPED"
            fi
            
            if [ -f "$project_dir/TASKS.md" ]; then
                completed=$(grep -c '^- \[x\]' "$project_dir/TASKS.md" 2>/dev/null || echo "0")
                uncompleted=$(grep -c '^- \[ \]' "$project_dir/TASKS.md" 2>/dev/null || echo "0")
                total=$((completed + uncompleted))
                progress="[$completed/$total]"
            else
                progress="[no tasks]"
            fi
            
            printf "  %-30s %s %s\n" "$proj_name" "$status" "$progress"
        fi
    done
    
    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_logs() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        error "Usage: $0 logs [project-name]"
        return 1
    fi
    
    local output_log="$LOGS_DIR/worker-$project_name.output.log"
    local session_log="$PROJECTS_DIR/$project_name/logs/worker-sessions.log"
    
    if [ -f "$session_log" ]; then
        echo "=== Session Log ==="
        tail -50 "$session_log"
        echo ""
    fi
    
    if [ -f "$output_log" ]; then
        echo "=== Output Log ==="
        tail -50 "$output_log"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

if [ -z "$1" ]; then
    echo "Wiggum Worker Manager"
    echo ""
    echo "Usage: $0 [start|stop|status|list|logs] [project-name]"
    echo ""
    echo "Commands:"
    echo "  start [project]      Start persistent worker (all if no project specified)"
    echo "  stop [project]       Stop worker (all if no project specified)"
    echo "  status [project]     Show worker status"
    echo "  list                 List all projects and their status"
    echo "  logs [project]       Show worker logs (requires project name)"
    echo ""
    exit 0
fi

case "$1" in
    start)
        cmd_start "$2"
        ;;
    stop)
        cmd_stop "$2"
        ;;
    status)
        cmd_status "$2"
        ;;
    list)
        cmd_list
        ;;
    logs)
        cmd_logs "$2"
        ;;
    *)
        error "Unknown command: $1"
        exit 1
        ;;
esac
