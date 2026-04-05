#!/bin/bash
# Wiggum Worker - OpenCode-based individual project loop (simplified from wiggum.sh)
# Usage: bash wiggum_worker.sh /path/to/project [--agent ROLE] [--persistent]

PROJECT_PATH="$1"
AGENT_ROLE="${2:-generic}"  # Default to generic if not specified, or use --agent flag
PERSISTENT_MODE="false"

# Parse --agent flag if provided
if [ "$2" = "--agent" ] && [ -n "$3" ]; then
    AGENT_ROLE="$3"
    # Check for persistent flag after agent
    if [ "$4" = "--persistent" ]; then
        PERSISTENT_MODE="true"
    fi
fi

# Check for persistent flag in position 2
if [ "$2" = "--persistent" ]; then
    PERSISTENT_MODE="true"
fi

PROJECT_NAME=$(basename "$PROJECT_PATH")
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" 
MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure opencode is in PATH (common user npm prefix)
if ! command -v opencode &> /dev/null; then
  export PATH="$HOME/.npm-global/bin:$PATH"
fi

# ============================================================================
# VALIDATION
# ============================================================================

if [ -z "$PROJECT_PATH" ]; then
    echo "❌ Usage: $0 /path/to/project"
    exit 1
fi

# ============================================================================
# SECURITY: PREVENT DEBUG OUTPUT FROM LEAKING ENV VARS
# ============================================================================
# Disable bash debugging/tracing that could print environment variables
set +x  # Don't print commands
set +v  # Don't print input lines

# ============================================================================
# SECURITY: SANITIZATION FUNCTION FOR API KEYS
# ============================================================================
# This function redacts sensitive data from output before logging
sanitize_output() {
    local input="$1"
    # Redact OpenRouter API keys (format: sk-or-v1-xxxxx) - most thorough
    echo "$input" | sed -E 's/sk-or-v1-[a-zA-Z0-9]{60,}/sk-or-v1-REDACTED/g' | \
    # Redact OPENROUTER_API_KEY in all formats (env vars, declare -x, exports, etc)
    sed -E 's/(OPENROUTER_API_KEY["\x27]?)([=:]|[[:space:]]+)(["\x27]?)([^ "\x27]+)/\1\2\3REDACTED/g' | \
    # Redact WIGGUM_MODEL and WIGGUM_UNSTICK_MODEL (contain sensitive model info)
    sed -E 's/(WIGGUM_(UN)?STICK_MODEL["\x27]?)([=:]|[[:space:]]+)(["\x27]?)([^ "\x27]+)/\1\3REDACTED/g' | \
    # Redact any Authorization headers
    sed -E 's/(Authorization: Bearer ).{20,}/\1REDACTED/g' | \
    # Redact quoted API key values (declare -x format: OPENROUTER_API_KEY="value")
    sed -E 's/(OPENROUTER_API_KEY=")([^"]+)(")/\1REDACTED\3/g'
}

# Create a wrapper that sanitizes before writing to logs
exec_with_sanitization() {
    local log_file="$1"
    shift  # Remove first arg
    # Execute command and sanitize output before logging
    "$@" 2>&1 | while IFS= read -r line; do
        sanitize_output "$line" >> "$log_file"
    done
    return ${PIPESTATUS[0]}
}

# Push with automatic rebase on stale branch errors
# Usage: git_push_with_rebase_retry <branch>
# Returns 0 on success, 1 on failure after retry
git_push_with_rebase_retry() {
    local branch="$1"
    if git push origin "$branch"; then
        return 0
    fi
    echo "⚠️  Push failed (likely stale branch). Attempting git pull --rebase..."
    if git pull --rebase origin "$branch"; then
        if git push origin "$branch"; then
            echo "✅ Push succeeded after rebase"
            return 0
        else
            echo "⚠️  Push still failed after rebase"
            return 1
        fi
    else
        echo "⚠️  Rebase failed. Resolve conflicts manually, then run: git rebase --continue && git push origin $branch"
        return 1
    fi
}

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project path does not exist: $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH" || exit 1

# Store active agent role in project for UI tracking
echo "$AGENT_ROLE" > .agent_role

# Store worker mode
echo "$PERSISTENT_MODE" > .worker_persistent_mode

# ============================================================================
# ENVIRONMENT & DEPENDENCY CHECK
# ============================================================================

if ! command -v opencode &> /dev/null; then
    echo "❌ opencode-ai is not installed! Run: npm i -g opencode-ai"
    exit 1
fi

# Load API keys and model selection from master .env ONLY
if [ -f "/home/julien/Desktop/Free-Wiggum-opencode/.env" ]; then
    # Extract and export only the critical vars
    OPENROUTER_API_KEY=$(grep "^OPENROUTER_API_KEY=" "/home/julien/Desktop/Free-Wiggum-opencode/.env" | cut -d'=' -f2- | tr -d '"')
    WIGGUM_MODEL=$(grep "^WIGGUM_MODEL=" "/home/julien/Desktop/Free-Wiggum-opencode/.env" | cut -d'=' -f2- | tr -d '"')
    WIGGUM_UNSTICK_MODEL=$(grep "^WIGGUM_UNSTICK_MODEL=" "/home/julien/Desktop/Free-Wiggum-opencode/.env" | cut -d'=' -f2- | tr -d '"')
    export OPENROUTER_API_KEY WIGGUM_MODEL WIGGUM_UNSTICK_MODEL
fi

# Load project .env for other project-specific variables (but not API keys)
if [ -f .env ]; then
    export $(cat .env | grep -v -E "OPENROUTER_API_KEY|WIGGUM_MODEL|WIGGUM_UNSTICK_MODEL" | grep -v '#' | xargs)
fi

# Token management - force OpenCode to truncate responses, leaving budget for context
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=32000

# ============================================================================
# PROJECT INITIALIZATION
# ============================================================================

# Ensure AGENTS.md exists
if [ ! -f "AGENTS.md" ]; then
    echo "🔍 AGENTS.md not found. Running opencode /init..."
    opencode /init --yes 2>/dev/null || echo "⚠️  Could not generate AGENTS.md"
fi

