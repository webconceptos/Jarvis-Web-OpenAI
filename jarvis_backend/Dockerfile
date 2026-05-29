FROM python:3.11-slim

# Evitar prompts y tzdata interactivo
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# Dependencias del sistema mínimas (curl solo si lo usas)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg curl build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Pre-descarga del modelo whisper (opcional)
ARG WHISPER_MODEL=base
RUN python - <<'PY'
import whisper, os
m = os.environ.get("WHISPER_MODEL", "base")
print(f"[Precache] Descargando modelo '{m}' ...")
whisper.load_model(m)
print("[Precache] Listo.")
PY

# Copia del código
COPY . .

# Crear usuario no root
RUN useradd -m appuser && chown -R appuser /app
# Crear /cache y asignarle permisos al usuario no root
RUN mkdir -p /cache && chown -R appuser:appuser /cache

USER appuser

EXPOSE 2000
# Healthcheck interno: servidor responde?
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD python -c "import socket; s=socket.socket(); \
  s.settimeout(3); s.connect(('127.0.0.1',2000)); s.close()"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "2000"]
