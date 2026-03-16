#!/bin/bash
# CI Error Detector for Wiggum Workers
# This script checks for recent GitHub Actions failures and adds them to TASKS.md
# 
# Usage: bash check-ci-errors.sh [project_path]

PROJECT_PATH="${1:-.}"
TASKS_FILE="$PROJECT_PATH/TASKS.md"

if [ ! -f "$TASKS_FILE" ]; then
    echo "❌ TASKS.md not found at $PROJECT_PATH"
    exit 1
fi

# Extract repo info from git
cd "$PROJECT_PATH" || exit 1
REPO_URL=$(git config --get remote.origin.url 2>/dev/null)

if [ -z "$REPO_URL" ]; then
    echo "⚠️  No git remote configured, skipping CI error check"
    exit 0
fi

# Parse owner/repo from URL (works with https and git@)
if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/(.+?)(.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
    FULL_REPO="$OWNER/$REPO"
else
    echo "⚠️  Could not parse GitHub repo from URL: $REPO_URL"
    exit 0
fi

echo "🔍 Checking CI errors for: $FULL_REPO"

# Use gh CLI to get recent workflow runs
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI not installed, skipping CI error check"
    exit 0
fi

# Get the last 5 workflow runs
FAILED_RUNS=$(gh run list --repo "$FULL_REPO" --limit 5 --json status,conclusion,name,number,url --query '.[] | select(.conclusion=="failure")' 2>/dev/null)

if [ -z "$FAILED_RUNS" ]; then
    echo "✅ No recent CI failures found"
    exit 0
fi

echo "Found CI failures, adding to TASKS.md..."

# Process each failed run - use JSON parsing instead of regex
gh run list --repo "$FULL_REPO" --limit 5 --json status,conclusion,name,number,url \
    --query '.[] | select(.conclusion=="failure")' > /tmp/failed_runs.json 2>/dev/null

if [ -s /tmp/failed_runs.json ]; then
    while IFS= read -r json_obj; do
        # Parse JSON object (requires jq, but fall back to grep if needed)
        if command -v jq &> /dev/null; then
            RUN_NUMBER=$(echo "$json_obj" | jq -r '.number // empty')
            RUN_NAME=$(echo "$json_obj" | jq -r '.name // empty')
            RUN_URL=$(echo "$json_obj" | jq -r '.url // empty')
        else
            # Fallback if jq not available - simple grep parsing
            RUN_NUMBER=$(echo "$json_obj" | grep -o '"number": *[0-9]*' | head -1 | grep -o '[0-9]*')
            RUN_NAME=$(echo "$json_obj" | grep -o '"name": *"[^"]*"' | head -1 | sed 's/.*": *"//;s/".*//')
            RUN_URL=$(echo "$json_obj" | grep -o '"url": *"[^"]*"' | head -1 | sed 's/.*": *"//;s/".*//')
        fi
        
        if [ -z "$RUN_NUMBER" ] || [ -z "$RUN_NAME" ]; then
            continue
        fi
        
        # Check if this error is already in TASKS.md
        if grep -q "CI Error.*#$RUN_NUMBER" "$TASKS_FILE"; then
            echo "  ⏭️  Error already tracked: $RUN_NAME #$RUN_NUMBER"
            continue
        fi
        
        # Add error task to TASKS.md at top of uncompleted tasks
        ERROR_TASK="- [ ] 🔴 CI Error: $RUN_NAME (#$RUN_NUMBER) - $RUN_URL"
        
        echo "  ✅ Adding: $RUN_NAME #$RUN_NUMBER"
        
        # Use a temporary file for safe insertion
        TMP_FILE="$TASKS_FILE.tmp"
        if grep -q '^- \[ \]' "$TASKS_FILE"; then
            # Insert before first uncompleted task
            head -n $(grep -n '^- \[ \]' "$TASKS_FILE" | head -1 | cut -d: -f1) "$TASKS_FILE" | sed '$d' > "$TMP_FILE"
            echo "$ERROR_TASK" >> "$TMP_FILE"
            tail -n +$(grep -n '^- \[ \]' "$TASKS_FILE" | head -1 | cut -d: -f1) "$TASKS_FILE" >> "$TMP_FILE"
        else
            # No uncompleted tasks yet, append to file
            cat "$TASKS_FILE" > "$TMP_FILE"
            echo "" >> "$TMP_FILE"
            echo "$ERROR_TASK" >> "$TMP_FILE"
        fi
        
        mv "$TMP_FILE" "$TASKS_FILE"
        echo "  ✅ Added: $RUN_NAME #$RUN_NUMBER"
    done < /tmp/failed_runs.json
fi

rm -f /tmp/failed_runs.json

echo "✅ CI error check complete"