# Create comprehensive .gitignore early to prevent large files
if [ ! -f ".gitignore" ]; then
    echo "📝 Creating comprehensive .gitignore..."
    
    # Look for template in parent or master directory
    TEMPLATE_PATH=""
    if [ -f "../.gitignore.template" ]; then
        TEMPLATE_PATH="../.gitignore.template"
    elif [ -f "../../.gitignore.template" ]; then
        TEMPLATE_PATH="../../.gitignore.template"
    elif [ -f ".gitignore.template" ]; then
        TEMPLATE_PATH=".gitignore.template"
    fi
    
    if [ -n "$TEMPLATE_PATH" ] && [ -f "$TEMPLATE_PATH" ]; then
        cp "$TEMPLATE_PATH" .gitignore
        echo "✅ .gitignore created from template"
    else
        echo "⚠️  Template not found at $TEMPLATE_PATH, creating minimal .gitignore"
        cat > .gitignore <<'GITIGNORE_MINIMAL'
# Auto-generated minimal .gitignore
node_modules/
.env
.env.local
.next/
build/
dist/
.cache/
*.log
GITIGNORE_MINIMAL
    fi
fi

# Backup original TASKS.md
[ ! -f TASKS_original.md ] && cp TASKS.md TASKS_original.md

# Validate TASKS.md has tasks
if ! grep -q '^- \[ \]' TASKS.md; then
    echo "⚠️  [WARNING] No uncompleted tasks found in TASKS.md!"
    total_marked=$(grep -c '^\- \[' TASKS.md || echo "0")
    echo "   Total task lines: $total_marked"
    if [ "$total_marked" -eq 0 ]; then
        echo "🔴 TASKS.md has no tasks at all! Cannot proceed."
        exit 1
    fi
fi

# Create logs directory
mkdir -p logs

# ============================================================================
# GITHUB REPO SETUP
# ============================================================================

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo "📦 Initializing fresh git repository..."
    git init
    git branch -M main
    git config user.name "Wiggum Bot"
    git config user.email "wiggum@bot.local"
    
    # Determine repo name from project name
    REPO_NAME="$PROJECT_NAME"
    FULL_REPO="Julien-ser/$REPO_NAME"
    
    echo "🔗 Adding remote: git@github.com:$FULL_REPO.git"
    git remote add origin "git@github.com:$FULL_REPO.git"
    
    # Create initial commit with current state
    git add .
    git commit -m "Initial commit: Fresh start with clean .gitignore" 2>/dev/null || true
    
    # Check if repo exists on GitHub, create if needed
    if ! gh repo view "$FULL_REPO" > /dev/null 2>&1; then
        echo "📦 Repository $FULL_REPO not found on GitHub. Creating..."
        if gh repo create "$FULL_REPO" --public --source="$PROJECT_PATH" --remote=origin --push 2>/dev/null; then
            echo "✅ Repository created and pushed to GitHub: $FULL_REPO"
        else
            echo "⚠️  Could not auto-create repo on GitHub. You may need to create it manually."
        fi
    else
        echo "✅ Repository already exists on GitHub: $FULL_REPO"
        # Push initial commit
        git push -u origin main 2>/dev/null || true
    fi
else
    echo "🔧 Git repository already exists. Verifying remote setup..."
    
    # Get the repository name from origin remote
    REPO_URL=$(git config --get remote.origin.url)
    if [ -n "$REPO_URL" ]; then
        # Extract owner/repo from URL (works with https and git@)
        if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/(.+?)(.git)?$ ]]; then
            OWNER="${BASH_REMATCH[1]}"
            REPO="${BASH_REMATCH[2]%.git}"
            FULL_REPO="$OWNER/$REPO"
            
            # Check if repo exists on GitHub
            if ! gh repo view "$FULL_REPO" > /dev/null 2>&1; then
                echo "📦 Repository $FULL_REPO not found on GitHub. Creating..."
                if gh repo create "$FULL_REPO" --public --source="$PROJECT_PATH" --remote=origin --push 2>/dev/null; then
                    echo "✅ Repository created and pushed to GitHub: $FULL_REPO"
                else
                    echo "⚠️  Could not auto-create repo on GitHub. You may need to create it manually."
                fi
            else
                echo "✅ Repository already exists on GitHub: $FULL_REPO"
            fi
        else
            echo "⚠️  Could not parse GitHub URL: $REPO_URL"
        fi
    fi
fi

# Enable auto-merge on main branch (best-effort; requires admin permissions)
if command -v gh &> /dev/null && [ -n "$FULL_REPO" ]; then
    echo "🔒 Setting branch protection to allow auto-merge on main..."
    gh api -X PUT repos/$FULL_REPO/branches/main/protection \
      -f "allow_auto_merge=true" \
      -f "required_status_checks=[]" \
      -f "enforce_admins=false" \
      -f "required_pull_request_reviews=null" \
      2>/dev/null || echo "⚠️  Could not set branch protection (may already exist or insufficient permissions)"
fi

# Switch to main and ensure up-to-date, then create a session branch for PR workflow
git checkout main 2>/dev/null || git checkout -b main
git pull origin main --rebase 2>/dev/null || true
SESSION_BRANCH="wiggum/session"
# Checkout existing session branch if present, else create from main (preserves local progress)
if git show-ref --verify --quiet "refs/heads/$SESSION_BRANCH"; then
    git checkout "$SESSION_BRANCH"
    echo "🔀 Using existing session branch: $SESSION_BRANCH"
else
    git checkout -b "$SESSION_BRANCH" origin/main
    echo "🔀 Created new session branch: $SESSION_BRANCH"
fi

PR_CREATED=0
PR_NUMBER=""

# Check if a PR already exists for this session branch (e.g., resuming after pause)
if command -v gh &> /dev/null; then
    EXISTING_PR=$(gh pr list --head "$SESSION_BRANCH" --json number -q '.[0].number' 2>/dev/null)
    if [ -n "$EXISTING_PR" ]; then
        echo "ℹ️ Existing PR #$EXISTING_PR found for branch $SESSION_BRANCH."
        PR_CREATED=1
        PR_NUMBER="$EXISTING_PR"
    fi
fi

# Find the highest numbered iteration
iteration=$(ls logs/iteration-*.md 2>/dev/null | sed 's/.*iteration-//;s/.md//' | sort -n | tail -1)
iteration=${iteration:-0}

# Token counter
total_tokens=0
TOKEN_LIMIT=64000

