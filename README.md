# SyncScribe 🎙️

SyncScribe takes an audio file and generates a standalone HTML viewer with embedded audio and synchronized transcription. Words are highlighted as they're spoken, and hovering over any word provides instant English translation. The generated file is fully self-contained and works completely offline, requiring no internet connection.

It uses local OpenAI's Whisper models via faster-whisper, if GPU-acceleration is available, it will be used. Checkout [sample page](https://defense.sh/syncscribe/sample-audio/sample_viewer.html) for a demonstration.

## Quick Start

### Generate Interactive Transcription Viewer

```bash
# Basic usage
./create_audio_viewer.sh your_audio.wav

# With custom model
./create_audio_viewer.sh --model medium
```

**Output:** Standalone HTML file in `out/` folder (or specified directory)

## Requirements

- **Python 3.8+**
- **NVIDIA GPU** (recommended) with CUDA support

## Installation

No manual installation needed, the scripts automatically:
1. Create Python virtual environment
2. Install all dependencies (faster-whisper, torch, librosa, etc.)
3. Configure GPU/CUDA settings
4. Download Whisper models to local cache

```bash
# Just clone and run
git clone <your-repo>
cd syncscribe
./create_audio_viewer.sh your_audio.wav
```

Everything is created and downloaded in the current directory for easy cleanup.
