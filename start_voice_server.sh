#!/bin/bash
# Start Wiggum Web Server
# Activates venv and starts Flask

set -e

MASTER_DIR="/home/julien/Desktop/Free-Wiggum-opencode"
VENV_DIR="${MASTER_DIR}/venv"

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  🌐 WIGGUM WEB SERVER                      ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "⚠️  Virtual environment not found!"
    echo ""
    echo "📖 Run setup first:"
    echo "   python3 -m venv $VENV_DIR"
    echo "   source $VENV_DIR/bin/activate"
    echo "   pip install -r requirements.txt"
    echo ""
    exit 1
fi

# Activate venv
echo "🔌 Activating virtual environment..."
source "$VENV_DIR/bin/activate"
echo "   ✅ Active: $VIRTUAL_ENV"
echo ""

# Create runtime directories
mkdir -p "$MASTER_DIR/logs"
mkdir -p "$MASTER_DIR/projects"

echo ""
echo "════════════════════════════════════════════"
echo "✨ Starting Web Server..."
echo "════════════════════════════════════════════"
echo ""
echo "📍 Open http://localhost:5000 in your browser"
echo ""
echo "🎯 Features:"
echo "   ✅ Create projects with text input"
echo "   ✅ Monitor running workers"
echo "   ✅ Start/stop projects"
echo "   ✅ View iteration logs"
echo ""
echo "🛑 To stop: Press Ctrl+C"
echo ""

# Start the server
cd "$MASTER_DIR"
python3 server.py

