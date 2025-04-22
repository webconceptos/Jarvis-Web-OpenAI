# Jarvis 2.3 Web – Asistente de Voz Técnico

Bienvenido a Jarvis 2.3, tu asistente técnico conversacional con entrada por voz o texto, respuesta con inteligencia artificial y salida hablada usando voz neural.

## Contenido del proyecto

```
jarvis_web_v2/
├── index.html
├── estilos.css
├── script.js
├── fondo_jarvis.png
├── logo.png

jarvis_backend/
├── app.py
├── requirements.txt

README.md
```

## Cómo ejecutar

### Backend (FastAPI)

```bash
cd jarvis_backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --reload
```

Asegúrate de tener tu API Key de OpenAI en `app.py`.

### Frontend

Abre `index.html` o usa servidor local:

```bash
cd jarvis_web_v2
python -m http.server
```

¡Listo para usar!
