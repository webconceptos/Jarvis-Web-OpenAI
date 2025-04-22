# 🧠 Jarvis Web OpenAI

Asistente de voz inteligente conectado a los modelos de OpenAI (GPT + Whisper), con síntesis de voz neural y despliegue completo en entorno web.

![Status](https://img.shields.io/badge/status-en%20desarrollo-blue)
![OpenAI](https://img.shields.io/badge/OpenAI-API-green)
![Docker](https://img.shields.io/badge/docker-ready-blue)

---

## 🚀 Características

- 🎤 Entrada por voz usando Whisper (transcripción local o API)
- 💬 Comunicación con modelos GPT de OpenAI
- 🗣️ Respuesta hablada con edge-tts y voz neural
- 🔐 Seguridad con variables de entorno (.env)
- 🌐 Interfaz web con micrófono y respuesta hablada
- 🐳 Despliegue fácil con Docker

---

## 📁 Estructura del Proyecto

```
jarvis-web-openai/
├── jarvis_backend/        # API FastAPI + lógica de conexión OpenAI
├── jarvis_web_v2/         # Interfaz web HTML/JS + micrófono
├── .env.example           # Variables de entorno necesarias
```

---

## 🔧 Requisitos

- Python 3.10+
- Node.js (opcional si deseas expandir el frontend)
- Cuenta en [OpenAI](https://platform.openai.com/)
- Clave API válida de OpenAI

---

## 🛠️ Instalación

1. Clona este repositorio:
```bash
git clone https://github.com/webconceptos/Jarvis-Web-OpenAI.git
cd Jarvis-Web-OpenAI
```

2. Copia el archivo `.env.example` y renómbralo a `.env`
```bash
cp .env.example .env
```

3. Instala dependencias:
```bash
cd jarvis_backend
pip install -r requirements.txt
```

4. Ejecuta el backend:
```bash
uvicorn app:app --reload --port 8000
```

---

## 🌐 Uso

1. Abre `jarvis_web_v2/index.html` en tu navegador
2. Presiona el botón de micrófono 🎤
3. Habla con Jarvis y escucha la respuesta

---

## 📦 Despliegue Docker (opcional)

Puedes crear un `Dockerfile` para el backend y servir el frontend con NGINX. Si lo necesitas, puedo ayudarte a generarlo.

---

## 📜 Licencia

MIT © [Web Conceptos](https://github.com/webconceptos)

---

## 📬 Contacto

📧 fgarcia@webconceptos.com  
🌐 https://webconceptos.com  
📞 +51 985 670 257
