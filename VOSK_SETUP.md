# 🎤 Vosk Setup Guide - Offline Speech-to-Text

This guide explains how to set up and use **Vosk** for free, offline speech recognition in Wiggum Master.

## Why Vosk?

✅ **Free** - No API costs or key limits  
✅ **Offline** - Runs locally on your computer  
✅ **Fast** - Low latency speech recognition  
✅ **Open Source** - Transparent and privacy-respecting  
✅ **Lightweight** - Small model download (~100MB)

## Quick Start (3 Steps)

### 1️⃣ Run the Setup Script

```bash
cd /home/julien/Desktop/Free-Wiggum
bash setup_venv.sh
```

This will:
- Create a Python virtual environment in `/Free-Wiggum/venv`
- Install Flask, Vosk, and dependencies
- Download the English speech model (~150MB)
- Verify everything is working

### 2️⃣ Start the Voice Server

```bash
bash start_voice_server.sh
```

Or manually:
```bash
source venv/bin/activate
python3 voice_server.py
```

### 3️⃣ Open in Browser

```
🌐 http://localhost:5000
```

Click the **🎙️ microphone button** and start speaking! 🗣️

---

## How Vosk Works

### Installation Components

```
venv/                   ← Python virtual environment
├── bin/
│   ├── python3         ← Isolated Python
│   └── ...
└── lib/
    └── vosk            ← Vosk library (speech recognition)
    
~/.local/share/vosk/models/
└── vosk-model-en-us-0.22-lgraph/  ← Speech model (150MB)
    ├── model.fst
    ├── words.txt
    └── ...
```

### Processing Pipeline

```
Browser 🎤 Records Audio
    ↓
Audio sent to Flask Server
    ↓
Vosk Model (offline, local)
    ↓ 
Speech-to-Text
    ↓
Auto-fills form
    ↓
Project created! ✨
```

All processing happens **on your computer**. Nothing is sent to external servers.

---

## Configuration

### Virtual Environment

The setup script creates one in: `/home/julien/Desktop/Free-Wiggum/venv`

**Activate manually:**
```bash
source /home/julien/Desktop/Free-Wiggum/venv/bin/activate
```

**Deactivate:**
```bash
deactivate
```

### Vosk Model

**Location:** `~/.local/share/vosk/models/vosk-model-en-us-0.22-lgraph/`

**To use a different model:**

1. Download from: https://alphacephei.com/vosk/models
2. Extract to: `~/.local/share/vosk/models/`
3. Update path in `voice_server.py` line ~48:

```python
model_path = os.path.expanduser("~/.local/share/vosk/models/YOUR_MODEL_NAME")
```

**Available models:**
- `vosk-model-en-us-0.22-lgraph` (English, default)
- `vosk-model-small-en-us-0.15` (Small, faster)
- Models in other languages available

---

## Troubleshooting

### ❌ "Model not found"

**Error:** `Model path not found`

**Fix:**
1. Check if model is downloaded:
   ```bash
   ls ~/.local/share/vosk/models/
   ```

2. If missing, download manually:
   ```bash
   mkdir -p ~/.local/share/vosk/models
   cd ~/.local/share/vosk/models
   # Download using wget or curl
   wget https://alphacephei.com/vosk/models/vosk-model-en-us-0.22-lgraph.zip
   unzip vosk-model-en-us-0.22-lgraph.zip
   ```

3. Verify:
   ```bash
   ls ~/.local/share/vosk/models/vosk-model-en-us-0.22-lgraph/model.fst
   ```

### 🔴 Microphone not working

**Error:** `Microphone access denied` OR `No audio devices`

**Fix:**
1. **Browser permissions** - Allow microphone access
   - Chrome: Address bar → Camera/Microphone icon → Allow
   - Firefox: Privacy settings → Permissions → Microphone → Allow localhost

2. **Linux audio** - Check audio devices:
   ```bash
   # List recording devices
   arecord -l
   
   # Test recording
   arecord -d 3 /tmp/test.wav
   ```

3. **Restart browser** and try again

### ⚠️ "Transcription failed"

**Possible causes:**
- No speech detected (speak louder/clearer)
- Audio format not compatible
- Vosk model not responding

