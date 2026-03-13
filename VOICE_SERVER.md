# 🎤 Wiggum Voice Server - Setup & Usage Guide

The **Voice Server** is a web-based control panel for the Wiggum Master that lets you:
- 🎙️ **Speak project ideas** directly into your browser
- 🚀 **Auto-create projects** from voice input
- 📊 **Monitor all workers** in real-time
- 🎮 **Control projects** (start/stop) from the dashboard
- 📝 **View live logs** for debugging

## Quick Start

### 1️⃣ Option A: Automatic Setup (Recommended)

```bash
cd /home/julien/Desktop/Free-Wiggum
bash start_voice_server.sh
```

This script will:
- Create an isolated Python venv
- Install Flask and dependencies
- Check for transcription options
- Start the server

Then open **http://localhost:5000** in your browser! 🌐

### 2️⃣ Option B: Manual Setup

```bash
# Create venv
python3 -m venv venv_server
source venv_server/bin/activate

# Install dependencies
pip install -r requirements-master.txt

# Run the server
python3 voice_server.py
```

## Features & How to Use

### 🎙️ Voice Input (Browser Recording)

1. **Click the microphone button** (big red circle)
2. **Speak your project idea** clearly
   - Example: *"Build a REST API for todo app"*
   - Or: *"Web scraper to crawl news articles"*
3. **Click again to stop** recording
4. Audio is transcribed automatically
5. Project name/description are populated
6. Click **Create & Start Project** ✨

### 🔤 Manual Text Input

If voice isn't working or you prefer typing:
1. Enter **Project Name** (e.g., `todo-app`)
2. Enter **Initial Task** (e.g., "Create backend endpoints")
3. Click **Create & Start Project**

### 📊 Project Dashboard

Each project card shows:
- **Status**: 🟢 RUNNING or ⚫ STOPPED
- **Progress**: X/Y tasks completed
- **Current Task**: What the AI is working on now
- **Actions**: Start/Stop buttons, view logs

Projects refresh every 3 seconds automatically.

### 📝 Live Logs

Click **📋 Logs** on any project card to view:
- Last 50 lines from the worker log
- Real-time task progression
- Errors or warnings
- Iteration details

## Transcription Options

### 🎯 Priority Order

1. **OpenAI Whisper API** (if `OPENAI_API_KEY` is set)
   ```bash
   export OPENAI_API_KEY="sk_test_..."
   bash start_voice_server.sh
   ```
   Best accuracy, requires API credits

2. **Local Whisper** (if installed)
   ```bash
   pip install openai-whisper
   # Download model:
   whisper --model base
   # Then start server
   bash start_voice_server.sh
   ```
   No API key needed, slower but free

3. **Ollama Whisper** (if Ollama is running)
   ```bash
   # Install Ollama from https://ollama.ai
   ollama pull whisper
   ollama serve  # In another terminal
   # Then start server
   bash start_voice_server.sh
   ```

4. **Manual Text Input** (fallback)
   - Type project name and description manually
   - Always works, no transcription service needed

## Architecture

```
Your Browser (http://localhost:5000)
    ↓
Flask Server (voice_server.py)
    ├─ Records audio from microphone
    ├─ Sends to transcription service
    ├─ Calls wiggum_master.sh commands
    └─ Returns status updates

    ↓
Wiggum Master (wiggum_master.sh)
    ├─ Creates project folders
    └─ Spawns worker processes

    ↓
Wiggum Workers (wiggum_worker.sh)
    └─ Run AI iterations in background
```

## Implementation Details

### Voice Recording (Web Audio API)

The browser uses native Web Audio API to:
- Request microphone permission
- Record audio to WebM format
- Send to Flask server
- Display waveform status

### Transcription Pipeline

```
Audio File → Transcription Service → Text → Auto-fill Form
```

Supports multiple transcription backends with fallback chain.

### Project Lifecycle

```
Voice Input
    ↓
Create Project (copy template, setup venv)
    ↓
Auto-Start Worker (spawn background process)
    ↓
Stream Logs (via /api/logs endpoint)
   ↓
Monitor Progress (refresh every 3s)
```

