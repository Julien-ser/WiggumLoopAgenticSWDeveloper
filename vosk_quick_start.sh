#!/bin/bash
# Quick Start: Vosk Voice Server with One Command
# This script does everything needed to get Wiggum voice working

set -e

MASTER_DIR="/home/julien/Desktop/Free-Wiggum"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║     🎤 VOSK QUICK START - One Command Setup          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Step 1: Setup venv
echo "📦 Step 1/3: Setting up virtual environment..."
bash "$MASTER_DIR/setup_venv.sh"

echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Step 2: Show what we installed
echo "✅ Installation complete!"
echo ""
echo "What's been installed:"
echo "   📁 Location: $MASTER_DIR/venv"
echo "   🐍 Python 3 isolated environment"
echo "   🌐 Flask web server"
echo "   🎤 Vosk speech recognition (offline)"
echo "   🗣️ English speech model (~150MB)"
echo ""

# Auto-activate venv for user convenience
source "$MASTER_DIR/venv/bin/activate"

# Step 3: Start server
echo "════════════════════════════════════════════════════════"
echo ""
echo "🚀 Starting Voice Server..."
echo ""
bash "$MASTER_DIR/start_voice_server.sh"