**Try:**
1. Use manual text input instead
2. Check browser console for errors: F12 → Console
3. Check server logs: `tail -f logs/voice_server.log`
4. Verify audio quality with `arecord`

### 🐛 FFmpeg missing (optional)

**Warning:** "FFmpeg not found"

**Fix (optional, for audio conversion):**
```bash
sudo apt install ffmpeg
```

Without FFmpeg, Vosk only works with WAV files captured by browser.

### 💾 Server won't start

**Error:** `Address already in use`

**Fix:**
```bash
# Kill any existing instance
pkill -f "python3 voice_server.py"

# Or use a different port - edit voice_server.py:
# Change: app.run(..., port=5000, ...)
# To: app.run(..., port=8000, ...)
```

---

## Advanced Usage

### Run Vosk Offline Demo

Test Vosk without the web interface:

```bash
source venv/bin/activate

python3 << 'EOF'
from vosk import Model, KaldiRecognizer
import json
import pyaudio

model = Model(os.path.expanduser("~/.local/share/vosk/models/vosk-model-en-us-0.22-lgraph"))
rec = KaldiRecognizer(model, 16000)

p = pyaudio.PyAudio()
stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000, input=True, frames_per_buffer=4096)

print("Say something...")
while True:
    data = stream.read(4096)
    if rec.AcceptWaveform(data):
        result = json.loads(rec.Result())
        print("Recognized:", result['result'])
        break
EOF
```

### Use Different Language Model

Change the model in `voice_server.py`:

```python
# Line 47
model_path = os.path.expanduser("~/.local/share/vosk/models/vosk-model-fr-fr-0.6-linto")  # French
```

Models available for: English, French, German, Spanish, Portuguese, Russian, etc.

### Customize Recognition Words

In `voice_server.py` around line ~130:

```python
rec.SetWords(["todo", "api", "webapp", "bot", "your-words-here"])
```

This improves accuracy for domain-specific words.

---

## Performance Tips

### Faster Transcription
- Use smaller model: `vosk-model-small-en-us-0.15`
- Speak clearly and at normal pace
- Use headphones/external mic for better quality

### Lower Memory Usage
- Smaller model uses less RAM (~100MB vs 500MB)
- Stop other applications to free resources

### Improve Accuracy
- Speak clearly
- Add domain-specific words: `rec.SetWords([...])`
- Use better microphone if available
- Reduce background noise

---

## Architecture Details

### Vosk Components

1. **Model** - Pre-trained speech recognition model
   - Contains acoustic model `model.fst`
   - Vocabulary `words.txt`
   - Language rules

2. **KaldiRecognizer** - Real-time recognition engine
   - Processes audio frames (4096 bytes at a time)
   - Updates hypothesis as more audio arrives
   - Returns final result when speech ends

3. **PyAudio** - Audio input (browser handles this)

### How Recognition Works

```
Audio Input
    ↓
Frame Buffer (4096 bytes)
    ↓
Acoustic Model + Words
    ↓
Find best match in language model
    ↓
Partial hypothesis
    ↓ (repeat for each frame)
Final Result (confidence score)
```

### Offline Processing

All steps run locally:
- No internet required
- No data leaves your computer
- No servers involved
- No logs or tracking

---

## Comparing Vosk with Alternatives

| Feature | Vosk | Whisper | OpenAI API |
|---------|------|---------|-----------|
| Cost | Free | Free (local) | $ (API) |
| Online | No | No | Yes |
| Speed | Fast | Medium | Slow (network) |
| Accuracy | Good | Excellent | Excellent |
| Setup | Easy | Medium | Easy |
| Privacy | Perfect | Perfect | Sent to server |

**For Wiggum Master:** Vosk is ideal (free, fast, local, good accuracy)

---

## Storage Requirements

- **Vosk model:** 150-500 MB
- **Python packages:** ~200 MB
- **Audio uploads:** Temporary (auto-cleaned)

Total: ~400-700 MB

---

## Next Steps

1. ✅ Run `bash setup_venv.sh`
2. ✅ Start server: `bash start_voice_server.sh`
3. ✅ Open http://localhost:5000
4. 🎙️ Start speaking project ideas!

For issues or questions, see [MASTER_README.md](MASTER_README.md#troubleshooting)

---

**Enjoy free, offline speech recognition!** 🎤✨
