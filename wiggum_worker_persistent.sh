#!/bin/bash
# 🔁 Wiggum Persistent Worker - Continuous project execution with task queueing
# Runs indefinitely, restarting sessions and managing task queues
# Usage: bash wiggum_worker_persistent.sh /path/to/project [--max-iterations N] [--token-limit N]

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Configuration
MAX_ITERATIONS_PER_SESSION="${MAX_ITERATIONS_PER_SESSION:-20}"
TOKEN_LIMIT="${TOKEN_LIMIT:-64000}"
RESTART_DELAY=10
SESSION_RESTART_THRESHOLD=3600  # Restart session every hour (in seconds)
HEALTH_CHECK_INTERVAL=300  # Check health every 5 minutes

# Parse arguments
while [[ $# -gt 1 ]]; do
    case $2 in
        --max-iterations)
            MAX_ITERATIONS_PER_SESSION="$3"
            shift 2
            ;;
        --token-limit)
            TOKEN_LIMIT="$3"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ============================================================================
# VALIDATION
# ============================================================================

if [ -z "$PROJECT_PATH" ]; then
    echo "❌ Usage: $0 /path/to/project [--max-iterations N] [--token-limit N]"
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project path does not exist: $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH" || exit 1

# ============================================================================
# SECURITY & ENVIRONMENT
# ============================================================================

set +x
set +v

sanitize_output() {
    local input="$1"
    echo "$input" | sed -E 's/sk-or-v1-[a-zA-Z0-9]{60,}/sk-or-v1-REDACTED/g' | \
    sed -E 's/(OPENROUTER_API_KEY["\047]?)([=:]|[[:space:]]+)(["\047]?)([^ "\047]+)/\1\2\3REDACTED/g'
}

# Load environment
MASTER_DIR="/home/julien/Desktop/Free-Wiggum-opencode"
if [ -f "$MASTER_DIR/.env" ]; then
    OPENROUTER_API_KEY=$(grep "^OPENROUTER_API_KEY=" "$MASTER_DIR/.env" | cut -d'=' -f2- | tr -d '"')
    WIGGUM_MODEL=$(grep "^WIGGUM_MODEL=" "$MASTER_DIR/.env" | cut -d'=' -f2- | tr -d '"')
    export OPENROUTER_API_KEY WIGGUM_MODEL
fi

export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=32000

# ============================================================================
# PERSISTENT STATE FILES
# ============================================================================

STATE_DIR="$PROJECT_PATH/.wiggum"
mkdir -p "$STATE_DIR"

STATE_FILE="$STATE_DIR/worker-state.json"
LOG_DIR="$PROJECT_PATH/logs"
mkdir -p "$LOG_DIR"

SESSION_LOG="$LOG_DIR/worker-sessions.log"
RESTART_COUNT_FILE="$STATE_DIR/restart-count"
LAST_SUCCESSFUL_TASK_FILE="$STATE_DIR/last-successful-task"
HEALTH_CHECK_LOG="$LOG_DIR/worker-health.log"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_session() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$SESSION_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log_health() {
    local status="$1"
    local details="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $status - $details" >> "$HEALTH_CHECK_LOG"
}

increment_restart_count() {
    count=$(($(cat "$RESTART_COUNT_FILE" 2>/dev/null || echo "0") + 1))
    echo "$count" > "$RESTART_COUNT_FILE"
    echo $count
}

reset_restart_count() {
    echo "0" > "$RESTART_COUNT_FILE"
}

save_last_task() {
    local task="$1"
    echo "$task" > "$LAST_SUCCESSFUL_TASK_FILE"
}

get_last_task() {
    cat "$LAST_SUCCESSFUL_TASK_FILE" 2>/dev/null || echo ""
}

# Count completed tasks
get_task_counts() {
    local completed=$(grep -c '^- \[x\]' TASKS.md 2>/dev/null || echo "0")
    local uncompleted=$(grep -c '^- \[ \]' TASKS.md 2>/dev/null || echo "0")
    echo "$completed:$uncompleted"
}

# ============================================================================
# TASK QUEUE MANAGEMENT
# ============================================================================

initialize_task_queue() {
    if [ ! -f "TASKS_QUEUE.json" ]; then
        cat > TASKS_QUEUE.json <<'EOF'
{
  "queue": [],
  "completed": [],
  "failed": [],
  "active": null,
  "created_at": "TIMESTAMP"
}
EOF
        sed -i "s/TIMESTAMP/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" TASKS_QUEUE.json
    fi
}

# Get next task from queue (or from TASKS.md if queue is empty)
get_next_task() {
    # First, ensure TASKS.md sync
    if [ ! -f TASKS.md ]; then
        log_session "WARN" "No TASKS.md found!"
        return 1
    fi
    
    # Get first uncompleted task from TASKS.md
    next_task=$(grep -m1 '^- \[ \]' TASKS.md | sed 's/^- \[ \] //' | xargs)
    
    if [ -z "$next_task" ]; then
        return 1
    fi
    
    echo "$next_task"
    return 0
}

