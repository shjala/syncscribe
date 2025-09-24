#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
PYTHON_VERSION="3.8"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
check_python_version() {
    local python_cmd="$1"
    if ! command_exists "$python_cmd"; then
        return 1
    fi
    
    local version=$($python_cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    
    if [ "$major" -eq 3 ] && [ "$minor" -ge 8 ]; then
        return 0
    else
        return 1
    fi
}

find_python() {
    local python_candidates=("python3.11" "python3.10" "python3.9" "python3.8" "python3" "python")
    
    for cmd in "${python_candidates[@]}"; do
        if check_python_version "$cmd"; then
            echo "$cmd"
            return 0
        fi
    done
    
    return 1
}

setup_venv() {
    log_info "Setting up Python virtual environment..."
    
    local python_cmd
    if ! python_cmd=$(find_python); then
        log_error "Python 3.8+ not found. Please install Python 3.8 or later."
        log_info "On Ubuntu/Debian: sudo apt update && sudo apt install python3 python3-venv python3-pip"
        log_info "On CentOS/RHEL: sudo yum install python3 python3-venv python3-pip"
        log_info "On macOS: brew install python3"
        exit 1
    fi
    
    log_info "Using Python: $python_cmd ($(${python_cmd} --version))"
    if [ ! -d "$VENV_DIR" ]; then
        log_info "Creating virtual environment at: $VENV_DIR"
        "$python_cmd" -m venv "$VENV_DIR"
        log_success "Virtual environment created successfully!"
    else
        log_info "Virtual environment already exists at: $VENV_DIR"
    fi
    
    source "$VENV_DIR/bin/activate"
    
    local python_version=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local cudnn_lib_path="$VENV_DIR/lib/python${python_version}/site-packages/nvidia/cudnn/lib"
    if [ -d "$cudnn_lib_path" ]; then
        export LD_LIBRARY_PATH="$cudnn_lib_path:$LD_LIBRARY_PATH"
        log_info "Set cuDNN library path: $cudnn_lib_path"
    fi
    log_info "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
}

install_dependencies() {
    log_info "Checking and installing dependencies..."
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        log_error "requirements.txt not found in $SCRIPT_DIR"
        exit 1
    fi

    log_info "Installing packages from requirements.txt..."
    pip install -r "$SCRIPT_DIR/requirements.txt"
    
    log_info "Verifying installation..."
    python -c "
import sys
try:
    import faster_whisper
    import librosa
    import numpy as np
    import torch
    print('✅ All required packages imported successfully!')
    
    # Check CUDA availability
    if torch.cuda.is_available():
        print(f'✅ CUDA is available! GPU: {torch.cuda.get_device_name(0)}')
        print(f'   GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB')
    else:
        print('⚠️  CUDA not available. Will use CPU (slower).')
        
except ImportError as e:
    print(f'Import error: {e}')
    sys.exit(1)
" || {
        log_error "Package verification failed. Please check the installation."
        exit 1
    }
    
    log_success "Dependencies installed and verified successfully!"
}

needs_setup() {
    if [ ! -d "$VENV_DIR" ]; then
        return 0
    fi
    
    source "$VENV_DIR/bin/activate" 2>/dev/null || return 0
    python -c "import faster_whisper, librosa, torch" 2>/dev/null || return 0
    
    return 1  # No setup needed
}

show_usage() {
    echo "Usage: $0 [OPTIONS] AUDIO_FILE"
    echo ""
    echo "High-Quality Audio Transcription using Faster-Whisper"
    echo ""
    echo "Arguments:"
    echo "  AUDIO_FILE              Path to audio file to transcribe"
    echo ""
    echo "Options:"
    echo "  -m, --model MODEL       Whisper model size (tiny, base, small, medium, large-v2, large-v3)"
    echo "                          Default: large-v3"
    echo "  -d, --device DEVICE     Device for inference (cuda, cpu)"
    echo "                          Default: cuda"
    echo "  -l, --language LANG     Source language (auto-detect if not specified)"
    echo "  -o, --output DIR        Output directory"
    echo "  -f, --formats FORMAT    Output formats (txt, json, srt, vtt)"
    echo "                          Default: txt json"
    echo "  --setup-only           Only setup environment, don't run transcription"
    echo "  --force-setup          Force reinstallation of dependencies"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 audio.wav"
    echo "  $0 --model medium --device cpu audio.mp3"
    echo "  $0 -l spanish -f txt srt audio.wav"
    echo "  $0 --setup-only"
}

main() {
    local audio_file=""
    local model="large-v3"
    local device="cuda"
    local language=""
    local output_dir=""
    local formats=("txt" "json")
    local setup_only=false
    local force_setup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--model)
                model="$2"
                shift 2
                ;;
            -d|--device)
                device="$2"
                shift 2
                ;;
            -l|--language)
                language="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -f|--formats)
                IFS=' ' read -ra formats <<< "$2"
                shift 2
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            --force-setup)
                force_setup=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$audio_file" ]; then
                    audio_file="$1"
                else
                    log_error "Multiple audio files specified. Please specify only one."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # check if we need to run setup
    if [ "$force_setup" = true ] || needs_setup; then
        log_info "Setting up transcription environment..."
        
        # remove existing venv if force setup
        if [ "$force_setup" = true ] && [ -d "$VENV_DIR" ]; then
            log_warning "Removing existing virtual environment..."
            rm -rf "$VENV_DIR"
        fi
        
        setup_venv
        install_dependencies
        log_success "Environment setup completed!"
    else
        log_info "Environment already set up. Activating..."
        source "$VENV_DIR/bin/activate"
        
        # set cuDNN library path for GPU acceleration
        local python_version=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        local cudnn_lib_path="$VENV_DIR/lib/python${python_version}/site-packages/nvidia/cudnn/lib"
        if [ -d "$cudnn_lib_path" ]; then
            export LD_LIBRARY_PATH="$cudnn_lib_path:$LD_LIBRARY_PATH"
            log_info "Set cuDNN library path: $cudnn_lib_path"
        fi
    fi
    
    # etup-only? then exit here
    if [ "$setup_only" = true ]; then
        log_success "Setup completed! You can now run transcriptions."
        exit 0
    fi
    
    if [ -z "$audio_file" ]; then
        log_error "No audio file specified."
        show_usage
        exit 1
    fi
    
    if [ ! -f "$audio_file" ]; then
        log_error "Audio file not found: $audio_file"
        exit 1
    fi
    
    local cmd_args=("$audio_file" "--model" "$model" "--device" "$device")
    if [ -n "$language" ]; then
        cmd_args+=("--language" "$language")
    fi
    if [ -n "$output_dir" ]; then
        cmd_args+=("--output" "$output_dir")
    fi
    if [ ${#formats[@]} -gt 0 ]; then
        cmd_args+=("--formats" "${formats[@]}")
    fi
    
    log_info "Starting transcription..."
    log_info "Audio file: $audio_file"
    log_info "Model: $model"
    log_info "Device: $device"
    log_info "Output formats: ${formats[*]}"
    echo "----------------------------------------"
    python "$SCRIPT_DIR/transcriber.py" "${cmd_args[@]}"
    echo "----------------------------------------"
    log_success "Transcription completed!"
}

trap 'log_warning "Script interrupted by user"; exit 130' INT

main "$@"