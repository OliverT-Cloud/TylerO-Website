//Enter Screen
const enterScreen = document.getElementById("enterScreen");
const enterText = document.getElementById("enterText");
const audio = document.getElementById("music");
const buttons = document.querySelectorAll(".playback-controls button");
const progress = document.querySelector(".progress");

if (enterScreen && enterText) {
    document.body.classList.add("no-scroll");
    enterText.onclick = function() {
        if (audio) {
            audio.play().catch(() => {});
        }
        if (buttons.length > 1) {
            buttons[1].textContent = "⏸";
        }
        document.body.classList.remove("no-scroll");
        enterScreen.style.opacity = "0";
        setTimeout(function() {
            enterScreen.style.display = "none";
        }, 600);
    };
}

// Typewriter effect for header
const headerElement = document.getElementById("Intro-Header") || document.querySelector(".typewriter");
const headerText = headerElement ? (headerElement.dataset.text || headerElement.textContent.trim()) : "";
let currentCharacterIndex = 0;
let isDeleting = false;
function typewriterEffect() {
    if (!headerElement) {
        return;
    }
    if (isDeleting) {
        currentCharacterIndex--;
    } else {
        currentCharacterIndex++;
    }
    headerElement.innerHTML = headerText.substring(0, currentCharacterIndex) + '<span class="blinking-cursor">|</span>';
    let delayInMilliseconds = isDeleting ? 50 : 100;
    if (!isDeleting && currentCharacterIndex === headerText.length) {
        delayInMilliseconds = 2500;
        isDeleting = true;
    } else if (isDeleting && currentCharacterIndex <= 0) {
        delayInMilliseconds = 500;
        isDeleting = false;
        currentCharacterIndex = 0;
    }
    setTimeout(typewriterEffect, delayInMilliseconds);
}

typewriterEffect();

//Music Player Stuff
if (audio) {
    audio.volume = 0.06;
    if (buttons.length > 1) {
        buttons[1].onclick = function() {
            if (audio.paused) {
                audio.play().catch(() => {});
                buttons[1].textContent = "⏸";
            } else {
                audio.pause();
                buttons[1].textContent = "▶";
            }
        };
    }
    audio.ontimeupdate = function() {
        if (audio.duration && progress) {
            progress.style.width =
                (audio.currentTime / audio.duration) * 100 + "%";
        }
    };
    audio.onended = function() {
        if (buttons.length > 1) {
            buttons[1].textContent = "▶";
        }
    };
}

//lua Loading
document.querySelectorAll("[data-script]").forEach(function(code) {
    fetch("../scripts/" + code.dataset.script)
        .then(function(response) {
            return response.text();
        })
        .then(function(script) {
            code.textContent = script;
        });
});

function copyScript(button) {
    const code = button.parentElement.nextElementSibling.textContent;

    navigator.clipboard.writeText(code);

    button.textContent = "Copied!";

    setTimeout(function() {
        button.textContent = "Copy";
    }, 1500);
}

//Discord Status Stuff
const discordId = "342331717216108545";
const socket = new WebSocket("wss://api.lanyard.rest/socket");

socket.onmessage = function(event) {
    const message = JSON.parse(event.data);

    if (message.op === 1) {
        socket.send(JSON.stringify({
            op: 2,
            d: {
                subscribe_to_ids: [discordId]
            }
        }));

        setInterval(function() {
            socket.send(JSON.stringify({
                op: 3
            }));
        }, message.d.heartbeat_interval);
    }

    if (message.op === 0 &&
        (message.t === "INIT_STATE" || message.t === "PRESENCE_UPDATE")) {

        const data = message.t === "INIT_STATE"
            ? message.d[discordId]
            : message.d;

        if (!data) return;

        const user = data.discord_user;
        const status = data.discord_status;
        const activities = data.activities;
        const guild = user.primary_guild;

        document.getElementById("discord-avatar").src =
            user.avatar
                ? "https://cdn.discordapp.com/avatars/" + discordId + "/" + user.avatar + ".png?size=128"
                : "https://cdn.discordapp.com/embed/avatars/0.png";

        document.getElementById("discord-name").textContent =
            user.global_name || user.username;

        if (guild) {
            document.getElementById("discord-tag").textContent =
                guild.tag || "";
        } else {
            document.getElementById("discord-tag").textContent = "";
        }

        const customStatus = activities.find(function(activity) {
            return activity.type === 4;
        });

        document.getElementById("discord-custom-status").textContent =
            customStatus
                ? customStatus.state
                : "No custom status";

        document.getElementById("discord-status").textContent =
            "Status: " + status;

        document.getElementById("status-dot").className =
            "status-dot status-" + status;

        const activity = activities.find(function(activity) {
            return activity.type === 0;
        });

        document.getElementById("discord-activity").textContent =
            activity
                ? "Playing " + activity.name
                : "No current activity";
    }
};

socket.onclose = function() {
    setTimeout(function() {
        location.reload();
    }, 5000);
};

//view counter
async function updateVisitCount() {
    const counter = document.getElementById("visit-count");

    if (!counter) return;

    try {
        const response = await fetch("/api/visit", {
            method: "POST",
            cache: "no-store"
        });

        const data = await response.json();
        const visits = Number(data.visits);

        counter.textContent =
            visits >= 1000000 ? (visits / 1000000).toFixed(visits >= 10000000 ? 0 : 1).replace(".0", "") + "M" :
            visits >= 1000 ? (visits / 1000).toFixed(visits >= 10000 ? 0 : 1).replace(".0", "") + "K" :
            visits;
    } catch {
        counter.textContent = "—";
    }
}
updateVisitCount();
