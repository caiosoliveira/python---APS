import os
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs

load_dotenv()

def transcribe_audio(audio_filepath: str) -> str:
    client = ElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))
    with open(audio_filepath, "rb") as audio_file:
        result = client.speech_to_text.convert(
            file=audio_file,
            model_id="scribe_v1",
            language_code="pt",
        )
    return result.text