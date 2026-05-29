const API_URL = "http://localhost:2000";

let historial = [];
let ultimoAudio = null;
let mediaRecorder = null;
let audioChunks = [];

// ============================
// ELEMENTOS UI
// ============================

const messages = document.getElementById("messages");
const input = document.getElementById("input");

const btnEnviar = document.getElementById("btnEnviar");
const btnReset = document.getElementById("btnReset");
const btnRepeat = document.getElementById("btnRepeat");

const btnGrabar = document.getElementById("btnGrabar");
const btnDetener = document.getElementById("btnDetener");

// ============================
// MENSAJES
// ============================

function agregarMensaje(texto, clase) {

    const div = document.createElement("div");

    div.className = clase;
    div.textContent = texto;

    messages.appendChild(div);

    messages.scrollTop = messages.scrollHeight;
}

function mostrarPensando(mostrar = true) {

    const indicador =
        document.getElementById("typingIndicator");

    if (!indicador) return;

    indicador.style.display =
        mostrar ? "block" : "none";
}

// ============================
// OPENAI TTS
// ============================

async function reproducirVoz(texto) {

    try {

        console.log("🔊 Generando audio...");

        const response = await fetch(
            `${API_URL}/speak`,
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    text: texto
                })
            }
        );

        if (!response.ok) {

            const error =
                await response.text();

            console.error(error);

            throw new Error(
                `TTS Error ${response.status}`
            );
        }

        const blob =
            await response.blob();

        const audioUrl =
            URL.createObjectURL(blob);

        ultimoAudio =
            new Audio(audioUrl);

        await ultimoAudio.play();

    } catch (error) {

        console.error(
            "❌ Error reproduciendo voz:",
            error
        );
    }
}

// ============================
// CHAT
// ============================

async function enviarMensaje() {

    const mensaje =
        input.value.trim();

    if (!mensaje) return;

    agregarMensaje(
        mensaje,
        "msg-user"
    );

    input.value = "";

    mostrarPensando(true);

    try {

        const persona =
            document.getElementById("personaSelect")?.value
            || "jarvis";

        const response =
            await fetch(
                `${API_URL}/chat`,
                {
                    method: "POST",
                    headers: {
                        "Content-Type":
                            "application/json"
                    },
                    body: JSON.stringify({
                        message: mensaje,
                        history: historial,
                        persona: persona
                    })
                }
            );

        const data =
            await response.json();

        mostrarPensando(false);

        const respuesta =
            data.reply ||
            "⚠️ Sin respuesta.";

        agregarMensaje(
            respuesta,
            "msg-bot"
        );

        historial.push(mensaje);
        historial.push(respuesta);

        await reproducirVoz(respuesta);

    } catch (error) {

        mostrarPensando(false);

        console.error(error);

        agregarMensaje(
            "❌ Error al comunicarse con Jarvis.",
            "msg-error"
        );
    }
}

// ============================
// DIAGNÓSTICO
// ============================

async function probarCORS() {

    try {

        const response =
            await fetch(
                `${API_URL}/health`
            );

        const data =
            await response.json();

        alert(
            "✅ Backend conectado\n\n" +
            JSON.stringify(
                data,
                null,
                2
            )
        );

        const statusBar =
            document.getElementById(
                "statusBar"
            );

        if (statusBar) {

            statusBar.innerHTML =
                "🟢 Conectado";
        }

    } catch (error) {

        alert(
            "❌ No se pudo conectar al backend."
        );

        const statusBar =
            document.getElementById(
                "statusBar"
            );

        if (statusBar) {

            statusBar.innerHTML =
                "🔴 Desconectado";
        }

        console.error(error);
    }
}

// ============================
// WHISPER
// ============================

async function iniciarGrabacion() {

    try {

        const stream =
            await navigator
                .mediaDevices
                .getUserMedia({
                    audio: true
                });

        mediaRecorder =
            new MediaRecorder(stream);

        audioChunks = [];

        mediaRecorder.ondataavailable =
            (event) => {

                audioChunks.push(
                    event.data
                );
            };

        mediaRecorder.onstop =
            async () => {

                const audioBlob =
                    new Blob(
                        audioChunks,
                        {
                            type:
                                "audio/webm"
                        }
                    );

                const formData =
                    new FormData();

                formData.append(
                    "file",
                    audioBlob,
                    "audio.webm"
                );

                try {

                    const response =
                        await fetch(
                            `${API_URL}/transcribe`,
                            {
                                method:
                                    "POST",
                                body:
                                    formData
                            }
                        );

                    const data =
                        await response.json();

                    input.value =
                        data.text || "";

                } catch (error) {

                    console.error(
                        error
                    );
                }
            };

        mediaRecorder.start();

        btnGrabar.disabled = true;
        btnDetener.disabled = false;

    } catch (error) {

        console.error(error);
    }
}

function detenerGrabacion() {

    if (!mediaRecorder) return;

    mediaRecorder.stop();

    btnGrabar.disabled = false;
    btnDetener.disabled = true;
}

// ============================
// BOTONES
// ============================

btnEnviar?.addEventListener(
    "click",
    enviarMensaje
);

input?.addEventListener(
    "keydown",
    (event) => {

        if (
            event.key === "Enter"
        ) {
            enviarMensaje();
        }
    }
);

btnReset?.addEventListener(
    "click",
    () => {

        historial = [];

        messages.innerHTML = "";

        input.value = "";
    }
);

btnRepeat?.addEventListener(
    "click",
    () => {

        if (!ultimoAudio) return;

        ultimoAudio.currentTime = 0;

        ultimoAudio.play();
    }
);

btnGrabar?.addEventListener(
    "click",
    iniciarGrabacion
);

btnDetener?.addEventListener(
    "click",
    detenerGrabacion
);

// ============================
// INICIALIZACIÓN
// ============================

window.probarCORS =
    probarCORS;

document.addEventListener(
    "DOMContentLoaded",
    () => {

        console.log(
            "🤖 Jarvis Web 2.0 iniciado"
        );

        probarCORS();
    }
);