# ============================================================================
# PROGRESS TRACKING (Detect True Stuck Tasks vs. Legitimate Multi-Iteration Work)
# ============================================================================

# Function: Check if actual progress was made since last iteration
# Returns 0 (true) if progress found, 1 (false) if stuck
check_progress_made() {
    local current_iteration=$1
    local task_name="$2"
    
    if [ $current_iteration -lt 2 ]; then
        return 0  # First iteration always counts as progress
    fi
    
    # Check 1: Did git commit happen in the last iteration?
    if git log --oneline -1 2>/dev/null | grep -q "Iteration $((current_iteration - 1))"; then
        echo "✓ Progress: Git commit found"
        return 0
    fi
    
    # Check 2: Did any files change in the last iteration?
    PREV_ITER_LOG="logs/iteration-$((current_iteration - 1)).md"
    if [ -f "$PREV_ITER_LOG" ]; then
        # Count files mentioned in the output
        if grep -q '✅\|📝\|Modified\|Created\|Deleted\|added\|changed' "$PREV_ITER_LOG"; then
            echo "✓ Progress: Work output found in logs"
            return 0
        fi
    fi
    
    # Check 3: Task list changed? (completed new tasks)
    PREV_ITER_LOG="logs/iteration-$((current_iteration - 1)).md"
    if [ -f "$PREV_ITER_LOG" ]; then
        # Extract task count from previous iteration log
        prev_completed=$(grep -c '^\- \[x\]' "$PREV_ITER_LOG" 2>/dev/null || echo "0")
        curr_completed=$(grep -c '^\- \[x\]' TASKS.md 2>/dev/null || echo "0")
        
        if [ "$curr_completed" -gt "$prev_completed" ]; then
            echo "✓ Progress: New tasks completed"
            return 0
        fi
    fi
    
    # Check 4: Look for repeated error patterns (bad sign)
    ITER_1_LOG="logs/iteration-$((current_iteration - 2)).md"
    ITER_2_LOG="logs/iteration-$((current_iteration - 1)).md"
    if [ -f "$ITER_1_LOG" ] && [ -f "$ITER_2_LOG" ]; then
        # Check if the same error appears in both logs
        error_pattern=$(grep -o 'error\|Error\|ERROR\|failed\|Failed' "$ITER_1_LOG" 2>/dev/null | head -1)
        if [ -n "$error_pattern" ] && grep -q "$error_pattern" "$ITER_2_LOG" 2>/dev/null; then
            echo "✗ No progress: Same error repeated"
            return 1
        fi
    fi
    
    echo "⚠️  No explicit progress markers found, but allowing task to continue (multi-iteration work)"
    return 0  # Benefit of the doubt: might be legitimate multi-iteration task
}

# ============================================================================
# FUNCTION: Detect if task is stuck in test failure loop
# Returns 0 (stuck) if 3+ iterations show the same test error, 1 otherwise
# ============================================================================
detect_test_failure_loop() {
    local current_iteration=$1
    local task_name="$2"
    local test_errors=0
    
    # Check last 3 iterations for test failures
    for i in 1 2 3; do
        prev_iter=$((current_iteration - i))
        if [ $prev_iter -gt 0 ]; then
            iter_log="logs/iteration-${prev_iter}.md"
            if [ -f "$iter_log" ]; then
                # Look for test-specific failures
                if grep -iE "test.*failed|Error.*test|Jest|\.test\.|FAIL|AssertionError|TypeError.*Component" "$iter_log" >/dev/null 2>&1; then
                    test_errors=$((test_errors + 1))
                fi
            fi
        fi
    done
    
    # If 2+ of last 3 iterations show test failures, we're stuck in a test loop
    if [ $test_errors -ge 2 ]; then
        return 0  # True - stuck in test failure loop
    else
        return 1  # False - not stuck in test loop
    fi
}

# Track stuck task attempts (only flag after 3 attempts with ZERO progress)
declare -A task_attempts
declare -A task_last_progress_iter
declare -A test_failure_count

# Setup logging with GUARANTEED sanitization (no fallback)
LOG_FILE="logs/worker-session-$(date +%Y%m%d-%H%M%S).log"

# Create log file first
mkdir -p logs
touch "$LOG_FILE"

# Create named pipe for sanitization
SANITIZE_FIFO="/tmp/wiggum_sanitize_$$"
mkfifo "$SANITIZE_FIFO" 2>/dev/null || SANITIZE_FIFO="/tmp/wiggum_sanitize_$RANDOM"

# Start background sanitization process
{
    while IFS= read -r line; do
        sanitized=$(sanitize_output "$line")
        echo "$sanitized"
    done < "$SANITIZE_FIFO" >> "$LOG_FILE"
} &
SANITIZE_PID=$!

# Redirect ALL output (stdout & stderr) through sanitization
exec 1>"$SANITIZE_FIFO"
exec 2>&1

# Cleanup function for named pipe
cleanup_sanitize() {
    exec 1>&-  # Close the pipe writer
    wait $SANITIZE_PID 2>/dev/null || true
    rm -f "$SANITIZE_FIFO" 2>/dev/null || true
}

# ============================================================================
# AUTONOMOUS ROLE INFERENCE
# ============================================================================

