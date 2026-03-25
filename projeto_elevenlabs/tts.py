import os
import tempfile
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs
from elevenlabs import VoiceSettings
import pygame

load_dotenv()

VOICE_ID = "onwK4e9ZLuTAKqWW03F9"  # Daniel

def speak(text: str, voice_id: str = VOICE_ID, output_path: str = None) -> str:
    client = ElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))
    audio = client.text_to_speech.convert(
        voice_id=voice_id,
        text=text,
        model_id="eleven_multilingual_v2",
        voice_settings=VoiceSettings(stability=0.6, similarity_boost=0.8),
    )
    if output_path is None:
        output_path = os.path.join(tempfile.gettempdir(), "tts_output.mp3")
    
    with open(output_path, "wb") as f:
        for chunk in audio:
            f.write(chunk)
    
    pygame.mixer.init()
    pygame.mixer.music.load(output_path)
    pygame.mixer.music.play()
    while pygame.mixer.music.get_busy():
        pygame.time.wait(100)
        
    if output_path is None:
        os.makedirs("outputs", exist_ok=True)
        output_path = os.path.join("outputs", "resposta.mp3")
    
    return output_path