# ============================================================================
# HEALTH CHECK & RECOVERY
# ============================================================================

check_worker_health() {
    local iteration=$1
    
    # Check 1: Are there uncompleted tasks?
    counts=$(get_task_counts)
    uncompleted=$(echo "$counts" | cut -d':' -f2)
    completed=$(echo "$counts" | cut -d':' -f1)
    
    if [ "$uncompleted" -eq 0 ]; then
        log_health "✅ HEALTHY" "All tasks completed ($completed/$((completed + uncompleted)))"
        return 0
    fi
    
    # Check 2: Recent git activity?
    last_commit=$(git log -1 --format="%ai" 2>/dev/null || echo "")
    if [ -z "$last_commit" ]; then
        log_health "⚠️  WARNING" "No git commits - worker may not be working"
    else
        log_health "✅ HEALTHY" "Recent activity: $last_commit, Iteration: $iteration"
    fi
    
    # Check 3: Log file size (indicates output)
    if [ -d logs ]; then
        latest_log=$(ls -t logs/iteration-*.md 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            size=$(stat -c%s "$latest_log" 2>/dev/null || stat -f%z "$latest_log" 2>/dev/null || echo 0)
            if [ "$size" -lt 500 ]; then
                log_health "⚠️  WARNING" "Latest iteration log very small ($size bytes) - possible stuck state"
            fi
        fi
    fi
    
    return 0
}

# ============================================================================
# SESSION RESTART LOGIC
# ============================================================================

needs_session_restart() {
    local session_start_time=$1
    local current_time=$(date +%s)
    local session_duration=$((current_time - session_start_time))
    
    # Restart if:
    # 1. Session older than SESSION_RESTART_THRESHOLD
    # 2. Too many restarts without progress
    
    if [ $session_duration -gt $SESSION_RESTART_THRESHOLD ]; then
        log_session "INFO" "Session age ($session_duration s) exceeds threshold ($SESSION_RESTART_THRESHOLD s) - scheduling restart"
        return 0
    fi
    
    restart_count=$(cat "$RESTART_COUNT_FILE" 2>/dev/null || echo "0")
    if [ "$restart_count" -gt 5 ]; then
        log_session "WARN" "Too many restarts ($restart_count) - investigating..."
        # Could implement backoff here
    fi
    
    return 1
}

# ============================================================================
# MAIN PERSISTENT LOOP
# ============================================================================

log_session "INFO" "=== Persistent Worker Starting for: $PROJECT_NAME ==="
log_session "INFO" "Max iterations per session: $MAX_ITERATIONS_PER_SESSION"
log_session "INFO" "Token limit: $TOKEN_LIMIT"

initialize_task_queue

session_start_time=$(date +%s)
session_iteration=0

while true; do
    session_iteration=$((session_iteration + 1))
    current_time=$(date +%s)
    
    log_session "INFO" "Session iteration $session_iteration at $(date)"
    
    # Health check periodically
    if [ $((session_iteration % 5)) -eq 0 ]; then
        check_worker_health "$session_iteration"
    fi
    
    # Get next task
    if ! next_task=$(get_next_task); then
        log_session "INFO" "🎉 No more uncompleted tasks found!"
        counts=$(get_task_counts)
        completed=$(echo "$counts" | cut -d':' -f1)
        total=$((completed + $(echo "$counts" | cut -d':' -f2)))
        log_session "SUCCESS" "Project complete: $completed/$total tasks"
        break
    fi
    
    if [ -z "$next_task" ]; then
        log_session "WARN" "Task extraction returned empty - waiting..."
        sleep 10
        continue
    fi
    
    log_session "INFO" "Next task: ${next_task:0:80}..."
    save_last_task "$next_task"
    
    # Call the original worker script for this single task
    # The worker script is designed to handle one iteration
    bash "$MASTER_DIR/wiggum_worker.sh" "$PROJECT_PATH" 2>&1 | tee -a "$SESSION_LOG"
    
    worker_exit=$?
    if [ $worker_exit -ne 0 ]; then
        log_session "ERROR" "Worker exited with code $worker_exit"
        restart_count=$(increment_restart_count)
        log_session "WARN" "Restart count: $restart_count"
        
        if [ "$restart_count" -gt 3 ]; then
            log_session "ERROR" "Too many consecutive failures - pausing for investigation"
            sleep 300
            reset_restart_count
        else
            sleep $RESTART_DELAY
            continue
        fi
    fi
    
    # Check if session needs restart
    if needs_session_restart "$session_start_time"; then
        log_session "INFO" "🔄 Restarting session..."
        reset_restart_count
        session_start_time=$(date +%s)
        session_iteration=0
        sleep 5
    fi
    
    # Check iteration limit
    if [ $session_iteration -ge $MAX_ITERATIONS_PER_SESSION ]; then
        log_session "INFO" "Iteration limit reached ($MAX_ITERATIONS_PER_SESSION) - restarting session"
        session_start_time=$(date +%s)
        session_iteration=0
        sleep 5
    fi
    
    sleep 3
done

log_session "INFO" "=== Persistent Worker Stopped at $(date) ==="
