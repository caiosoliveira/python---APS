import argparse
from audio_input import record_audio, load_audio_file
from stt import transcribe_audio
from response_engine import ResponseEngine
from tts import speak, VOICE_ID

def run_pipeline(source: str = "mic", filepath: str = None, duration: int = 5):
    engine = ResponseEngine()

    # Bloco 1 — entrada de áudio
    if source == "mic":
        audio_path = record_audio(duration_seconds=duration)
    else:
        audio_path = load_audio_file(filepath)

    # Bloco 2 — transcrição STT
    print("A transcrever...")
    transcription = transcribe_audio(audio_path)
    print(f"Transcrição: {transcription}")

    # Bloco 3 — motor de resposta
    response_text = engine.get_response(transcription)
    print(f"Resposta: {response_text}")

    # Bloco 4 — síntese TTS
    print("A sintetizar resposta...")
    speak(response_text, voice_id=VOICE_ID, output_path="outputs/resposta.mp3")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", choices=["mic", "file"], default="mic")
    parser.add_argument("--file", type=str, default=None)
    parser.add_argument("--duration", type=int, default=5)
    args = parser.parse_args()
    run_pipeline(args.source, args.file, args.duration)