infer_role_from_tasks() {
    local tasks_file="${1:-TASKS.md}"
    if [ ! -f "$tasks_file" ]; then
        echo "generic"
        return
    fi

    # Extract pending tasks (unchecked)
    local pending_tasks
    pending_tasks=$(grep '^- \[ \]' "$tasks_file" | sed 's/^- \[ \] //')
    local task_count=0
    local devops_count=0 qa_count=0 docs_count=0 release_count=0 orchestrator_count=0

    # Count role-specific keywords in each task
    echo "$pending_tasks" | while IFS= read -r task; do
        task_count=$((task_count + 1))
        task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')

        # DevOps / infrastructure keywords
        if echo "$task_lower" | grep -qE \
            "ci/cd|deploy|infrastructure|docker|kubernetes|k8s|server|aws|cloud|database|redis|nginx|monitoring|logging|ci|cd|pipeline|github actions|workflow|ansible|terraform|helm|chart|config\.|secrets|environment|\.env|production|staging|scaling|load balancer|reverse proxy|ssl|tls|certificate"; then
            devops_count=$((devops_count + 1))
        fi

        # QA / testing
        if echo "$task_lower" | grep -qE \
            "test|qa|quality|assertion|jest|pytest|unittest|integration test|unit test|e2e|end-to-end|mocking|coverage|ci.*test|test.*suite|validation|test case|test plan|load test|stress test"; then
            qa_count=$((qa_count + 1))
        fi

        # Documentation
        if echo "$task_lower" | grep -qE \
            "documentation|readme|guide|tutorial|api doc|comment|swagger|openapi|markdown|docstring|code comment|user manual"; then
            docs_count=$((docs_count + 1))
        fi

        # Release management
        if echo "$task_lower" | grep -qE \
            "release|version|changelog|bump|semver|tag|deploy.*production|publish|npm publish|pip upload|docker push|app store|play store|deployment notes"; then
            release_count=$((release_count + 1))
        fi

        # Orchestration / planning
        if echo "$task_lower" | grep -qE \
            "plan|design|architecture|break down|decompose|subtasks|coordinate|coordination|blocking|risk|dependency|timeline|milestone|epic|user story|backlog grooming|prioritize"; then
            orchestrator_count=$((orchestrator_count + 1))
        fi
    done

    # If no tasks, stay generic
    [ $task_count -eq 0 ] && { echo "generic"; return; }

    # Find max count among specialized roles (with thresholds)
    local max_count=0
    local selected_role="generic"

    # Require at least 2 matches for most roles (avoid noise)
    if [ $devops_count -ge 2 ] && [ $devops_count -ge $max_count ]; then
        max_count=$devops_count
        selected_role="devops-engineer"
    fi
    if [ $qa_count -ge 2 ] && [ $qa_count -ge $max_count ]; then
        max_count=$qa_count
        selected_role="qa-specialist"
    fi
    if [ $docs_count -ge 2 ] && [ $docs_count -ge $max_count ]; then
        max_count=$docs_count
        selected_role="documentation-specialist"
    fi
    # Release & orchestrator need only 1 (they're rare)
    if [ $release_count -ge 1 ] && [ $release_count -ge $max_count ]; then
        max_count=$release_count
        selected_role="release-manager"
    fi
    if [ $orchestrator_count -ge 1 ] && [ $orchestrator_count -ge $max_count ]; then
        max_count=$orchestrator_count
        selected_role="project-orchestrator"
    fi

    echo "$selected_role"
}

# Error handling
set +e  # Don't exit on errors
set -o pipefail  # Preserve exit codes through pipes
trap 'echo "❌ Worker interrupted"; cleanup_sanitize; cleanup' EXIT INT TERM

cleanup() {
    completed=$(grep -c '^- \[x\]' TASKS.md 2>/dev/null) && : || completed=0
    uncompleted=$(grep -c '^- \[ \]' TASKS.md 2>/dev/null) && : || uncompleted=0
    total=$((${completed:-0} + ${uncompleted:-0}))
    
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "📊 WORKER SESSION SUMMARY"
    echo "════════════════════════════════════════════════════════"
    echo "Project: $PROJECT_NAME"
    echo "Iterations: $iteration"
    echo "Tasks: $completed / $total completed"
    echo "Remaining: $uncompleted"
    echo "Tokens: $total_tokens / $TOKEN_LIMIT"
    echo "Logs: logs/iteration-*.md"
    echo "⏰ Completed: $(date)"
    echo "════════════════════════════════════════════════════════"
}

# ============================================================================
# MAIN LOOP
# ============================================================================

echo "🚀 Starting Wiggum Worker for: $PROJECT_NAME"
echo "📍 Project Path: $PROJECT_PATH"
echo "⏰ Started at: $(date)"
echo "⚡ Token Budget: $TOKEN_LIMIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━════"
echo ""

