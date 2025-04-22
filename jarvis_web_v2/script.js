const mensajes = document.getElementById("messages");
const entrada = document.getElementById("input");
const titulo = document.getElementById("titulo");
let historial = [];
let nombreUsuario = localStorage.getItem("usuario") || null;

// Detecta Enter para enviar
entrada.addEventListener("keydown", (e) => {
    if (e.key === "Enter") enviarTexto();
  });
  
  // Botón enviar
  document.getElementById("btnEnviar").addEventListener("click", enviarTexto);
  
  // Botón reiniciar
  document.getElementById("btnReset").addEventListener("click", () => {
    historial = [];
    localStorage.removeItem("usuario");
    nombreUsuario = null;
    mensajes.innerHTML = "";
    titulo.innerText = "🤖 WCBot 1.0";
    iniciarSaludo();
  });

// Agrega un mensaje visual
function agregarMensaje(texto, clase) {
  const burbuja = document.createElement("div");
  burbuja.className = "bubble " + clase;
  burbuja.innerText = texto;
  mensajes.appendChild(burbuja);
  mensajes.scrollTop = mensajes.scrollHeight;
}

async function enviarTexto() {
  
  const mensaje = entrada.value.trim();
  if (!mensaje) return;
  agregarMensaje(mensaje, "user");
  historial.push(mensaje);
  entrada.value = "";

  if (!nombreUsuario) {
    nombreUsuario = extraerNombre(mensaje);
    localStorage.setItem("usuario", nombreUsuario);
    titulo.innerText = `Hola, ${nombreUsuario}`;
    const saludo = `Encantado de conocerte, ${nombreUsuario}. ¿En qué puedo ayudarte hoy?`;
    agregarMensaje(saludo, "jarvis");
    reproducirVoz(saludo);
    historial.push(saludo);
    return;
  }

  agregarMensaje("🧠 Pensando...", "system");
  try {
    const res = await fetch("http://localhost:8000/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: mensaje, history: historial })
      });
    
    const data = await res.json();
    let respuesta = data.reply;

    if (respuesta.length < 80 && !respuesta.includes(nombreUsuario)) {
    respuesta = `${nombreUsuario}, ${respuesta.charAt(0).toLowerCase() + respuesta.slice(1)}`;
    }

    
    // Elimina mensaje de sistema
    document.querySelector(".system")?.remove();
       
    agregarMensaje(respuesta, "jarvis");
    historial.push(respuesta);
    reproducirVoz(respuesta);    
  } catch (error) {
    agregarMensaje("❌ Hubo un problema al generar la respuesta.", "system");
  }

}

function extraerNombre(texto) {
  texto = texto.toLowerCase();
  const match = texto.match(/(?:soy|me llamo|mi nombre es)\s+(\w+)/);
  return match ? match[1].charAt(0).toUpperCase() + match[1].slice(1) : "humano";
}

async function usarMicrofono() {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const mediaRecorder = new MediaRecorder(stream);
  const chunks = [];

  mediaRecorder.ondataavailable = e => chunks.push(e.data);
  mediaRecorder.onstop = async () => {
    const blob = new Blob(chunks, { type: "audio/wav" });
    const formData = new FormData();
    formData.append("file", blob, "entrada.wav");

    const res = await fetch("http://localhost:8000/transcribe", {
      method: "POST",
      body: formData
    });

    const data = await res.json();
    entrada.value = data.text || "";
    enviarTexto();
  };

  mediaRecorder.start();
  setTimeout(() => mediaRecorder.stop(), 5000);
}

async function reproducirVoz(texto) {
    agregarMensaje("🔊 Reproduciendo...", "system");

    try {
        const res = await fetch("http://localhost:8000/speak", {
            method: "POST",
            headers: {
              "Content-Type": "application/json"
            },
            body: JSON.stringify({ text: texto })
          });
        
        if (res.ok) {
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        const audio = new Audio(url);
        audio.play();
        } else {
        console.error("❌ Error al reproducir voz");
        }        
    } catch (err) {
        console.error("❌ Error al reproducir voz", err);
    } finally {
        document.querySelector(".system")?.remove();
    }

  }


function reiniciarChat() {
  historial = [];
  localStorage.removeItem("usuario");
  nombreUsuario = null;
  mensajes.innerHTML = "";
  document.getElementById("input").value = "";
  const saludo = "Hola, ¿cómo te llamas?";
  agregarMensaje(saludo, "jarvis");
  reproducirVoz(saludo);
}

// Mensaje inicial
function iniciarSaludo() {
    if (!nombreUsuario) {
      const mensaje = "Hola, ¿cómo te llamas?";
      agregarMensaje(mensaje, "jarvis");
      reproducirVoz(mensaje);
    } else {
      titulo.innerText = `🤖 WCBot - Hola, ${nombreUsuario}`;
    }
  }
  
  window.onload = iniciarSaludo;