## Troubleshooting

### 🔴 Microphone Not Working

1. **Check browser permissions**
   - Chrome: Address bar → Camera/Microphone icon
   - Firefox: Preferences → Privacy → Permissions
   - Allow access to microphone

2. **Check OS audio permissions**
   ```bash
   # Linux - verify recording device
   arecord -l
   ```

3. **Test audio manually**
   ```bash
   # Record 5 seconds
   arecord -d 5 /tmp/test.wav
   ```

### ❌ No Transcription Service Found

**Error**: "Transcription failed"

**Solutions**:
1. Install Whisper:
   ```bash
   pip install openai-whisper
   whisper --model base  # Download model
   ```

2. Set OpenAI API key:
   ```bash
   export OPENAI_API_KEY="sk_..."
   bash start_voice_server.sh
   ```

3. Use manual input (no transcription needed)

### 📡 Server Won't Start

**Error**: "Address already in use"

**Fix**:
```bash
# Kill existing server
pkill -f "python3 voice_server.py"

# Or use different port (edit voice_server.py, line ~200):
# Change: app.run(..., port=5000, ...)
# To: app.run(..., port=5001, ...)
```

### 💾 Projects Not Appearing

**Wait**: Dashboard refreshes every 3 seconds
```bash
# Or check manually:
ls /home/julien/Desktop/Free-Wiggum/projects/
```

**Check logs**:
```bash
tail -f /home/julien/Desktop/Free-Wiggum/logs/your-project.log
```

### 🚀 Worker Won't Start

See [MASTER_README.md](MASTER_README.md#troubleshooting)

## Browser Compatibility

| Browser | Voice Recording | Status |
|---------|-----------------|--------|
| Chrome | ✅ Full support | Recommended |
| Firefox | ✅ Full support | Works great |
| Safari | ✅ Full support | Works on macOS/iOS |
| Edge | ✅ Full support | Works great |

## Security Notes

⚠️ **This runs on localhost only** (127.0.0.1) - not accessible from other machines by default

To allow access from other machines:
```python
# Edit voice_server.py line ~200:
# Change: app.run(..., host='127.0.0.1', ...)
# To: app.run(..., host='0.0.0.0', ...)
```

**Warning**: This exposes the server to your network! Use with caution.

## API Endpoints

For integration or scripting:

### GET /api/projects
Returns all projects with current status
```bash
curl http://localhost:5000/api/projects
```

### POST /api/create-project
Create a new project
```bash
curl -X POST http://localhost:5000/api/create-project \
  -H "Content-Type: application/json" \
  -d '{"name": "my-project", "description": "Do something", "auto_start": true}'
```

### POST /api/start-project/<name>
Start a project worker
```bash
curl -X POST http://localhost:5000/api/start-project/my-project
```

### POST /api/stop-project/<name>
Stop a project worker
```bash
curl -X POST http://localhost:5000/api/stop-project/my-project
```

### GET /api/logs/<name>?lines=50
Get project logs
```bash
curl http://localhost:5000/api/logs/my-project?lines=100
```

### POST /api/transcribe
Transcribe audio to text (requires `audio` file field)
```bash
curl -X POST http://localhost:5000/api/transcribe \
  -F "audio=@recording.webm"
```

## Performance Tips

1. **Keep dashboard open** to have live refresh (3s intervals)
2. **Don't run too many workers in parallel** (depends on your system)
3. **Check logs** if something seems slow
4. **Monitor CPU/Memory**:
   ```bash
   top
   ```

## Future Enhancements

- [ ] Voice commands for actions (*"stop project X"*)
- [ ] Notification sounds on task completion
- [ ] Export project reports
- [ ] Database storage of project history
- [ ] WebSocket for real-time log streaming
- [ ] Integration with chat APIs for bidirectional control
- [ ] Project templates selector
- [ ] Scheduled/recurring projects

## Support

For issues:
1. Check troubleshooting section above
2. Check logs: `tail -f logs/voice_server.log`
3. See [MASTER_README.md](MASTER_README.md)

---

**Enjoy building with Wiggum!** 🐳✨
