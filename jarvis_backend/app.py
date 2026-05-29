from fastapi import FastAPI, UploadFile, HTTPException
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from openai import OpenAI
from pydantic import BaseModel, Field

import whisper
import tempfile
import os
import asyncio
import re
import threading

import random

modelo_asistente = None
_whisper_lock = threading.Lock()

class SpeakInput(BaseModel):
    text: str = Field(..., description="Texto a sintetizar")
    voice: str | None = Field(None, description="Nombre corto de la voz Edge‑TTS")
    
    # 🔊 Nuevos parámetros opcionales
    rate: str | None = Field(
        None, 
        description='Velocidad SSML (ej. "+10%", "-25%"). Rango: -100 % a +200 %'
    )
    style: str | None = Field(
        None, 
        description='Estilo (ej. "cheerful", "sad"). Solo si la voz lo soporta'
    )
    style_degree: float | None = Field(
        None, ge=0.01, le=2.0,
        description="Intensidad del estilo (0.01–2.0). Por defecto 1.0"
    )
    pitch: str | None = None     # ej. "+2Hz"  "-4Hz"
    volume: str | None = None    # ej. "+2dB"

class SpeakMin(BaseModel):
    text: str
    rate: str | None = None
    volume: str | None = None
    voice: str | None = None

class SpeakAdv(BaseModel):
    text: str
    voice: str | None = None
    rate: str | None = None
    volume: str | None = None
    pitch: str | None = None
    style: str | None = None
    style_degree: float | None = Field(None, ge=0.01, le=2.0)

def get_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY no configurada dentro del contenedor.")
    return OpenAI(api_key=api_key)

#================= Voces disponibles ============

def generar_prompt_paisa(intensidad="medio"):
    if intensidad == "suave":
        return (
            "Eres Salomé, una asistente técnica colombiana con voz femenina amable y cálida. "
            "Puedes usar algunas expresiones paisas como 'de una', 'parce', 'pues vea', pero sin exagerar."
        )
    elif intensidad == "fuerte":
        return (
            "Eres Salomé, una asistente técnica colombiana con acento paisa MUY marcado. "
            "Hablas como una paisa de pura cepa, usando expresiones típicas en todo momento como '¿Quiubo pues, mi llave?', 'una chimba', 'parce', 'pues vea', 'me avisa pues', etc. "
            "Tu estilo es efusivo, carismático, y con sabor a Medellín en cada palabra."
        )
    elif intensidad == "coqueto":
        return (
            "Eres Salomé, una asistente técnica colombiana con voz femenina y estilo coqueto paisa. "
            "Hablas con expresiones juguetonas, pícaras y amables, como 'Hola pues, bombón', 'mi cielo', '¿me vas a hacer repetir?', 'ay, qué ternura'. "
            "Tu tono es encantador, cariñoso y siempre con chispa femenina." 
        )
    else:
        return (
            "Eres Salomé, una asistente técnica colombiana con acento paisa. "
            "Hablas con expresiones típicas de Medellín como '¿Quiubo pues, mi llave?', 'de una', 'parce', 'pues vea', etc. "
            "Siempre ayudas con una actitud cálida, amigable y con el toque paisa que alegra el día. Sé técnica pero con sabor." 
        )

EXPRESIONES_PAISAS = {
    "saludo": {
        "suave": ["Hola, ¿cómo estás?"],
        "medio": ["¿Quiubo pues, mi llave?", "Hola pues, ¿cómo vamos?"],
        "fuerte": ["¿Qué más pues, mi amor?", "¡Ey! Bien o qué, mi ciela?"],
        "coqueto": ["Hola pues, bombón.", "¿Cómo amanece mi ciela?", "¡Holaaa, qué ternura verte por aquí!"]
    },
    "confirmacion": {
        "suave": ["Listo, ya está."],
        "medio": ["De una, mi amor.", "Eso está hecho, mi cielo."],
        "fuerte": ["Claro que sí, eso está más que listo, mi reina.", "¡Uy, mamita! Eso está hecho pues, una chimba."],
        "coqueto": ["Por ti, lo que sea... 😏", "Obvio mi amor, ya mismito.", "Todo listo, mi ciela. 💖"]
    },
    "despedida": {
        "suave": ["Estamos en contacto."],
        "medio": ["Listo pues, hablamos.", "Me avisas si necesitas algo más, ¿oyó?"],
        "fuerte": ["Estamos pues a la orden, mi reina, no se me pierda.", "Con gusto, mi ciela. Que esté bien pues, ¡una chimba!"],
        "coqueto": ["No te me pierdas, ¿sí? 😘", "Un abracito, mi cielo. 💕", "Hasta pronto, bombón. 🥰"]
    },
    "espera": {
        "suave": ["Un momento por favor..."],
        "medio": ["Espérame y verás lo que te tengo...", "Déjame reviso pues..."],
        "fuerte": ["Aguántame un momentico, que eso va volando, mi amor.", "Espérate pues, que ya te lo resuelvo en un dos por tres."],
        "coqueto": ["Ay, dame un segundito que esto va a estar divino. 😌", "Ya mismo te doy lo que necesitas, corazón."]
    }
}

