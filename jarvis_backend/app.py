from fastapi import FastAPI, UploadFile, Form
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Body

from pydantic import BaseModel
from openai import OpenAI

import whisper
import edge_tts
import tempfile
import os
import asyncio



# ================= CONFIGURACIÓN =================
# 🔐 Tu clave API KEY
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
IDIOMA = "es"
modelo_asistente = whisper.load_model("base")

# ================= INICIALIZACIÓN =================
app = FastAPI()

# CORS para integración con frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================= MODELOS DE DATOS =================
class ChatInput(BaseModel):
    message: str
    history: list[str] = []

# ================= ENDPOINTS =================

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile):
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp:
            temp.write(await file.read())
            temp_path = temp.name

        resultado = modelo_asistente.transcribe(temp_path, language=IDIOMA)
        os.remove(temp_path)
        return {"text": resultado["text"].strip()}
    except Exception as e:
        print("❌ ERROR EN /transcribe:", e)
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/chat")
async def chat(input_data: ChatInput):
    try:
        messages = [
            {"role": "system", "content": "Eres Jarvis, un asistente técnico claro, conciso y educado. Responde siempre en español."}
        ]
        for i in range(0, len(input_data.history), 2):
            messages.append({"role": "user", "content": input_data.history[i]})
            if i + 1 < len(input_data.history):
                messages.append({"role": "assistant", "content": input_data.history[i + 1]})
        messages.append({"role": "user", "content": input_data.message})

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=messages,
            temperature=0.4,
            max_tokens=200,
            top_p=0.9
        )
        respuesta = response.choices[0].message.content.strip()
        return {"reply": respuesta}
    except Exception as e:
        print("❌ ERROR EN /chat:", e)
        return JSONResponse(content={"error": str(e)}, status_code=500)

class SpeakInput(BaseModel):
    text: str

@app.post("/speak")
async def speak(payload: SpeakInput):
    final_text = payload.text.strip()

    if not final_text:
        return JSONResponse(content={"error": "No se recibió texto válido."}, status_code=400)

    try:
        print("🗣 Texto recibido:", final_text)  # 👈 Agrega esto para confirmar entrada
        
        audio_path = tempfile.NamedTemporaryFile(delete=False, suffix=".mp3").name
        print("Ruta del audio:", audio_path)  
        communicate = edge_tts.Communicate(final_text, voice="es-MX-DaliaNeural")

        await communicate.save(audio_path)

        #return FileResponse(audio_path, media_type="audio/mpeg", filename="respuesta.mp3")
        # Enviar y eliminar archivo
        def cleanup_and_stream():
            with open(audio_path, "rb") as f:
                yield from f
            os.remove(audio_path)  # ✅ Limpieza inmediata

        return StreamingResponse(cleanup_and_stream(), media_type="audio/mpeg")        
    
    except Exception as e:
        print("❌ ERROR EN /speak:", e)
        return JSONResponse(content={"error": str(e)}, status_code=500)