while true; do
    iteration=$((iteration + 1))
    
    # === AUTONOMOUS ROLE SWITCHING ===
    # Check if remaining tasks suggest a different agent role
    inferred_role=$(infer_role_from_tasks "TASKS.md")
    current_role=$(cat .agent_role 2>/dev/null || echo "generic")
    
    if [ "$inferred_role" != "$current_role" ]; then
        echo "🔁 Role auto-switch: $current_role → $inferred_role"
        echo "$inferred_role" > .agent_role
        # Cleanup sanitization FIFO and background process
        cleanup_sanitize
        # Restart the worker with the new role
        if [ "$PERSISTENT_MODE" = "true" ]; then
            exec bash "$0" "$PROJECT_PATH" --agent "$inferred_role" --persistent
        else
            exec bash "$0" "$PROJECT_PATH" --agent "$inferred_role"
        fi
    fi
    
    echo "📍 Iteration $iteration at $(date)..."
    
    # ====================================================================
    # CHECK FOR CI/CD ERRORS FROM GITHUB ACTIONS
    # ====================================================================
    if command -v gh &> /dev/null; then
        MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$MASTER_DIR/check-ci-errors.sh" ]; then
            # Check for CI errors and add them to TASKS.md if found
            bash "$MASTER_DIR/check-ci-errors.sh" "$PROJECT_PATH" 2>/dev/null || true
        fi
        
        # If this is a CI error task, use the CI debugger agent for smarter error analysis
        if echo "$next_task" | grep -qi "ci\|error\|failing\|test.*fail"; then
            if [ -f "$MASTER_DIR/agents/ci-debugger.md" ]; then
                CI_DEBUGGER_PROMPT=$(cat "$MASTER_DIR/agents/ci-debugger.md")
                echo "🔧 Using CI Debugger agent for smart error analysis..."
                # This prompt will be injected into the main build command below
                export CI_DEBUG_MODE="true"
            fi
        fi
    fi
    
    # ====================================================================
    # EXTRACT NEXT TASK
    # ====================================================================
    
    # Use consistent grep pattern and proper extraction
    next_task=$(grep -m1 '^- \[ \]' TASKS.md | sed 's/^- \[ \] //' | xargs)
        
    # Debug output
    if [ -z "$next_task" ]; then
        echo "🔍 [DEBUG] No uncompleted tasks found. Checking task counts..."
        completed=$(grep -c '^- \[x\]' TASKS.md 2>/dev/null) && : || completed=0
        uncompleted=$(grep -c '^- \[ \]' TASKS.md 2>/dev/null) && : || uncompleted=0
        total=$((${completed:-0} + ${uncompleted:-0}))
        echo "   Completed: $completed, Uncompleted: $uncompleted, Total: $total"
        # No break here; allow loop to continue to PR creation/monitoring later
        # We'll set a flag to skip work and go to PR section
        NO_NEXT_TASK=1
    else
        NO_NEXT_TASK=0
    fi
    
    if [ ${#next_task} -lt 5 ]; then
        # Only skip if next_task is non-empty; empty means all tasks done, proceed to PR handling
        if [ -n "$next_task" ]; then
            echo "⚠️  [WARNING] Task too short or malformed: '$next_task'"
            echo "⏭️  Skipping to next iteration..."
            sleep 2
            continue
        fi
        # else: empty task (all done) -> fall through to PR creation
    fi

    # ====================================================================
    # PROGRESS CHECK - Detect Truly Stuck Tasks (vs. Legit Multi-Iteration Work)
    # ====================================================================
    
    # Initialize tracking for this task if first time seeing it
    if [ -z "${task_attempts[$next_task]}" ]; then
        task_attempts["$next_task"]=1
        task_last_progress_iter["$next_task"]=$iteration
    else
        # Increment attempt count for this task
        task_attempts["$next_task"]=$((${task_attempts["$next_task"]} + 1))
        
        # Check if progress has been made since last attempt
        if check_progress_made "$iteration" "$next_task"; then
            task_last_progress_iter["$next_task"]=$iteration
            echo "📊 Task attempt ${task_attempts[$next_task]}: Progress detected, continuing..."
        else
            attempts_count=${task_attempts["$next_task"]}
            last_progress=${task_last_progress_iter["$next_task"]}
            iterations_since_progress=$((iteration - last_progress))
            
            # ====================================================================
            # AUTONOMOUS UNSTICKING STRATEGIES (Before auto-marking as complete)
            # ====================================================================
            
            # Analyze error patterns from previous attempts
            PREV_LOG="logs/iteration-$((iteration - 1)).md"
            error_patterns=""
            if [ -f "$PREV_LOG" ]; then
                # Look for common errors
                if grep -q "ImportError\|ModuleNotFoundError" "$PREV_LOG" 2>/dev/null; then
                    error_patterns="📦 Import/dependency issues detected."
                elif grep -q "FileNotFoundError\|No such file" "$PREV_LOG" 2>/dev/null; then
                    error_patterns="📁 File path or structure issues detected."
                elif grep -q "SyntaxError\|IndentationError" "$PREV_LOG" 2>/dev/null; then
                    error_patterns="🔧 Syntax/code format issues detected."
                elif grep -q "context_length\|token.*limit\|too.*long" "$PREV_LOG" 2>/dev/null; then
                    error_patterns="📊 Token limit exceeded - task too complex for single iteration."
                elif grep -q "Error\|error\|failed\|Failed" "$PREV_LOG" 2>/dev/null; then
                    error_patterns="❌ Generic error detected. Check logs for details."
                fi
            fi
            
            # ====================================================================
            # CHECK: Is this task stuck in a TEST FAILURE LOOP?
            # ====================================================================
            if detect_test_failure_loop "$iteration" "$next_task"; then
                test_failure_count["$next_task"]=$((${test_failure_count["$next_task"]:-0} + 1))
                test_fail_attempts=${test_failure_count["$next_task"]}
                
                if [ $test_fail_attempts -eq 1 ]; then
                    echo "🧪 [TEST FAILURE DETECTED] Task stuck in failing tests (attempt 1)"
                    echo "    Switching to TEST DEBUG MODE on next iteration..."
                    # Will trigger debug mode below
                    UNSTICK_ATTEMPT="test_debug_mode_1"
                elif [ $test_fail_attempts -ge 2 ]; then
                    echo "🧪 [TEST FAILURE LOOP] Tests have failed 2+ times in a row"
                    echo "    ⏭️  SKIPPING to next task - marking this for manual review"
                    
                    # Mark task as needing manual debugging
                    sed -i 's/^\- \[ \] '"$(printf '%s\n' "$next_task" | sed -e 's/[]\/$*.^[]/\\&/g')"'/- [ ] [DEBUG-NEEDED] &/' TASKS.md 2>/dev/null
                    
                    git add TASKS.md
                    git commit -m "Iteration $iteration: Marked task as debug-needed (test failures)" 2>/dev/null || true
                    
                    echo "📌 Task marked as [DEBUG-NEEDED] in TASKS.md - skipping to next task"
                    sleep 1
                    continue
                fi
            fi
            
            if [ $iterations_since_progress -ge 2 ] && [ $iterations_since_progress -lt 3 ]; then
                echo "⚠️  [POTENTIAL STUCK] No progress for $iterations_since_progress iterations - Gathering context..."
                [ -n "$error_patterns" ] && echo "    $error_patterns"
                
                # Extract what was already done from previous iterations
                partial_work=$(grep -A 50 "## OpenCode Output" "$PREV_LOG" 2>/dev/null | grep "Write\|Created\|Modified" | head -3)
                
                if [ -n "$partial_work" ]; then
                    echo "✅ Found partial work from previous iteration:"
                    echo "$partial_work"
                fi
                
                # Continue to next iteration with enhanced previous_context
                continue
            fi
            
            if [ $iterations_since_progress -ge 3 ] && [ $iterations_since_progress -lt 4 ]; then
                echo "🔴 [STUCK - STRATEGY 1] No progress for 3+ iterations. Trying task decomposition..."
                [ -n "$error_patterns" ] && echo "    $error_patterns"
                
                # Strategy 1: Break task into smaller numbered subtasks
                UNSTICK_PROMPT="This task is failing. Break it into 3-5 smaller subtasks and complete ONLY THE FIRST ONE fully. Don't try to do everything at once.

$error_patterns

Original task: $next_task

For example, if the task is 'implement auth', do ONLY 'Create user model' first, then we'll do the rest next iteration.

Complete just ONE small piece. Mark progress in TASKS.md. DO NOT skip any required files."
                
                # Will use simplified prompt below
                UNSTICK_ATTEMPT="true"
            elif [ $iterations_since_progress -ge 4 ] && [ $iterations_since_progress -lt 5 ]; then
                echo "🔴 [STUCK - STRATEGY 2] Decomposition failed. Trying minimal viable approach..."
                [ -n "$error_patterns" ] && echo "    $error_patterns"
                
                # Strategy 2: Just create skeleton/placeholder files
                UNSTICK_PROMPT="This task is too complex. Create MINIMAL working versions:

$error_patterns

Original task: $next_task

INSTRUCTIONS:
1. Create empty Python files with just imports and class stubs (no implementation)
2. Create empty JSON files with structure only
3. Create empty directories as needed
4. Update TASKS.md to mark subtasks as started

Return the list of files created. DON'T implement, just structure."
                
                UNSTICK_ATTEMPT="true"
            elif [ $iterations_since_progress -ge 5 ]; then
                echo "🔴 [STUCK TASK] No progress after 5+ iterations (attempt $attempts_count)"
                echo "   Task: ${next_task:0:70}..."
                [ -n "$error_patterns" ] && echo "   Error pattern: $error_patterns"
                
                # Move to end of TASKS.md as [RETRY] for model to attempt again later
                # This keeps it in the queue without breaking the loop
                echo "📌 Moving to end of TASKS.md for retry - model will attempt again later"
                
                # Remove the stuck task from current position
                sed -i '\|^- \[ \] '"$(printf '%s\n' "$next_task" | sed -e 's/[]\/$*.^[]/\\&/g')"'|d' TASKS.md 2>/dev/null || \
                sed -i '0,/^- \[ \] /{/^- \[ \] /d;}' TASKS.md
                
                # Append to end with [RETRY] marker
                {
                    echo ""
                    echo "## Stuck Tasks (attempted 5+ times, needs fresh approach)"
                    echo ""
                    echo "- [ ] [RETRY] $next_task"
                } >> TASKS.md
                
                sleep 2
                continue
            fi
        fi
    fi

    # ====================================================================
    # BUILD DYNAMIC PROMPT (with Historical Context for Multi-Iteration Tasks)
    # ====================================================================
    
    # Initialize unstick flag
    UNSTICK_ATTEMPT=""
    
    # Gather context from previous iterations if this is a repeated task
    previous_context=""
    if [ ${task_attempts["$next_task"]} -gt 1 ]; then
        echo "📚 Loading context from previous iteration attempts..."
        
        # Look back through recent iteration logs for this task attempt
        for prev_iter in $(seq $((iteration - 1)) -1 $((iteration - 5))); do
            if [ $prev_iter -gt 0 ]; then
                PREV_LOG="logs/iteration-${prev_iter}.md"
                if [ -f "$PREV_LOG" ]; then
                    # Check if this log mentions working on the same task
                    if grep -q "^## NEXT TASK.*$next_task" "$PREV_LOG" 2>/dev/null || \
                       grep -q "Task:.*$next_task" "$PREV_LOG" 2>/dev/null; then
                        
                        echo "   Found context in: iteration-${prev_iter}.md"
                        
                        # Extract key output lines (errors, progress, etc.)
                        prev_output=$(grep -A 20 "## OpenCode Output" "$PREV_LOG" 2>/dev/null | head -30)
                        
                        # Extract files that were created or modified
                        created_files=$(grep "Write.*successfully\|Created\|mkdir" "$PREV_LOG" 2>/dev/null | head -5)
                        
                        previous_context="### Previous Attempt (Iteration $prev_iter):
**Files created/modified:**
\`\`\`
$created_files
\`\`\`

**Last Output:**
\`\`\`
$prev_output
\`\`\`

**Guidance:** Continue from where we left off. Don't re-do work already done. Focus on the next incomplete piece.
"
                        break  # Use the most recent attempt's context
                    fi
                fi
            fi
        done
    fi
    
    # Load base prompt - prefer agent-specific, fallback to project, then generic
    base_prompt=""
    
    # 1. Try agent-specific prompt from master agents directory
    if [ "$AGENT_ROLE" != "generic" ] && [ -f "${MASTER_DIR}/agents/${AGENT_ROLE}.md" ]; then
        base_prompt=$(cat "${MASTER_DIR}/agents/${AGENT_ROLE}.md")
        echo "✅ Loaded $AGENT_ROLE agent personality"
    # 2. Try project-specific prompt
    elif [ -f "prompt.txt" ]; then
        base_prompt=$(cat prompt.txt)
    # 3. Use generic fallback
    else
        base_prompt="You are an autonomous software engineer. Complete the assigned task."
    fi

    # Build prompt (use UNSTICK_PROMPT if set by unsticking logic, otherwise normal)
    if [ "$UNSTICK_ATTEMPT" = "test_debug_mode_1" ]; then
        # TEST DEBUG MODE - Fix failing tests
        dynamic_prompt=$(cat <<'PROMPT'
## TEST DEBUG MODE - Fix Failing Tests

You are in TEST DEBUG MODE because tests are failing.

**Your ONLY goal:** Fix the failing tests. Do NOT implement new features.

### Steps:
1. Run the tests: `npm test` or `pytest` or similar
2. Read the error output CAREFULLY
3. Find the ROOT CAUSE (missing mock? wrong import? logic bug?)
4. Fix ONLY what's breaking the tests
5. Re-run tests to verify they pass
6. Mark task as complete in TASKS.md when tests pass

### Critical Rules:
- Focus on TEST FAILURES ONLY - ignore unrelated code quality issues
- Don't refactor or add features - just fix what breaks tests
- If a component is broken (e.g., returns null), fix the logic
- If mocks/imports are missing, add them
- Get tests to GREEN before marking task complete

### Current Task: PROMPT
        dynamic_prompt="$dynamic_prompt$next_task"
        dynamic_prompt="$dynamic_prompt

### Recent Test Output:
"
        # Append last iteration's error output
        if [ -f "logs/iteration-$((iteration - 1)).md" ]; then
            test_output=$(grep -A 50 "Error\|FAIL\|TypeError\|AssertionError" "logs/iteration-$((iteration - 1)).md" 2>/dev/null | head -40)
            dynamic_prompt="$dynamic_prompt$test_output"
        fi
        
        dynamic_prompt="$dynamic_prompt

Mark progress in TASKS.md. Commit when tests pass."
    elif [ -n "$UNSTICK_ATTEMPT" ]; then
        # Unsticking attempt - use simplified prompt
        dynamic_prompt=$(cat <<PROMPT
$UNSTICK_PROMPT

$previous_context

**CRITICAL:** Complete ONLY what was asked above. Mark progress in TASKS.md. Commit using git.
PROMPT
)
    elif [ "$CI_DEBUG_MODE" = "true" ]; then
        # CI Error debugging - completely generic, let model figure it out
        
        # Extract error from previous iteration
        error_summary=""
        if [ -f "logs/iteration-$((iteration - 1)).md" ]; then
            error_summary=$(tail -150 "logs/iteration-$((iteration - 1)).md" | grep -B 5 -A 15 "error\|Error\|failed\|Failed" | head -40)
        fi
        
        dynamic_prompt=$(cat <<PROMPT
### Current Task: $next_task

### Build/Test Error - Fix Code Only

**Context:** The build or test command failed. Your job is to fix it.

**CRITICAL RULES:**
- Do NOT install system tools, download large files, or set up external environments
- Only modify code, config files, and dependency versions
- If error requires external setup → document in README, skip from CI

**Error from last attempt:**
\`\`\`
$error_summary
\`\`\`

**Decision:**
- **Is this a code/syntax error?** → Fix the code
- **Is this a missing/version dependency error?** → Update the version constraint
- **Is this an environment/setup error?** → Mark in README as prerequisite, exclude from CI, or skip

**Do the minimal fix to make the error go away, then commit.**

$previous_context
PROMPT
)
    else
        # Normal attempt
        dynamic_prompt=$(cat <<PROMPT
$base_prompt

---

### ⚠️ CRITICAL TOKEN CONSTRAINTS:
- Iteration: $iteration / 64k Token Budget
- Attempt: ${task_attempts["$next_task"]} (previous attempts may have partial progress)
- **Mandate:** Operate efficiently. Use partial edits, not full file rewrites when possible.
- **Output:** Be concise and action-oriented.
$previous_context

## CURRENT PROJECT STATE (Iteration $iteration)

\`\`\`
$(cat TASKS.md)
\`\`\`

## NEXT TASK TO COMPLETE:
$next_task

**Instructions:** Complete this task. Mark [x] in TASKS.md when done. Create, modify, or delete files as needed. Execute commands as needed. Also update README.md to match this project (name, setup instructions, current progress). No permission needed—just act.
PROMPT
)
    fi

    # ====================================================================
    # SAVE ITERATION LOG
    # ====================================================================
    
    ITER_LOG_FILE="logs/iteration-${iteration}.md"
    {
        echo "# Iteration $iteration - $PROJECT_NAME"
        echo ""
        echo "**Timestamp:** $(date)"
        echo "**Task:** $next_task"
        echo ""
        echo "## Prompt Sent"
        echo ""
        echo '```'
        echo "$dynamic_prompt"
        echo '```'
        echo ""
        echo "## OpenCode Output"
        echo ""
        echo '```'
    } > "$ITER_LOG_FILE"

    # ====================================================================
    # EXECUTION
    # ====================================================================
    
    # Use a faster model for unsticking attempts to save tokens
    if [ -n "$UNSTICK_ATTEMPT" ]; then
        RUN_MODEL="${WIGGUM_UNSTICK_MODEL:-openrouter/google/gemini-2.0-flash-exp:free}"
        echo "🎯 UNSTICKING ATTEMPT - Using fast model for decomposition"
    else
        RUN_MODEL="${WIGGUM_MODEL:-openrouter/google/gemini-2.0-flash-exp:free}"
    fi
    
    echo "🤖 OpenCode processing: $next_task"
    # Ensure OpenRouter API key is available for OpenCode
    # Execute opencode and sanitize output before writing to logs
    OPENCODE_CONFIG_CONTENT='{"permission":{"read":{"*.env":"allow","*.env.*":"allow"}}}' \
    OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
    opencode run \
             --model "$RUN_MODEL" \
             "$dynamic_prompt" 2>&1 | while IFS= read -r line; do
                sanitized=$(sanitize_output "$line")
                echo "$sanitized" | tee -a "$ITER_LOG_FILE"
            done
    opencode_exit=$?
    # Note: Exit code captured above via pipe, using 0 as fallback
    [ $? -ne 0 ] && opencode_exit=0

    # Close log
    {
        echo '```'
        echo ""
        echo "## TASKS.md After Iteration"
        echo ""
        echo '```markdown'
        cat TASKS.md
        echo '```'
        echo ""
        echo "**Completed at:** $(date)"
    } >> "$ITER_LOG_FILE"

    echo "📝 Log saved: $ITER_LOG_FILE"

    # ====================================================================
    # ERROR DETECTION - Check for API/Auth Issues
    # ====================================================================
    
    if grep -q "Error: User not found" "$ITER_LOG_FILE" 2>/dev/null; then
        echo "⚠️  [AUTH ERROR] OpenCode returned 'User not found' - skipping this iteration"
        echo "    This is likely an OpenRouter/API authentication issue"
        sleep 5
        continue
    fi

    # ====================================================================
    # TOKEN TRACKING
    # ====================================================================
    
    if [ ! -f "$ITER_LOG_FILE" ]; then
        echo "⚠️  [WARNING] Log file was not created!"
        iteration_tokens=0
    else
        LOG_SIZE=$(stat -c%s "$ITER_LOG_FILE" 2>/dev/null || stat -f%z "$ITER_LOG_FILE" 2>/dev/null || echo "500")
        LOG_SIZE_KB=$((LOG_SIZE / 1024 + 1))
        iteration_tokens=$((LOG_SIZE_KB * 250))
    fi
    
    total_tokens=$((total_tokens + iteration_tokens))
    
    echo "📊 Token Usage: $iteration_tokens / Session: $total_tokens / $TOKEN_LIMIT"
    
    # Check for context errors
    if grep -q "context_length_exceeded\|Context.*exceed\|too.*long\|token.*limit" "$ITER_LOG_FILE" 2>/dev/null; then
        echo "⚠️  CONTEXT LENGTH ERROR - skipping to next iteration"
        sleep 2
        continue
    fi
    
    # Check for OpenCode failures
    if [ $opencode_exit -ne 0 ]; then
        echo "❌ [ERROR] OpenCode crashed with exit code: $opencode_exit"
        echo "⚠️  Continuing to next iteration (will retry task)"
        echo "    Check logs/iteration-${iteration}.md for details"
        sleep 2
        continue
    fi
    
    # Check token limit - restart session if exhausted
    if [ $total_tokens -gt $TOKEN_LIMIT ]; then
        echo "⚠️  Token budget exhausted this session ($total_tokens / $TOKEN_LIMIT)"
        echo "🔄 AUTO-RESTARTING WORKER SESSION..."
        sleep 2
        exec bash "$SCRIPT_PATH" "$PROJECT_PATH"  # Restart script with full path
    fi

    # ====================================================================
    # GIT COMMIT (with large file filtering)
    # ====================================================================
    
    # .gitignore is already created at initialization if needed
    
    # Add files, but exclude common problem directories
    git add . 2>/dev/null || true
    
    # Explicitly remove known large directories from staging
    git reset -- node_modules/ .next/ build/ dist/ out/ 2>/dev/null || true
    
    # Check for files and directories that are larger than 100MB (GitHub limit)
    # This catches any sneaky large files that made it through .gitignore
    staging_files=$(git diff --cached --diff-filter=A --name-only 2>/dev/null)
    
    large_found=0
    if [ -n "$staging_files" ]; then
        while IFS= read -r file; do
            if [ -e "$file" ]; then
                size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
                if [ "$size" -gt 104857600 ]; then  # 100MB - GitHub's hard limit
                    if [ $large_found -eq 0 ]; then
                        echo "⚠️  LARGE FILES DETECTED (>100MB) - Removing from commit:"
                        large_found=1
                    fi
                    size_mb=$((size / 1048576))
                    echo "   - $file ($size_mb MB) - REMOVING"
                    git reset -- "$file" 2>/dev/null || true
                fi
            fi
        done <<< "$staging_files"
    fi
    
    # Also warn about medium files (>50MB)
    medium_found=0
    if [ -n "$staging_files" ]; then
        while IFS= read -r file; do
            if [ -e "$file" ]; then
                size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
                if [ "$size" -gt 52428800 ] && [ "$size" -le 104857600 ]; then  # 50-100MB
                    if [ $medium_found -eq 0 ]; then
                        echo "⚠️  MEDIUM FILES (50-100MB) - Consider these for .gitignore:"
                        medium_found=1
                    fi
                    size_mb=$((size / 1048576))
                    echo "   - $file ($size_mb MB)"
                fi
            fi
        done <<< "$staging_files"
    fi
    
    # Now commit if there are changes
    if git commit -m "Iteration $iteration: $next_task" > /dev/null 2>&1; then
        echo "✅ Changes committed"
        if git_push_with_rebase_retry "$SESSION_BRANCH"; then
            echo "✅ Pushed to GitHub (branch: $SESSION_BRANCH)"
        else
            echo "❌ Push failed after retry. Stopping worker to avoid state issues. Resolve git conflicts manually, then restart."
            break
        fi
    else
        echo "ℹ️  No changes to commit"
    fi
    
    # Re-check task status after OpenCode execution
    # (in case OpenCode modified TASKS.md)
    completed=$(grep -c '^- \[x\]' TASKS.md 2>/dev/null) && : || completed=0
    uncompleted=$(grep -c '^- \[ \]' TASKS.md 2>/dev/null) && : || uncompleted=0
    total=$((${completed:-0} + ${uncompleted:-0}))
    
    echo "📊 Updated Tasks: $completed/$total completed, $uncompleted remaining"
    
    # Debug: Show next task
    next_upcoming=$(grep -m1 '^- \[ \]' TASKS.md | sed 's/^- \[ \] //' | xargs | cut -c1-60)
    if [ -n "$next_upcoming" ]; then
        echo "   Next task: $next_upcoming..."
    fi
    
    if [ "$uncompleted" -eq 0 ]; then
        if [ "$PR_CREATED" -eq 0 ]; then
            echo "✅ All tasks completed! Creating PR..."
            cd "$PROJECT_PATH" || exit
            git add . 2>/dev/null
            if git diff --cached --quiet 2>/dev/null; then
                echo "ℹ️ No uncommitted changes to push"
            else
                if git commit -m "Final worker session push"; then
                    if git_push_with_rebase_retry "$SESSION_BRANCH"; then
                        echo "✅ Final push to GitHub successful (branch: $SESSION_BRANCH)"
                        PR_URL=$(gh pr create --fill --base main --head "$SESSION_BRANCH" --json url -q .url 2>/dev/null)
                        if [ -n "$PR_URL" ]; then
                            echo "✅ Created pull request from $SESSION_BRANCH to main: $PR_URL"
                            PR_NUMBER=$(echo "$PR_URL" | rev | cut -d'/' -f1 | rev)
                            gh api -X PUT repos/$FULL_REPO/branches/main/protection \
                              -f "allow_auto_merge=true" \
                              -f "required_status_checks=[]" \
                              -f "enforce_admins=false" \
                              -f "required_pull_request_reviews=null" \
                              2>/dev/null || true
                        else
                            echo "⚠️  Could not create pull request"
                        fi
                    else
                        echo "❌ Final push to GitHub failed after retry. Stopping worker; resolve git issues manually, then restart."
                        break
                    fi
                fi
            fi
            PR_CREATED=1
        else
            PR_STATE=$(gh api repos/$FULL_REPO/pulls/$PR_NUMBER --jq .state 2>/dev/null)
            MERGED=$(gh api repos/$FULL_REPO/pulls/$PR_NUMBER --jq .merged_at 2>/dev/null)
            if [ -n "$MERGED" ] && [ "$MERGED" != "null" ]; then
                echo "✅ PR $PR_NUMBER merged."
                break
            fi
            CR_REVIEW_STATE=$(gh api repos/$FULL_REPO/pulls/$PR_NUMBER/reviews --jq '.[] | select(.user.login=="pr-agent") | .state' 2>/dev/null | head -1)
            if [ "$CR_REVIEW_STATE" = "CHANGES_REQUESTED" ]; then
                echo "⚠️ PR-Agent requested changes. Adding feedback task..."
                {
                    echo ""
                    echo "## PR-Agent Feedback"
                    echo "- [ ] Address PR-Agent feedback on PR #$PR_NUMBER"
                } >> TASKS.md
                git add TASKS.md
                git commit -m "chore: add PR-Agent feedback task for PR #$PR_NUMBER" || true
                git_push_with_rebase_retry "$SESSION_BRANCH" || true
            fi
        fi
    fi
    
    sleep 3
done

echo "✅ Worker finished"