def detectar_tipo_respuesta(texto):
    texto = texto.lower()
    if any(palabra in texto for palabra in ["hola", "buenas", "qué tal"]):
        return "saludo"
    if any(palabra in texto for palabra in ["ok", "hecho", "gracias", "correcto"]):
        return "confirmacion"
    if any(palabra in texto for palabra in ["adiós", "nos vemos", "chau"]):
        return "despedida"
    if any(palabra in texto for palabra in ["espera", "momento", "cargando"]):
        return "espera"
    return None

def paisa_talkify(texto, intensidad="medio"):
    tipo = detectar_tipo_respuesta(texto)
    lista = EXPRESIONES_PAISAS.get(tipo, EXPRESIONES_PAISAS["confirmacion"])
    intro = random.choice(lista[intensidad]) if intensidad in lista else random.choice(lista["medio"])

    voz_params = {}
    if intensidad == "coqueto":
        voz_params = {"pitch": "+4Hz", "rate": "+8%", "volume": "+0%"}
    elif intensidad == "fuerte":
        voz_params = {"pitch": "+2Hz", "rate": "+4%", "volume": "+2%"}
    else:
        voz_params = {"pitch": "+0Hz", "rate": "+0%", "volume": "+0%"}

    return {
        "texto": f"{intro} {texto}",
        "voz_params": voz_params
    }

# ================= CONFIGURACIÓN =================
IDIOMA = "es"

# ================= INICIALIZACIÓN =================
app = FastAPI()

# CORS para integración con frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:88"
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)
# ================= MODELOS DE DATOS =================
class ChatInput(BaseModel):
    message: str
    history: list[str] = []
    persona: str | None = "jarvis"

# ================= ENDPOINTS =================

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile):
    global modelo_asistente
    if modelo_asistente is None:
        with _whisper_lock:
            if modelo_asistente is None:
                print("⏳ Cargando modelo Whisper base (lazy)…")
                import whisper
                modelo_asistente = whisper.load_model("base")
                print("✅ Whisper listo")
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp:
            temp.write(await file.read())
            temp_path = temp.name

        resultado = modelo_asistente.transcribe(temp_path, language=IDIOMA)
        os.remove(temp_path)
        return {"text": resultado["text"].strip()}
    except Exception as e:
        import traceback
        traceback.print_exc()
        print("❌ ERROR EN /transcribe:", e)
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/chat")
async def chat(input_data: ChatInput):
    try:
        #messages = [
        #    {"role": "system", "content": "Eres Jarvis, un asistente técnico claro, conciso y educado. Responde siempre en español."}
        #]

        messages = [
            {
                "role": "system",
                "content": generar_prompt_paisa("fuerte")
            }
        ]        
        for i in range(0, len(input_data.history), 2):
            messages.append({"role": "user", "content": input_data.history[i]})
            if i + 1 < len(input_data.history):
                messages.append({"role": "assistant", "content": input_data.history[i + 1]})
        messages.append({"role": "user", "content": input_data.message})

        client = get_openai_client()
        response = client.chat.completions.create(
            #model="gpt-3.5-turbo",
            model="gpt-4o-mini",
            messages=messages,
            temperature=0.4,
            max_tokens=200,
            top_p=0.9
        )
        respuesta = response.choices[0].message.content.strip()
        data = paisa_talkify(respuesta, intensidad="coqueto")
        texto_final = data["texto"]
        tts_params = data["voz_params"] 
        return {
        "reply": texto_final,
        "tts": tts_params
        }       
        #respuesta = paisa_talkify(respuesta)
        #return {"reply": respuesta}
    except Exception as e:
        print("❌ ERROR EN /chat:", e)
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.post("/speak")
async def speak(payload: SpeakInput):
    final_text = payload.text.strip()
    if not final_text:
        return JSONResponse(
            content={"error": "No se recibió texto válido."},
            status_code=400
        )
    try:
        client = get_openai_client()
        speech = client.audio.speech.create(
            model="gpt-4o-mini-tts",
            voice="sage",
            input=final_text,
            instructions="Habla con acento paisa colombiano, tono cálido y alegre.",
        )
        audio_path = tempfile.NamedTemporaryFile(
            delete=False,
            suffix=".mp3"
        ).name
        with open(audio_path, "wb") as f:
            f.write(speech.content)

        def cleanup_and_stream():
            with open(audio_path, "rb") as f:
                yield from f
            try:
                os.remove(audio_path)
            except:
                pass
        return StreamingResponse(
            cleanup_and_stream(),
            media_type="audio/mpeg"
        )
    except Exception as e:
        print("❌ ERROR OPENAI TTS:", e)
        return JSONResponse(
            content={"error": str(e)},
            status_code=500
        )

@app.get("/health")
def health():
    return {
        "status": "ok"
    }
