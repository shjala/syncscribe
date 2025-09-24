#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

check_file() {
    if [ ! -f "$1" ]; then
        log_error "File not found: $1"
        exit 1
    fi
}
create_html_viewer() {
    local audio_file="$1"
    local transcript_json="$2"
    local output_html="$3"
    local audio_basename="$(basename "$audio_file")"
    
    log_step "Creating interactive HTML viewer..."
    
    # Create HTML content
    cat > "$output_html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Transcription Viewer</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: #ffffff;
            padding: 30px;
            text-align: center;
            color: #333333;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .audio-section {
            padding: 30px;
            background: #ffffff;
            border-bottom: 1px solid #e5e5e5;
        }
        
        .audio-player {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .audio-controls {
            display: flex;
            align-items: center;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        /* Custom SVG Play/Pause Button */
        .play-btn {
            display: inline-block;
            cursor: pointer;
            transition: all 0.5s ease;
            position: relative;
            border: none;
            background: transparent;
            padding: 0;
        }

        .play-btn svg {
            width: 50px;
            height: 50px;
        }

        .btn-circle {
            stroke: #333;
            stroke-width: 2;
            fill: none;
            stroke-dasharray: 440;
            stroke-dashoffset: 440;
            transition: all 0.5s ease-in-out;
            opacity: 0.3;
        }

        .play-icon {
            transition: all 0.7s ease-in-out;
            stroke-dasharray: 180;
            stroke-dashoffset: 360;
            stroke: #333;
            stroke-width: 2;
            fill: none;
            transform: translateY(0);
        }

        .pause-bars {
            stroke: #333;
            stroke-width: 2;
            stroke-dasharray: 40;
            stroke-dashoffset: 0;
            transition: all 0.6s ease-in-out;
            opacity: 0;
        }

        .play-btn:hover .play-icon,
        .play-btn:hover .pause-bars {
            stroke-dashoffset: 0;
            opacity: 1;
            stroke: #333;
            animation: btnWiggle 0.7s ease-in-out;
        }

        .play-btn:hover .btn-circle {
            stroke-dashoffset: 0;
            opacity: 1;
        }

        @keyframes btnWiggle {
            0% { transform: translateX(0); }
            30% { transform: translateX(-2px); }
            50% { transform: translateX(2px); }
            70% { transform: translateX(-1px); }
            100% { transform: translateX(0); }
        }
        
        .time-info {
            display: flex;
            gap: 10px;
            align-items: center;
            font-family: 'Courier New', monospace;
            font-weight: bold;
        }
        
        .progress-container {
            flex: 1;
            margin: 0 20px;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e9ecef;
            border-radius: 4px;
            cursor: pointer;
            position: relative;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #34353a 0%, #d9d7dc 100%);
            border-radius: 4px;
            width: 0%;
            transition: width 0.1s ease;
        }
        
        .volume-container {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .volume-slider {
            width: 100px;
            height: 5px;
            background: #9ca3af;
            border-radius: 3px;
            outline: none;
            cursor: pointer;
            -webkit-appearance: none;
            appearance: none;
        }
        
        .volume-slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            height: 15px;
            width: 15px;
            border-radius: 50%;
            background: #4b5563;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .volume-slider::-webkit-slider-thumb:hover {
            background: #374151;
            transform: scale(1.1);
        }
        
        .volume-slider::-moz-range-thumb {
            width: 15px;
            height: 15px;
            border-radius: 50%;
            background: #4b5563;
            cursor: pointer;
            border: none;
            transition: all 0.3s ease;
        }
        
        .volume-slider::-moz-range-thumb:hover {
            background: #374151;
            transform: scale(1.1);
        }
        
        .transcript-section {
            padding: 30px;
        }
        
        .transcript-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
            padding-bottom: 15px;
            border-bottom: 2px solid #e9ecef;
        }
        
        .transcript-title {
            font-size: 1.8em;
            font-weight: 300;
            color: #495057;
        }
        
        .transcript-info {
            font-size: 0.9em;
            color: #6c757d;
            text-align: right;
        }
        
        .transcript-content {
            line-height: 2;
            font-size: 1.1em;
            max-height: 400px;
            overflow-y: auto;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #667eea;
        }
        
        .segment {
            cursor: pointer;
            padding: 5px 8px;
            margin: 2px 0;
            border-radius: 5px;
            transition: all 0.3s ease;
            display: inline;
        }
        
        .segment:hover {
            background-color: #e3f2fd;
        }
        
        .segment.active {
            background-color: #ffeb3b;
            font-weight: bold;
            box-shadow: 0 2px 8px rgba(255, 235, 59, 0.5);
        }
        
        .segment.played {
            background-color: #c8e6c9;
        }
        
        .word {
            cursor: pointer;
            padding: 2px 4px;
            margin: 1px 0;
            border-radius: 3px;
            transition: all 0.2s ease;
            display: inline;
        }
        
        .word:hover {
            background-color: #e3f2fd;
        }
        
        .word.active {
            background-color: #ffeb3b;
            font-weight: bold;
            box-shadow: 0 1px 4px rgba(255, 235, 59, 0.5);
        }
        
        .word.played {
            background-color: #c8e6c9;
        }
        
        /* Translation tooltip styles */
        .tooltip {
            position: absolute;
            background: #2c3e50;
            color: white;
            padding: 8px 12px;
            border-radius: 6px;
            font-size: 0.9em;
            max-width: 200px;
            word-wrap: break-word;
            z-index: 1000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            border: 1px solid #34495e;
            opacity: 0;
            transform: translateY(-5px);
            transition: all 0.2s ease;
            pointer-events: none;
        }
        
        .tooltip.show {
            opacity: 1;
            transform: translateY(0);
        }
        
        .tooltip::after {
            content: '';
            position: absolute;
            top: 100%;
            left: 50%;
            margin-left: -5px;
            border: 5px solid transparent;
            border-top-color: #2c3e50;
        }
        
        .tooltip .translation-text {
            font-weight: bold;
        }
        
        /* Custom SVG Skip Buttons */
        .skip-btn {
            display: inline-block;
            cursor: pointer;
            transition: all 0.5s ease;
            position: relative;
            border: none;
            background: transparent;
            padding: 5px;
        }

        .skip-btn svg {
            width: 40px;
            height: 40px;
        }

        .skip-circle {
            stroke: #333;
            stroke-width: 2;
            fill: none;
            stroke-dasharray: 300;
            stroke-dashoffset: 300;
            transition: all 0.5s ease-in-out;
            opacity: 0.3;
        }

        .skip-arrows {
            stroke: #333;
            stroke-width: 2;
            fill: none;
            stroke-dasharray: 80;
            stroke-dashoffset: 0;
            transition: all 0.6s ease-in-out;
        }

        .skip-btn:hover .skip-arrows {
            stroke: #333;
            animation: skipSlide 0.6s ease-in-out;
        }

        .skip-btn:hover .skip-circle {
            stroke-dashoffset: 0;
            opacity: 1;
        }

        .skip-btn.backward:hover .skip-arrows {
            animation: skipSlideLeft 0.6s ease-in-out;
        }

        .skip-btn.forward:hover .skip-arrows {
            animation: skipSlideRight 0.6s ease-in-out;
        }

        @keyframes skipSlideLeft {
            0% { transform: translateX(0); }
            50% { transform: translateX(-2px); }
            100% { transform: translateX(0); }
        }

        @keyframes skipSlideRight {
            0% { transform: translateX(0); }
            50% { transform: translateX(2px); }
            100% { transform: translateX(0); }
        }

        /* Custom Speed Buttons */
        .speed-btn-svg {
            display: inline-block;
            cursor: pointer;
            transition: all 0.5s ease;
            position: relative;
            border: none;
            background: transparent;
            padding: 5px;
            margin: 0 2px;
        }

        .speed-btn-svg svg {
            width: 50px;
            height: 50px;
        }

        .speed-circle {
            stroke: #333;
            stroke-width: 2;
            fill: none;
            stroke-dasharray: 380;
            stroke-dashoffset: 380;
            transition: all 0.5s ease-in-out;
            opacity: 0.3;
        }

        .speed-text {
            fill: #333;
            font-size: 18px;
            font-weight: bold;
            opacity: 1;
            transition: all 0.6s ease-in-out;
            text-anchor: middle;
            font-family: Arial, sans-serif;
        }

        .speed-btn-svg:hover .speed-text {
            fill: #333;
            animation: speedWiggle 0.7s ease-in-out;
        }

        .speed-btn-svg:hover .speed-circle {
            stroke-dashoffset: 0;
            opacity: 1;
        }

        .speed-btn-svg.active .speed-circle {
            stroke-dashoffset: 0;
            opacity: 1;
        }

        .speed-btn-svg.active .speed-text {
            fill: #333;
        }

        @keyframes speedWiggle {
            0% { transform: translateX(0); }
            30% { transform: translateX(-1px); }
            50% { transform: translateX(1px); }
            70% { transform: translateX(-0.5px); }
            100% { transform: translateX(0); }
        }
        
        /* Custom Scroll Button */
        .scroll-btn-svg {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 3px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            border: 1px solid #ddd;
            background: white;
            color: #333;
            border-radius: 6px;
            padding: 0px 4px;
            font-size: 0.85em;
            font-weight: 500;
            line-height: 1.2;
            min-height: 20px;
        }

        .scroll-btn-svg:hover,
        .scroll-btn-svg.active {
            background: #f5f5f5;
            color: #333;
            transform: translateY(-2px);
        }

        .scroll-btn-svg svg {
            width: 14px;
            height: 14px;
        }

        .scroll-text {
            font-size: 0.85em;
            font-weight: 500;
            color: inherit;
            line-height: 1;
        }

        .scroll-icon {
            stroke: #333;
            stroke-width: 2;
            fill: none;
        }
        
        .controls-section {
            padding: 20px 30px;
            background: white;
            display: flex;
            gap: 15px;
            justify-content: center;
            flex-wrap: wrap;
        }
        
        .control-btn {
            padding: 10px 20px;
            border: 2px solid #ddd;
            background: white;
            color: #333;
            border-radius: 25px;
            cursor: pointer;
            font-size: 0.9em;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        .control-btn:hover,
        .control-btn.active {
            background: #f5f5f5;
            color: #333;
            transform: translateY(-2px);
        }
        
        .speed-control {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .speed-btn {
            width: 35px;
            height: 35px;
            border: 2px solid #ddd;
            background: white;
            color: #333;
            border-radius: 50%;
            cursor: pointer;
            font-size: 0.8em;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        
        .speed-btn:hover,
        .speed-btn.active {
            background: #f5f5f5;
            color: white;
        }
        
        @media (max-width: 768px) {
            .container {
                margin: 10px;
                border-radius: 15px;
            }
            
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .audio-section,
            .transcript-section {
                padding: 20px;
            }
            
            .audio-controls {
                flex-direction: column;
                gap: 15px;
            }
            
            .progress-container {
                margin: 0;
                width: 100%;
            }
            
            .controls-section {
                flex-direction: column;
                align-items: center;
            }
            
            .speed-control {
                justify-content: center;
            }
        }
        
        .footer {
            text-align: center;
            padding: 20px 30px;
            border-top: 1px solid #e5e5e5;
            background: white;
            font-size: 0.9em;
            color: #666;
        }
        
        .footer a {
            color: #333;
            text-decoration: none;
            font-weight: 500;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><svg width="60" height="60" viewBox="0 0 100 100" style="vertical-align: text-bottom; margin-right: 10px;">
                <rect x="35" y="20" width="30" height="45" rx="15" fill="none" stroke="#333" stroke-width="3"/>
                <line x1="50" y1="70" x2="50" y2="85" stroke="#333" stroke-width="3" stroke-linecap="round"/>
                <line x1="35" y1="85" x2="65" y2="85" stroke="#333" stroke-width="3" stroke-linecap="round"/>
                <circle cx="50" cy="42" r="8" fill="#333"/>
                <line x1="20" y1="35" x2="25" y2="35" stroke="#333" stroke-width="2" stroke-linecap="round"/>
                <line x1="20" y1="42" x2="25" y2="42" stroke="#333" stroke-width="2" stroke-linecap="round"/>
                <line x1="20" y1="49" x2="25" y2="49" stroke="#333" stroke-width="2" stroke-linecap="round"/>
                <line x1="75" y1="35" x2="80" y2="35" stroke="#333" stroke-width="2" stroke-linecap="round"/>
                <line x1="75" y1="42" x2="80" y2="42" stroke="#333" stroke-width="2" stroke-linecap="round"/>
                <line x1="75" y1="49" x2="80" y2="49" stroke="#333" stroke-width="2" stroke-linecap="round"/>
            </svg> Audio Transcription Viewer</h1>
            <p id="audioTitle">AUDIO_FILENAME</p>
        </div>
        
        <div class="audio-section">
            <div class="audio-player">
                <audio id="audioPlayer" preload="metadata">
                    <source src="AUDIO_DATA_URL" type="audio/mpeg">
                    Your browser does not support the audio element.
                </audio>
                
                <div class="audio-controls">
                    <button id="playBtn" class="play-btn">
                        <svg viewBox="0 0 100 100">
                            <circle class="btn-circle" cx="50" cy="50" r="35"/>
                            <polygon class="play-icon" points="40,30 40,70 70,50" stroke-linejoin="round"/>
                            <line class="pause-bars" x1="42" y1="35" x2="42" y2="65"/>
                            <line class="pause-bars" x1="58" y1="35" x2="58" y2="65"/>
                        </svg>
                    </button>
                    
                    <div class="time-info">
                        <span id="currentTime">00:00</span>
                        <span>/</span>
                        <span id="totalTime">00:00</span>
                    </div>
                    
                    <div class="progress-container">
                        <div id="progressBar" class="progress-bar">
                            <div id="progressFill" class="progress-fill"></div>
                        </div>
                    </div>
                    
                    <div class="volume-container">
                        <svg width="20" height="20" viewBox="0 0 100 100">
                            <polygon points="20,35 20,65 35,65 55,80 55,20 35,35" fill="#333" stroke="none"/>
                            <path d="M65,30 Q75,40 75,50 Q75,60 65,70" fill="none" stroke="#333" stroke-width="3" stroke-linecap="round"/>
                            <path d="M75,20 Q90,35 90,50 Q90,65 75,80" fill="none" stroke="#333" stroke-width="3" stroke-linecap="round"/>
                        </svg>
                        <input type="range" id="volumeSlider" class="volume-slider" min="0" max="1" step="0.1" value="1">
                    </div>
                </div>
            </div>
        </div>
        
        <div class="controls-section">
            <button class="skip-btn backward" onclick="skipTime(-10)">
                <svg viewBox="0 0 100 100">
                    <circle class="skip-circle" cx="50" cy="50" r="30"/>
                    <polygon class="skip-arrows" points="45,35 30,50 45,65" stroke-linejoin="round"/>
                    <polygon class="skip-arrows" points="65,35 50,50 65,65" stroke-linejoin="round"/>
                </svg>
            </button>
            <button class="skip-btn forward" onclick="skipTime(10)">
                <svg viewBox="0 0 100 100">
                    <circle class="skip-circle" cx="50" cy="50" r="30"/>
                    <polygon class="skip-arrows" points="35,35 50,50 35,65" stroke-linejoin="round"/>
                    <polygon class="skip-arrows" points="55,35 70,50 55,65" stroke-linejoin="round"/>
                </svg>
            </button>
            
            <div class="speed-control">
                <span>Speed:</span>
                <button class="speed-btn-svg" onclick="setSpeed(0.5)">
                    <svg viewBox="0 0 100 100">
                        <circle class="speed-circle" cx="50" cy="50" r="30"/>
                        <text class="speed-text" x="50" y="58">0.5x</text>
                    </svg>
                </button>
                <button class="speed-btn-svg active" onclick="setSpeed(1)">
                    <svg viewBox="0 0 100 100">
                        <circle class="speed-circle" cx="50" cy="50" r="30"/>
                        <text class="speed-text" x="50" y="58">1x</text>
                    </svg>
                </button>
                <button class="speed-btn-svg" onclick="setSpeed(1.25)">
                    <svg viewBox="0 0 100 100">
                        <circle class="speed-circle" cx="50" cy="50" r="30"/>
                        <text class="speed-text" x="50" y="58">1.25x</text>
                    </svg>
                </button>
                <button class="speed-btn-svg" onclick="setSpeed(1.5)">
                    <svg viewBox="0 0 100 100">
                        <circle class="speed-circle" cx="50" cy="50" r="30"/>
                        <text class="speed-text" x="50" y="58">1.5x</text>
                    </svg>
                </button>
                <button class="speed-btn-svg" onclick="setSpeed(2)">
                    <svg viewBox="0 0 100 100">
                        <circle class="speed-circle" cx="50" cy="50" r="30"/>
                        <text class="speed-text" x="50" y="58">2x</text>
                    </svg>
                </button>
            </div>
            
            <button class="scroll-btn-svg" onclick="toggleAutoScroll()">
                <svg viewBox="15 15 70 70">
                    <path class="scroll-icon" d="M35,35 L50,20 L65,35 M35,45 L50,30 L65,45 M35,55 L50,40 L65,55 M35,65 L50,50 L65,65 M35,75 L50,60 L65,75" stroke-linejoin="round" stroke-linecap="round"/>
                </svg>
                <span class="scroll-text">Auto Scroll</span>
            </button>
        </div>
        
        <div class="transcript-section">
            <div class="transcript-header">
                <h2 class="transcript-title">Transcription</h2>
                <div class="transcript-info">
                    <div>Language: <strong id="detectedLanguage">DETECTED_LANGUAGE</strong></div>
                </div>
            </div>
            
            <div id="transcriptContent" class="transcript-content">
                <!-- Words will be inserted here -->
            </div>
        </div>
        
        <div class="footer">
            Made by <a href="https://github.com/shjala/syncscribe" target="_blank">SyncScribe</a>
        </div>
    </div>

    <script>
        // Transcript data
        const transcriptData = TRANSCRIPT_JSON;
        
        // Audio elements
        const audio = document.getElementById('audioPlayer');
        const playBtn = document.getElementById('playBtn');
        const currentTimeEl = document.getElementById('currentTime');
        const totalTimeEl = document.getElementById('totalTime');
        const progressBar = document.getElementById('progressBar');
        const progressFill = document.getElementById('progressFill');
        const volumeSlider = document.getElementById('volumeSlider');
        const transcriptContent = document.getElementById('transcriptContent');
        
        // State variables
        let isPlaying = false;
        let autoScroll = true;
        let currentSegmentIndex = -1;
        
        // Translation variables
        let tooltip = null;
        let translationCache = new Map();
        let currentLanguage = null;
        
        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            setupTranscript();
            setupAudioEvents();
            updateLanguageInfo();
            initializeButtons();
            // Start pre-caching translations
            setTimeout(precacheTranslations, 1000); // Start after 1 second delay
        });
        
        function initializeButtons() {
            // Initialize play button state (show play icon, hide pause bars)
            const playIcon = playBtn.querySelector('.play-icon');
            const pauseBars = playBtn.querySelectorAll('.pause-bars');
            
            if (playIcon) playIcon.style.opacity = '1';
            pauseBars.forEach(bar => bar.style.opacity = '0');
        }
        
        function setupTranscript() {
            let transcriptHTML = '';
            
            transcriptData.segments.forEach((segment, segmentIndex) => {
                if (segment.words && segment.words.length > 0) {
                    // Use word-level timestamps if available
                    segment.words.forEach((word, wordIndex) => {
                        transcriptHTML += `<span class="word" data-start="${word.start}" data-end="${word.end}" data-segment="${segmentIndex}" data-word="${wordIndex}" onclick="seekToSegment(${word.start})">${word.word}</span>`;
                        // Add space after word, but not if it's punctuation
                        if (!word.word.match(/^[.,!?;:]$/)) {
                            transcriptHTML += ' ';
                        }
                    });
                } else {
                    // Fallback to segment-level if no word timestamps
                    const words = segment.text.trim().split(/\s+/);
                    const segmentDuration = segment.end - segment.start;
                    const wordDuration = segmentDuration / words.length;
                    
                    words.forEach((word, wordIndex) => {
                        const wordStart = segment.start + (wordIndex * wordDuration);
                        const wordEnd = segment.start + ((wordIndex + 1) * wordDuration);
                        transcriptHTML += `<span class="word" data-start="${wordStart}" data-end="${wordEnd}" data-segment="${segmentIndex}" data-word="${wordIndex}" onclick="seekToSegment(${wordStart})">${word}</span> `;
                    });
                }
            });
            
            transcriptContent.innerHTML = transcriptHTML;
            
            // Add hover events for translation
            setupTranslationHovers();
        }
        
        function setupTranslationHovers() {
            const words = document.querySelectorAll('.word');
            
            words.forEach(word => {
                word.addEventListener('mouseenter', function(e) {
                    const wordText = e.target.textContent.trim();
                    if (wordText && !wordText.match(/^[.,!?;:()"\-\s]+$/)) {
                        showTranslation(e.target, wordText);
                    }
                });
                
                word.addEventListener('mouseleave', function() {
                    hideTooltip();
                });
            });
        }
        
        async function showTranslation(element, word) {
            // Clean word (remove punctuation)
            const cleanWord = word.replace(/[.,!?;:()"\-]/g, '').toLowerCase();
            
            if (!cleanWord || cleanWord.length < 2) return;
            
            // Skip if language is English
            if (!currentLanguage || currentLanguage === 'en' || currentLanguage === 'english') {
                return;
            }
            
            // Check cache first
            const cacheKey = `${currentLanguage}-${cleanWord}`;
            if (translationCache.has(cacheKey)) {
                displayTooltip(element, translationCache.get(cacheKey));
                return;
            }
            
            // Show loading tooltip
            displayTooltip(element, 'Translating...');
            
            try {
                let translation = 'Translation not found';
                
                // Try Google Translate (unofficial) first
                try {
                    const response = await fetch(`https://translate.googleapis.com/translate_a/single?client=gtx&sl=${currentLanguage}&tl=en&dt=t&q=${encodeURIComponent(cleanWord)}`);
                    
                    if (response.ok) {
                        const data = await response.json();
                        if (data && data[0] && data[0][0] && data[0][0][0]) {
                            translation = data[0][0][0];
                        }
                    }
                } catch (err) {
                    console.warn('Google Translate failed:', err);
                }
                
                // Fallback to MyMemory if Google failed
                if (translation === 'Translation not found') {
                    try {
                        const response = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(cleanWord)}&langpair=${currentLanguage}|en`, {
                            method: 'GET',
                            headers: {
                                'Accept': 'application/json',
                            }
                        });
                        
                        if (response.ok) {
                            const data = await response.json();
                            if (data.responseStatus === 200 && data.responseData && data.responseData.translatedText) {
                                const translated = data.responseData.translatedText;
                                // Check if it's not a quota error message
                                if (!translated.includes('MYMEMORY WARNING') && !translated.includes('QUOTA')) {
                                    translation = translated;
                                }
                            }
                        }
                    } catch (err) {
                        console.warn('MyMemory API failed:', err);
                    }
                }
                

                
                // Cache the result
                translationCache.set(cacheKey, translation);
                displayTooltip(element, translation);
                
            } catch (error) {
                console.warn('Translation failed:', error);
                displayTooltip(element, 'Translation unavailable');
            }
        }
        
        function displayTooltip(element, text) {
            hideTooltip();
            
            tooltip = document.createElement('div');
            tooltip.className = 'tooltip';
            tooltip.innerHTML = `
                <div class="translation-text">${text}</div>
            `;
            
            document.body.appendChild(tooltip);
            
            // Position tooltip
            const rect = element.getBoundingClientRect();
            const tooltipRect = tooltip.getBoundingClientRect();
            
            let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2);
            let top = rect.top + window.pageYOffset - tooltipRect.height - 10;
            
            // Adjust if tooltip goes off screen
            if (left < 10) left = 10;
            if (left + tooltipRect.width > window.innerWidth - 10) {
                left = window.innerWidth - tooltipRect.width - 10;
            }
            if (top < window.pageYOffset + 10) {
                top = rect.bottom + window.pageYOffset + 10;
            }
            
            tooltip.style.left = left + 'px';
            tooltip.style.top = top + 'px';
            
            // Show tooltip with animation
            setTimeout(() => {
                if (tooltip) tooltip.classList.add('show');
            }, 10);
        }
        
        function hideTooltip() {
            if (tooltip) {
                tooltip.remove();
                tooltip = null;
            }
        }
        
        async function precacheTranslations() {
            if (!currentLanguage || currentLanguage === 'en') return;
            
            console.log('Starting translation pre-caching...');
            
            // Collect all unique words from the transcript
            const words = document.querySelectorAll('.word');
            const uniqueWords = new Set();
            
            words.forEach(word => {
                const wordText = word.textContent.trim();
                const cleanWord = wordText.replace(/[.,!?;:()"\-]/g, '').toLowerCase();
                if (cleanWord && cleanWord.length >= 2 && !cleanWord.match(/^[.,!?;:()"\-\s]+$/)) {
                    uniqueWords.add(cleanWord);
                }
            });
            
            console.log(`Pre-caching translations for ${uniqueWords.size} unique words...`);
            
            // Cache translations in batches to avoid overwhelming the API
            const wordsArray = Array.from(uniqueWords);
            const batchSize = 5; // Process 5 words at a time
            const delay = 200; // 200ms delay between batches
            
            for (let i = 0; i < wordsArray.length; i += batchSize) {
                const batch = wordsArray.slice(i, i + batchSize);
                
                // Process batch in parallel
                const promises = batch.map(word => cacheTranslation(word));
                await Promise.allSettled(promises);
                
                // Add delay between batches to be respectful to the API
                if (i + batchSize < wordsArray.length) {
                    await new Promise(resolve => setTimeout(resolve, delay));
                }
                
                // Show progress
                const progress = Math.min(100, Math.round(((i + batchSize) / wordsArray.length) * 100));
                console.log(`Translation caching progress: ${progress}%`);
            }
            
            console.log('Translation pre-caching completed!');
        }
        
        async function cacheTranslation(cleanWord) {
            const cacheKey = `${currentLanguage}-${cleanWord}`;
            
            // Skip if already cached
            if (translationCache.has(cacheKey)) return;
            
            try {
                let translation = 'Translation not found';
                
                // Try Google Translate (unofficial) first
                try {
                    const response = await fetch(`https://translate.googleapis.com/translate_a/single?client=gtx&sl=${currentLanguage}&tl=en&dt=t&q=${encodeURIComponent(cleanWord)}`);
                    
                    if (response.ok) {
                        const data = await response.json();
                        if (data && data[0] && data[0][0] && data[0][0][0]) {
                            translation = data[0][0][0];
                        }
                    }
                } catch (err) {
                    // Silently fail for pre-caching
                }
                
                // Fallback to MyMemory if Google failed
                if (translation === 'Translation not found') {
                    try {
                        const response = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(cleanWord)}&langpair=${currentLanguage}|en`);
                        const data = await response.json();
                        
                        if (data.responseStatus === 200 && data.responseData && data.responseData.translatedText) {
                            const translated = data.responseData.translatedText;
                            if (!translated.includes('MYMEMORY WARNING') && !translated.includes('QUOTA')) {
                                translation = translated;
                            }
                        }
                    } catch (err) {
                        // Silently fail for pre-caching
                    }
                }
                
                // Cache the result
                translationCache.set(cacheKey, translation);
                
            } catch (error) {
                // Silently fail for pre-caching - we don't want to spam the console
                translationCache.set(cacheKey, 'Translation unavailable');
            }
        }
        
        function setupAudioEvents() {
            // Play/pause button
            playBtn.addEventListener('click', togglePlayPause);
            
            // Time update
            audio.addEventListener('timeupdate', updateProgress);
            
            // Load metadata
            audio.addEventListener('loadedmetadata', function() {
                totalTimeEl.textContent = formatTime(audio.duration);
            });
            
            // Progress bar click
            progressBar.addEventListener('click', function(e) {
                const rect = progressBar.getBoundingClientRect();
                const clickX = e.clientX - rect.left;
                const width = rect.width;
                const percentage = clickX / width;
                const newTime = percentage * audio.duration;
                audio.currentTime = newTime;
            });
            
            // Volume control
            volumeSlider.addEventListener('input', function() {
                audio.volume = volumeSlider.value;
            });
            
            // Keyboard controls
            document.addEventListener('keydown', function(e) {
                switch(e.code) {
                    case 'Space':
                        e.preventDefault();
                        togglePlayPause();
                        break;
                    case 'ArrowLeft':
                        skipTime(-5);
                        break;
                    case 'ArrowRight':
                        skipTime(5);
                        break;
                    case 'ArrowUp':
                        e.preventDefault();
                        audio.volume = Math.min(1, audio.volume + 0.1);
                        volumeSlider.value = audio.volume;
                        break;
                    case 'ArrowDown':
                        e.preventDefault();
                        audio.volume = Math.max(0, audio.volume - 0.1);
                        volumeSlider.value = audio.volume;
                        break;
                }
            });
        }
        
        function togglePlayPause() {
            const playIcon = playBtn.querySelector('.play-icon');
            const pauseBars = playBtn.querySelectorAll('.pause-bars');
            
            if (isPlaying) {
                audio.pause();
                // Show play icon, hide pause bars
                playIcon.style.opacity = '1';
                pauseBars.forEach(bar => bar.style.opacity = '0');
                isPlaying = false;
            } else {
                audio.play();
                // Hide play icon, show pause bars
                playIcon.style.opacity = '0';
                pauseBars.forEach(bar => bar.style.opacity = '1');
                isPlaying = true;
            }
        }
        
        function updateProgress() {
            const currentTime = audio.currentTime;
            const duration = audio.duration;
            
            // Update time display
            currentTimeEl.textContent = formatTime(currentTime);
            
            // Update progress bar
            const percentage = (currentTime / duration) * 100;
            progressFill.style.width = percentage + '%';
            
            // Update active segment
            updateActiveSegment(currentTime);
        }
        
        function updateActiveSegment(currentTime) {
            const words = document.querySelectorAll('.word');
            let activeIndex = -1;
            let foundActiveWord = false;
            
            words.forEach((word, index) => {
                const start = parseFloat(word.dataset.start);
                const end = parseFloat(word.dataset.end);
                
                word.classList.remove('active');
                
                if (currentTime >= start && currentTime < end) {
                    word.classList.add('active');
                    activeIndex = index;
                    foundActiveWord = true;
                    
                    // Auto scroll to active word
                    if (autoScroll) {
                        word.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }
                } else if (currentTime >= end) {
                    word.classList.add('played');
                } else {
                    word.classList.remove('played');
                }
            });
            
            // If no word is active (like during music/silence), make sure no word is highlighted
            if (!foundActiveWord) {
                activeIndex = -1;
            }
            
            currentSegmentIndex = activeIndex;
        }
        
        function seekToSegment(time) {
            audio.currentTime = time;
        }
        
        function skipTime(seconds) {
            audio.currentTime += seconds;
        }
        
        function setSpeed(speed) {
            audio.playbackRate = speed;
            
            // Update active speed button
            document.querySelectorAll('.speed-btn-svg').forEach(btn => {
                btn.classList.remove('active');
            });
            document.querySelectorAll('.speed-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            
            if (event && event.target) {
                // Check if clicked element is the button or inside the button
                let targetButton = event.target;
                if (event.target.tagName === 'svg' || event.target.tagName === 'text' || event.target.tagName === 'circle') {
                    targetButton = event.target.closest('button');
                }
                if (targetButton) {
                    targetButton.classList.add('active');
                }
            }
        }
        
        function toggleAutoScroll() {
            autoScroll = !autoScroll;
            event.target.classList.toggle('active');
        }
        
        function formatTime(seconds) {
            const minutes = Math.floor(seconds / 60);
            const remainingSeconds = Math.floor(seconds % 60);
            return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
        }
        
        function updateLanguageInfo() {
            // Update language only
            currentLanguage = transcriptData.language;
            document.getElementById('detectedLanguage').textContent = transcriptData.language.toUpperCase();
        }
    </script>
</body>
</html>
EOF

    # replace placeholders with actual data
    python3 -c "
import base64
import json

# Read files
with open('$transcript_json', 'r') as f:
    transcript_data = f.read()

with open('$audio_file', 'rb') as f:
    audio_data = f.read()

# Get audio type
audio_ext = '$audio_file'.lower().split('.')[-1]
audio_types = {
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav', 
    'm4a': 'audio/mp4',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac'
}
audio_type = audio_types.get(audio_ext, 'audio/mpeg')
audio_b64 = base64.b64encode(audio_data).decode('utf-8')
audio_data_url = f'data:{audio_type};base64,{audio_b64}'
with open('$output_html', 'r') as f:
    html_content = f.read()

html_content = html_content.replace('AUDIO_FILENAME', '$audio_basename')
html_content = html_content.replace('AUDIO_DATA_URL', audio_data_url)
html_content = html_content.replace('TRANSCRIPT_JSON', transcript_data)
with open('$output_html', 'w') as f:
    f.write(html_content)
"
    
    log_success "HTML viewer created: $output_html"
}

show_usage() {
    echo "Usage: $0 [OPTIONS] AUDIO_FILE"
    echo ""
    echo "Interactive Audio Transcription Viewer Generator"
    echo ""
    echo "Arguments:"
    echo "  AUDIO_FILE              Path to audio file to transcribe"
    echo ""
    echo "Options:"
    echo "  -o, --output DIR        Output directory for HTML file"
    echo "  -m, --model MODEL       Whisper model size (tiny, base, small, medium, large-v2, large-v3)"
    echo "                          Default: large-v3"
    echo "  -d, --device DEVICE     Device for inference (cuda, cpu)"
    echo "                          Default: cuda"
    echo "  -l, --language LANG     Source language (auto-detect if not specified)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 audio.wav"
    echo "  $0 --model medium audio.mp3"
    echo "  $0 -l spanish -o viewers/ audio.wav"
}

main() {
    local audio_file=""
    local output_dir=""
    local model="large-v3"
    local device="cuda"
    local language=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
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
    
    if [ -z "$audio_file" ]; then
        log_error "No audio file specified."
        show_usage
        exit 1
    fi
    
    check_file "$audio_file"
    
    if [ -z "$output_dir" ]; then
        output_dir="$SCRIPT_DIR/out"
    fi
    mkdir -p "$output_dir"
    
    local base_name="$(basename "$audio_file" | sed 's/\.[^.]*$//')"
    local transcript_json="$output_dir/${base_name}_transcript.json"
    local output_html="$output_dir/${base_name}_viewer.html"
    
    echo "🎙️  INTERACTIVE AUDIO TRANSCRIPTION VIEWER GENERATOR"
    echo "=================================================="
    
    log_info "Input audio: $audio_file"
    log_info "Output HTML: $output_html"
    log_info "Model: $model | Device: $device"
    
    # run transcription
    log_step "Running transcription..."
    local transcribe_cmd=("$SCRIPT_DIR/run_transcriber.sh")
    transcribe_cmd+=("--model" "$model" "--device" "$device")
    transcribe_cmd+=("--formats" "json")
    transcribe_cmd+=("--output" "$output_dir")
    
    if [ -n "$language" ]; then
        transcribe_cmd+=("--language" "$language")
    fi
    
    transcribe_cmd+=("$audio_file")
    
    if ! "${transcribe_cmd[@]}"; then
        log_error "Transcription failed"
        exit 1
    fi
    
    # check if transcript JSON was created
    check_file "$transcript_json"
    log_success "Transcription completed!"
    
    # create HTML viewer
    log_step "Creating interactive HTML viewer..."
    create_html_viewer "$audio_file" "$transcript_json" "$output_html"
    
    echo ""
    echo "Done!"
    echo "=========================================="
    log_success "HTML viewer: $output_html"
    log_info "Open the HTML file in any modern web browser to start using!"
}

trap 'log_warning "Script interrupted by user"; exit 130' INT

main "$@"