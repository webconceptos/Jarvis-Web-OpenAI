import asyncio
import edge_tts

async def main():
    texto = "Hola, esto es una prueba de voz generada con Edge TTS."
    communicate = edge_tts.Communicate(text=texto, voice="es-MX-DaliaNeural")
    await communicate.save("prueba.mp3")
    print("✅ Archivo generado: prueba.mp3")

asyncio.run(main())
