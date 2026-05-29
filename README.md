# 🤖 Jarvis Web 2.0

> Asistente conversacional multimodal desarrollado por Web Conceptos, impulsado por OpenAI GPT-4o-mini, Whisper y OpenAI TTS, desplegado mediante Docker y accesible desde una interfaz web moderna.

![Status](https://img.shields.io/badge/status-estable-success)
![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o--mini-green)
![OpenAI TTS](https://img.shields.io/badge/TTS-OpenAI-blue)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688)
![License](https://img.shields.io/badge/license-MIT-orange)

---

# 📌 Descripción

Jarvis Web 2.0 es una plataforma de inteligencia artificial conversacional que permite interactuar mediante texto y voz utilizando modelos avanzados de OpenAI.

## Componentes principales

* GPT-4o-mini para generación de respuestas.
* Whisper para reconocimiento de voz.
* GPT-4o-mini-TTS para síntesis de voz.
* Frontend Web moderno.
* Backend FastAPI.
* Docker Compose.
* Arquitectura preparada para RAG.

---

# 🚀 Características

## 💬 Inteligencia Conversacional

* GPT-4o-mini.
* Conversación contextual.
* Personalidades configurables.
* Arquitectura preparada para memoria persistente.

## 🎤 Voz a Texto (Speech-to-Text)

* Grabación desde navegador.
* Integración con Whisper.
* Conversión automática de voz a texto.
* Compatible con micrófono local.

## 🔊 Texto a Voz (Text-to-Speech)

* OpenAI GPT-4o-mini-TTS.
* Generación de audio MP3.
* Reproducción automática.
* Repetición del último audio generado.
* Eliminación de dependencias Edge-TTS.

## 🌐 Interfaz Web

* Chat en tiempo real.
* Entrada por teclado.
* Entrada por voz.
* Selector de personalidad.
* Diagnóstico de conectividad.
* Reinicio de conversación.

## 🐳 Contenedorización

* Docker Compose.
* Backend FastAPI.
* Frontend Nginx.
* Health Checks.
* Variables de entorno seguras.

---

# 🏗️ Arquitectura

```text
Navegador
    │
    ▼
Frontend Nginx (Puerto 88)
    │
    ▼
Backend FastAPI (Puerto 2000)
    │
 ┌──┴─────────────┐
 ▼                ▼
GPT-4o-mini    Whisper
     │
     ▼
GPT-4o-mini-TTS
     │
     ▼
Audio MP3
```

---

# 📁 Estructura del Proyecto

```text
JarvisWeb_OpenAI/
│
├── docker-compose.yml
├── .env
├── .env.example
│
├── jarvis_backend/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── ...
│
├── jarvis_frontend/
│   ├── index.html
│   ├── estilos.css
│   ├── script.js
│   ├── LogoWCBot.png
│   ├── Dockerfile
│   └── ...
│
└── README.md
```

---

# ⚙️ Configuración

## Variables de entorno

Crear archivo `.env`

```env
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

⚠️ Nunca subir este archivo al repositorio.

---

# 🚀 Despliegue

## Construir contenedores

```bash
docker compose build --no-cache
```

## Levantar servicios

```bash
docker compose up -d
```

## Verificar estado

```bash
docker ps
```

Resultado esperado:

```text
jarvis_frontend
jarvis_backend
```

---

# 🌐 Acceso

## Frontend

```text
http://localhost:88
```

## Backend

```text
http://localhost:2000
```

## Health Check

```text
http://localhost:2000/health
```

---

# 🎯 Personalidades

## 🤖 Jarvis

Asistente técnico general.

## 👩 AndyIA

Especialista en:

* Denuncias ciudadanas.
* Control gubernamental.
* Normativa institucional.

## 📊 Especialista CGR

Orientado a:

* Ley N° 27785.
* Invierte.pe.
* Gestión de inversiones.
* Proyecto BID 3.

## 🇨🇴 Salomé Paisa

Personalidad conversacional amigable.

---

# 🔐 Seguridad

Agregar al `.gitignore`:

```gitignore
.env
.env.*
*.mp3
__pycache__/
*.pyc
```

Nunca almacenar:

* API Keys
* Tokens
* Credenciales

dentro del código fuente o docker-compose.

---

# 🛣️ Roadmap

## Versión 2.1

* Memoria persistente.
* Historial de conversaciones.
* Gestión de usuarios.

## Versión 2.2

* RAG documental.
* ChromaDB.
* Búsqueda semántica.

## Versión 3.0

* AndyIA.
* WhatsApp.
* Telegram.
* Microsoft Teams.
* Base de conocimiento institucional.

---

# 📈 Estado del Proyecto

## Implementado

* GPT-4o-mini.
* Whisper.
* OpenAI TTS.
* FastAPI.
* Docker Compose.
* Frontend Web.
* Selector de personalidades.

## Próximamente

* Memoria persistente.
* RAG.
* Multiusuario.
* Integraciones empresariales.

---

# 👨‍💻 Autor

**Fernando García Atúncar**

Web Conceptos EIRL

📧 [fgarcia@webconceptos.com](mailto:fgarcia@webconceptos.com)

🌐 https://webconceptos.com

🇵🇪 Lima - Perú

---

# 📄 Licencia

MIT License

Copyright (c) Web Conceptos EIRL

