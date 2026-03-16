#!/bin/bash
# CI Debugger for Wiggum Workers
# Provides smart analysis of GitHub Actions failures and suggests fixes
# Usage: bash ci-debug.sh <repo_owner/repo_name>

REPO="$1"

if [ -z "$REPO" ]; then
    echo "❌ Usage: bash ci-debug.sh <owner/repo>"
    exit 1
fi

echo "🔍 Analyzing recent CI failures for: $REPO"
echo ""

# Get last 10 runs with their status
echo "📊 Recent CI Runs:"
gh run list --repo "$REPO" --limit 10 --json status,conclusion,name,number,runNumber --query '.[] | "\(.number): \(.name) - \(.conclusion)"' 2>/dev/null || echo "⚠️ Could not fetch runs"

echo ""
echo "🔎 Analyzing failures..."

# Get latest failed run
FAILED_RUN=$(gh run list --repo "$REPO" --limit 1 --json number,conclusion --query '.[] | select(.conclusion=="failure") | .number' 2>/dev/null)

if [ -z "$FAILED_RUN" ]; then
    echo "✅ No recent failures found!"
    exit 0
fi

echo "Latest failed run: #$FAILED_RUN"
echo ""

# Get detailed job info
echo "Job Details:"
gh run view "$FAILED_RUN" --repo "$REPO" 2>/dev/null | head -40

echo ""
echo "🚨 Key Error Patterns to Fix:"

# Fetch logs and analyze
LOGS=$(gh run view "$FAILED_RUN" --repo "$REPO" --log 2>/dev/null || echo "")

# Check for common Rust errors
if echo "$LOGS" | grep -q "could not compile"; then
    echo "  • Compilation error detected - check Cargo.toml dependencies"
fi

if echo "$LOGS" | grep -q "no matching package"; then
    echo "  • Missing crate in crates.io - verify correct crate name or use path dependencies"
fi

if echo "$LOGS" | grep -q "could not find"; then
    echo "  • Missing dependency or file - add to Cargo.toml or check paths"
fi

if echo "$LOGS" | grep -q "profile.*ignored"; then
    echo "  • Cargo profile warning - move profiles to workspace root in Cargo.toml"
fi

if echo "$LOGS" | grep -q "error\[E"; then
    ERRORS=$(echo "$LOGS" | grep "error\[E" | sed 's/.*error\[E/error[E/' | cut -d']' -f1-2 | sort -u)
    echo "  • Specific Rust errors:"
    echo "$ERRORS" | sed 's/^/    /'
fi

echo ""
echo "💡 RECOMMENDATIONS:"
echo ""
echo "1. Check Cargo.toml for correct dependency names"
echo "2. Verify all crates exist on crates.io"
echo "3. For local/path dependencies, use: path = \"../crate-name\""
echo "4. For workspace issues, ensure [workspace] and profiles are at root"
echo "5. Run 'cargo check' locally before pushing"
echo ""
echo "📖 Full logs available at:"
echo "   https://github.com/$REPO/actions/runs/$FAILED_RUN"
