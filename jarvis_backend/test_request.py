
import requests

BASE_URL = "http://127.0.0.1:8000"

def test_chat():
    payload = {
        "message": "Hola, ¿qué puedes hacer?",
        "history": ["Hola", "¡Hola! ¿En qué te ayudo hoy?"]
    }
    response = requests.post(f"{BASE_URL}/chat", json=payload)
    print("🔁 /chat respuesta:")
    print(response.status_code, response.json())

def test_transcribe():
    with open("entrada.wav", "rb") as f:
        files = {"file": ("entrada.wav", f, "audio/wav")}
        response = requests.post(f"{BASE_URL}/transcribe", files=files)
        print("🔁 /transcribe respuesta:")
        print(response.status_code, response.json())

def test_speak():
    # Texto que se desea convertir en voz
    texto = "Hola, soy Jarvis y estoy listo para ayudarte."

    # CORRECTO: enviar como JSON
    speak_response = requests.post("http://localhost:8000/speak", json={"text": texto})

    if speak_response.status_code == 200:
        with open("respuesta.mp3", "wb") as f:
            f.write(speak_response.content)
        print("✅ Audio guardado como 'respuesta.mp3'")
    else:
        print("❌ Error al generar audio:", speak_response.text)

if __name__ == "__main__":
    test_chat()
    # test_transcribe()  # Descomenta si tienes entrada.wav
    test_speak()
