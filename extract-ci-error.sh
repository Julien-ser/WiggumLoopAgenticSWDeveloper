#!/bin/bash
# CI Error Context Extractor for OpenCode Agents
# Pulls detailed error info from GitHub Actions to help agents understand what broke
# Usage: bash extract-ci-error.sh <owner/repo> <run_id>

REPO="$1"
RUN_ID="$2"

if [ -z "$REPO" ] || [ -z "$RUN_ID" ]; then
    echo "Usage: bash extract-ci-error.sh <owner/repo> <run_id>"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "⚠️ GitHub CLI not installed"
    exit 1
fi

echo "🔍 Extracting error context from GitHub Actions..."
echo ""

# Get job details
JOBS=$(gh run view "$RUN_ID" --repo "$REPO" --json jobs --jq '.jobs[] | select(.conclusion=="failure")' 2>/dev/null | jq -r '.name' 2>/dev/null)

if [ -z "$JOBS" ]; then
    echo "No failed jobs found in run $RUN_ID"
    exit 0
fi

echo "❌ Failed Jobs:"
echo "$JOBS"
echo ""

# Try to extract error logs (requires newer gh version)
echo "📋 Error Details:"
echo "---"

# Fallback: provide link to full logs
echo "Full logs available at:"
echo "https://github.com/$REPO/actions/runs/$RUN_ID"
echo ""

# Provide common fixes based on project type
echo "🛠️ Common Fixes for Different Languages:"
echo ""
echo "**Rust Projects:**"
echo "  - Check crate names spelling in Cargo.toml"
echo "  - Verify crates exist on crates.io: https://crates.io"
echo "  - Move [profile.*] sections to workspace root"
echo "  - Use 'cargo check' to validate locally"
echo ""
echo "**Python Projects:**"
echo "  - Missing dependencies: check requirements.txt"
echo "  - Version conflicts: try 'pip install --upgrade'"
echo "  - Run 'pip install -r requirements.txt' locally"
echo ""
echo "**Node/JavaScript Projects:**"
echo "  - Missing packages: check package.json"
echo "  - Run 'npm install' locally"
echo "  - Check Node version compatibility"
echo ""
echo "**General:**"
echo "  - Clean build first: 'rm -rf build node_modules dist target'"
echo "  - Rebuild dependencies from scratch"
echo "  - Check GitHub Secrets are configured"
echo "  - Verify file permissions (executable scripts)"
