import streamlit as st
import tempfile
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from audio_input import record_audio
from stt import transcribe_audio
from response_engine import ResponseEngine
from tts import speak, VOICE_ID

st.set_page_config(page_title="Sistema de Conversação", page_icon="🎙️")
st.title("🎙️ Sistema de Conversação — ElevenLabs")
st.caption("Trabalho Prático — Aplicação de Processamento de Sinal")

@st.cache_resource
def load_engine():
    return ResponseEngine()

def processar(audio_path: str, engine: ResponseEngine):
    with st.spinner("A transcrever..."):
        transcricao = transcribe_audio(audio_path)
    st.info(f"📝 Transcrição: **{transcricao}**")

    resposta = engine.get_response(transcricao)
    st.success(f"💬 Resposta: **{resposta}**")

    with st.spinner("A sintetizar voz..."):
        output_path = speak(resposta, voice_id=VOICE_ID, output_path="output.mp3")
    st.audio(output_path)

engine = load_engine()

modo = st.radio("Modo de entrada de áudio", ["Ficheiro de áudio", "Microfone"])

if modo == "Ficheiro de áudio":
    uploaded = st.file_uploader("Carrega um ficheiro .wav ou .mp3", type=["wav", "mp3"])
    if uploaded and st.button("▶ Processar"):
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.write(uploaded.read())
        tmp.flush()
        processar(tmp.name, engine)

elif modo == "Microfone":
    duracao = st.slider("Duração da gravação (segundos)", 3, 10, 5)
    if st.button("🔴 Gravar e processar"):
        with st.spinner("A gravar..."):
            audio_path = record_audio(duration_seconds=duracao)
        st.audio(audio_path)
        processar(audio_path, engine)