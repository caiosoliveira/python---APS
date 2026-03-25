import os
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs

load_dotenv()

def clone_voice(name: str, sample_paths: list, description: str = "") -> str:
    client = ElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))
    files = [open(p, "rb") for p in sample_paths]
    voice = client.voices.ivc.create(
        name=name,
        description=description,
        files=files,
    )
    for f in files:
        f.close()
    print(f"Voz clonada com sucesso! ID: {voice.voice_id}")
    return voice.voice_id