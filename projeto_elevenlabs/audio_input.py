import sounddevice as sd
import numpy as np
from scipy.io import wavfile
import tempfile
import os

SAMPLE_RATE = 16000

def record_audio(duration_seconds: int = 5, sample_rate: int = SAMPLE_RATE) -> str:
    print(f"A gravar {duration_seconds}s... fala agora!")
    audio = sd.rec(
        int(duration_seconds * sample_rate),
        samplerate=sample_rate,
        channels=1,
        dtype="int16"
    )
    sd.wait()
    print("Gravação concluída.")
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    wavfile.write(tmp.name, sample_rate, audio)
    return tmp.name

def load_audio_file(filepath: str) -> str:
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Ficheiro não encontrado: {filepath}")
    if not filepath.lower().endswith((".wav", ".mp3", ".m4a")):
        raise ValueError("Formato não suportado. Usa .wav, .mp3 ou .m4a")
    return filepath