#!/usr/bin/env python3
"""
Yet Another Audio Transcription library using Faster Whisper
"""

import os
import sys
import time
import logging
from pathlib import Path
from typing import Optional, List, Dict, Tuple
import warnings

try:
    from faster_whisper import WhisperModel
    import librosa
    import numpy as np
    from tqdm import tqdm
except ImportError as e:
    print(f"Error importing required libraries: {e}")
    sys.exit(1)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)
warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", category=UserWarning)


class HQTranscriber:
    def __init__(
        self,
        model_size: str = "large-v3",
        device: str = "cuda",
        compute_type: str = "float16",
        cpu_threads: int = 0,
        num_workers: int = 1
    ):
        """
        Initialize the transcriber with best quality settings.
        
        Args:
            model_size: Model size to use. Options: tiny, base, small, medium, large-v2, large-v3
            device: Device to use for inference ("cuda" for GPU, "cpu" for CPU)
            compute_type: Precision for inference ("float16" for GPU, "int8" for CPU)
            cpu_threads: Number of CPU threads (0 = auto)
            num_workers: Number of workers for parallel processing
        """
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        
        logger.info(f"Initializing Whisper model: {model_size}")
        logger.info(f"Device: {device}, Compute type: {compute_type}")
        
        # set up local cache directory
        script_dir = Path(__file__).parent
        cache_dir = script_dir / "cache"
        cache_dir.mkdir(exist_ok=True)
        
        try:
            self.model = WhisperModel(
                model_size,
                device=device,
                compute_type=compute_type,
                cpu_threads=cpu_threads,
                num_workers=num_workers,
                download_root=str(cache_dir),
                local_files_only=False
            )
            logger.info("Model loaded successfully!")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    def preprocess_audio(
        self, 
        audio_path: str, 
        target_sample_rate: int = 16000,
        normalize: bool = True
    ) -> Tuple[np.ndarray, int]:
        """
        Preprocess audio file for optimal transcription quality.
        
        Args:
            audio_path: Path to audio file
            target_sample_rate: Target sample rate (Whisper expects 16kHz)
            normalize: Whether to normalize audio amplitude
            
        Returns:
            Tuple of (audio_data, sample_rate)
        """
        logger.info(f"Preprocessing audio: {audio_path}")
        
        try:
            audio, sr = librosa.load(
                audio_path,
                sr=target_sample_rate,
                mono=True,
                dtype=np.float32
            )
            
            if normalize:
                audio = librosa.util.normalize(audio)
            
            logger.info(f"Audio preprocessed: {len(audio)/sr:.2f}s duration, {sr}Hz sample rate")
            return audio, sr
            
        except Exception as e:
            logger.error(f"Error preprocessing audio: {e}")
            raise
    
    def transcribe(
        self,
        audio_path: str,
        language: Optional[str] = None,
        task: str = "transcribe",
        beam_size: int = 5,
        best_of: int = 5,
        patience: float = 1.0,
        length_penalty: float = 1.0,
        repetition_penalty: float = 1.0,
        no_repeat_ngram_size: int = 0,
        temperature: List[float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        compression_ratio_threshold: float = 2.4,
        log_prob_threshold: float = -1.0,
        no_speech_threshold: float = 0.6,
        condition_on_previous_text: bool = True,
        prompt_reset_on_temperature: float = 0.5,
        initial_prompt: Optional[str] = None,
        prefix: Optional[str] = None,
        suppress_blank: bool = True,
        suppress_tokens: Optional[List[int]] = [-1],
        without_timestamps: bool = False,
        max_initial_timestamp: float = 1.0,
        word_timestamps: bool = True,
        prepend_punctuations: str = "\"'¿([{-",
        append_punctuations: str = "\"'.。,，!！?？:：\")}]、",
        vad_filter: bool = True,
        vad_parameters: Optional[Dict] = None
    ) -> Dict:
        """
        Transcribe audio with highest quality settings.
        
        Args:
            audio_path: Path to audio file
            language: Source language (None for auto-detection)
            task: Task type ("transcribe" or "translate")
            beam_size: Beam size for beam search
            best_of: Number of candidates to generate
            patience: Patience for beam search
            length_penalty: Length penalty for beam search
            repetition_penalty: Repetition penalty
            no_repeat_ngram_size: Size of n-grams to avoid repetition
            temperature: Temperature for sampling (list for fallback)
            compression_ratio_threshold: Compression ratio threshold
            log_prob_threshold: Log probability threshold
            no_speech_threshold: No speech threshold
            condition_on_previous_text: Whether to condition on previous text
            prompt_reset_on_temperature: Temperature to reset prompt
            initial_prompt: Initial prompt for the model
            prefix: Prefix for the transcription
            suppress_blank: Whether to suppress blank outputs
            suppress_tokens: List of token IDs to suppress
            without_timestamps: Whether to exclude timestamps
            max_initial_timestamp: Maximum initial timestamp
            word_timestamps: Whether to include word-level timestamps
            prepend_punctuations: Punctuations to prepend
            append_punctuations: Punctuations to append
            vad_filter: Whether to use voice activity detection
            vad_parameters: Parameters for VAD
            
        Returns:
            Dictionary containing transcription results
        """
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
        
        if vad_parameters is None:
            vad_parameters = {
                "threshold": 0.5,
                "min_speech_duration_ms": 250,
                "max_speech_duration_s": 60,
                "min_silence_duration_ms": 100,
                "speech_pad_ms": 30
            }
        
        logger.info(f"Starting transcription of: {audio_path}")
        start_time = time.time()
        
        try:
            audio_data, _ = self.preprocess_audio(audio_path)
            segments, info = self.model.transcribe(
                audio_data,
                language=language,
                task=task,
                beam_size=beam_size,
                best_of=best_of,
                patience=patience,
                length_penalty=length_penalty,
                repetition_penalty=repetition_penalty,
                no_repeat_ngram_size=no_repeat_ngram_size,
                temperature=temperature,
                compression_ratio_threshold=compression_ratio_threshold,
                log_prob_threshold=log_prob_threshold,
                no_speech_threshold=no_speech_threshold,
                condition_on_previous_text=condition_on_previous_text,
                prompt_reset_on_temperature=prompt_reset_on_temperature,
                initial_prompt=initial_prompt,
                prefix=prefix,
                suppress_blank=suppress_blank,
                suppress_tokens=suppress_tokens,
                without_timestamps=without_timestamps,
                max_initial_timestamp=max_initial_timestamp,
                word_timestamps=word_timestamps,
                prepend_punctuations=prepend_punctuations,
                append_punctuations=append_punctuations,
                vad_filter=vad_filter,
                vad_parameters=vad_parameters
            )

            segment_list = []
            full_text = ""
            logger.info("Processing transcription segments...")
            for segment in tqdm(segments, desc="Processing segments"):
                segment_dict = {
                    "id": segment.id,
                    "start": segment.start,
                    "end": segment.end,
                    "text": segment.text.strip(),
                    "avg_logprob": segment.avg_logprob,
                    "no_speech_prob": segment.no_speech_prob,
                    "compression_ratio": segment.compression_ratio,
                    "temperature": segment.temperature
                }
                
                # add word-level timestamps if available
                if hasattr(segment, 'words') and segment.words:
                    segment_dict["words"] = [
                        {
                            "word": word.word,
                            "start": word.start,
                            "end": word.end,
                            "probability": word.probability
                        }
                        for word in segment.words
                    ]
                
                segment_list.append(segment_dict)
                full_text += segment.text
            
            end_time = time.time()
            duration = end_time - start_time
            result = {
                "text": full_text.strip(),
                "segments": segment_list,
                "language": info.language,
                "language_probability": info.language_probability,
                "duration": info.duration,
                "duration_after_vad": info.duration_after_vad,
                "all_language_probs": info.all_language_probs,
                "transcription_time": duration,
                "audio_file": audio_path,
                "model_size": self.model_size,
                "settings": {
                    "beam_size": beam_size,
                    "best_of": best_of,
                    "temperature": temperature,
                    "word_timestamps": word_timestamps,
                    "vad_filter": vad_filter,
                    "device": self.device,
                    "compute_type": self.compute_type
                }
            }
            
            logger.info(f"Transcription completed in {duration:.2f}s")
            logger.info(f"Detected language: {info.language} (confidence: {info.language_probability:.3f})")
            logger.info(f"Audio duration: {info.duration:.2f}s")
            
            return result
            
        except Exception as e:
            logger.error(f"Transcription failed: {e}")
            raise
    
    def transcribe_file(
        self,
        audio_path: str,
        output_path: Optional[str] = None,
        output_formats: List[str] = ["txt", "json"],
        **kwargs
    ) -> Dict:
        """
        Transcribe a single audio file and save results.
        
        Args:
            audio_path: Path to audio file
            output_path: Output directory (None for same directory as input)
            output_formats: List of output formats ("txt", "json", "srt", "vtt")
            **kwargs: Additional transcription parameters
            
        Returns:
            Transcription results dictionary
        """
        audio_path = Path(audio_path)
        if output_path is None:
            output_path = audio_path.parent
        else:
            output_path = Path(output_path)
            output_path.mkdir(parents=True, exist_ok=True)
        
        result = self.transcribe(str(audio_path), **kwargs)
        base_name = audio_path.stem
        
        for fmt in output_formats:
            if fmt == "txt":
                txt_path = output_path / f"{base_name}_transcript.txt"
                with open(txt_path, "w", encoding="utf-8") as f:
                    f.write(result["text"])
                logger.info(f"Saved text transcript: {txt_path}")
            
            elif fmt == "json":
                import json
                json_path = output_path / f"{base_name}_transcript.json"
                with open(json_path, "w", encoding="utf-8") as f:
                    json.dump(result, f, indent=2, ensure_ascii=False)
                logger.info(f"Saved JSON transcript: {json_path}")
            
            elif fmt == "srt":
                srt_path = output_path / f"{base_name}_transcript.srt"
                self._save_srt(result["segments"], srt_path)
                logger.info(f"Saved SRT subtitle: {srt_path}")
            
            elif fmt == "vtt":
                vtt_path = output_path / f"{base_name}_transcript.vtt"
                self._save_vtt(result["segments"], vtt_path)
                logger.info(f"Saved VTT subtitle: {vtt_path}")
        
        return result
    
    def _save_srt(self, segments: List[Dict], output_path: str):
        """Save segments as SRT subtitle format."""
        with open(output_path, "w", encoding="utf-8") as f:
            for i, segment in enumerate(segments, 1):
                start = self._format_timestamp(segment["start"])
                end = self._format_timestamp(segment["end"])
                f.write(f"{i}\n")
                f.write(f"{start} --> {end}\n")
                f.write(f"{segment['text'].strip()}\n\n")
    
    def _save_vtt(self, segments: List[Dict], output_path: str):
        """Save segments as VTT subtitle format."""
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("WEBVTT\n\n")
            for segment in segments:
                start = self._format_timestamp(segment["start"], vtt=True)
                end = self._format_timestamp(segment["end"], vtt=True)
                f.write(f"{start} --> {end}\n")
                f.write(f"{segment['text'].strip()}\n\n")
    
    def _format_timestamp(self, seconds: float, vtt: bool = False) -> str:
        """Format timestamp for subtitle files."""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = seconds % 60
        
        if vtt:
            return f"{hours:02d}:{minutes:02d}:{secs:06.3f}"
        else:
            return f"{hours:02d}:{minutes:02d}:{secs:06.3f}".replace(".", ",")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Audio transcription using faster-whisper"
    )
    parser.add_argument("audio_file", help="Path to audio file")
    parser.add_argument("--model", default="large-v3", 
                       choices=["tiny", "base", "small", "medium", "large-v2", "large-v3"],
                       help="Whisper model size")
    parser.add_argument("--device", default="cuda", choices=["cuda", "cpu"],
                       help="Device for inference")
    parser.add_argument("--language", help="Source language (auto-detect if not specified)")
    parser.add_argument("--output", help="Output directory")
    parser.add_argument("--formats", nargs="+", default=["txt", "json"],
                       choices=["txt", "json", "srt", "vtt"],
                       help="Output formats")
    
    args = parser.parse_args()
    
    transcriber = HQTranscriber(
        model_size=args.model,
        device=args.device
    )
    result = transcriber.transcribe_file(
        args.audio_file,
        output_path=args.output,
        output_formats=args.formats,
        language=args.language
    )
    
    print(f"\nTranscription completed!")
    print(f"Text: {result['text'][:50]}...")
    print(f"Language: {result['language']} (confidence: {result['language_probability']:.3f})")
    print(f"Duration: {result['duration']:.2f}s")


if __name__ == "__main__":
    main()