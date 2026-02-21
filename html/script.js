/**
 * Patxi Carrera — Offroad Race NUI
 * Handles timer HUD, lobby panel, leaderboard, and notifications.
 */

// ============================================================
// DOM References (cached once)
// ============================================================

const DOM = {
    raceHud:        document.getElementById('race-hud'),
    timer:          document.getElementById('timer'),
    cpCurrent:      document.getElementById('cp-current'),
    cpTotal:        document.getElementById('cp-total'),
    progressFill:   document.getElementById('progress-fill'),
    lobbyPanel:     document.getElementById('lobby-panel'),
    lobbyTimer:     document.getElementById('lobby-timer'),
    lobbyPlayers:   document.getElementById('lobby-players'),
    leaderboard:    document.getElementById('leaderboard-panel'),
    lbList:         document.getElementById('lb-list'),
    notifications:  document.getElementById('notifications'),
};

// ============================================================
// Formatters
// ============================================================

/**
 * Format milliseconds to MM:SS
 * @param {number} ms
 * @returns {string}
 */
function formatMs(ms) {
    if (ms < 0) ms = 0;
    const total = Math.floor(ms / 1000);
    const min   = Math.floor(total / 60);
    const sec   = total % 60;
    return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
}

/**
 * Format seconds to MM:SS
 * @param {number} sec
 * @returns {string}
 */
function formatSec(sec) {
    const min = Math.floor(sec / 60);
    const s   = sec % 60;
    return `${String(min).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/**
 * Format milliseconds to readable finish time (e.g. "12m 34s")
 * @param {number} ms
 * @returns {string}
 */
function formatFinish(ms) {
    const total = Math.floor(ms / 1000);
    const min   = Math.floor(total / 60);
    const sec   = total % 60;
    return `${min}m ${String(sec).padStart(2, '0')}s`;
}

// ============================================================
// Notifications
// ============================================================

const NOTIF_DURATION = 3800;

/**
 * Show a toast notification
 * @param {string} msg
 * @param {'info'|'success'|'error'} type
 */
function showNotification(msg, type = 'info') {
    const el = document.createElement('div');
    el.className = `notif ${type}`;
    el.textContent = msg;
    DOM.notifications.appendChild(el);

    setTimeout(() => el.remove(), NOTIF_DURATION);
}

// ============================================================
// UI Handlers
// ============================================================

const handlers = {
    /**
     * Toggle race HUD visibility
     */
    toggleHUD(data) {
        DOM.raceHud.style.display = data.show ? 'block' : 'none';
    },

    /**
     * Update timer, checkpoint counter, and progress bar
     */
    updateTimer(data) {
        const { remaining, checkpoint, total } = data;

        DOM.timer.textContent = formatMs(remaining);

        // Color states
        DOM.timer.className = 'timer-display';
        if (remaining < 120_000) {
            DOM.timer.classList.add('danger');
        } else if (remaining < 300_000) {
            DOM.timer.classList.add('warning');
        }

        DOM.cpCurrent.textContent = checkpoint;
        DOM.cpTotal.textContent   = `/ ${total}`;

        const pct = ((checkpoint - 1) / total) * 100;
        DOM.progressFill.style.width = `${pct}%`;
    },

    /**
     * Toggle lobby panel and update player list
     */
    toggleLobby(data) {
        DOM.lobbyPanel.style.display = data.show ? 'block' : 'none';

        if (!data.show) return;

        DOM.lobbyTimer.textContent = formatSec(data.timeLeft);
        DOM.lobbyPlayers.innerHTML = '';

        if (data.players?.length) {
            const frag = document.createDocumentFragment();
            data.players.forEach((p, i) => {
                const li = document.createElement('li');
                li.innerHTML = `<span class="pos">${i + 1}</span> ${p.name}`;
                frag.appendChild(li);
            });
            DOM.lobbyPlayers.appendChild(frag);
        }
    },

    /**
     * Toggle and update the leaderboard
     */
    updateLeaderboard(data) {
        DOM.leaderboard.style.display = data.show ? 'block' : 'none';

        if (!data.show || !data.leaderboard) return;

        const MEDALS = ['🥇', '🥈', '🥉'];
        const frag   = document.createDocumentFragment();

        data.leaderboard.forEach((p, i) => {
            const li  = document.createElement('li');
            const pos = i < 3 ? MEDALS[i] : `${i + 1}.`;

            const status = p.finished
                ? `<span class="lb-finished">✓ ${formatFinish(p.finishTime)}</span>`
                : `<span class="lb-cp">CP ${p.checkpoint || 0}</span>`;

            li.innerHTML = `
                <span class="lb-pos">${pos}</span>
                <span class="lb-name">${p.name}</span>
                ${status}
            `;
            frag.appendChild(li);
        });

        DOM.lbList.innerHTML = '';
        DOM.lbList.appendChild(frag);
    },

    /**
     * Show a notification toast
     */
    notification(data) {
        showNotification(data.message, data.type);
    },
};

// ============================================================
// NUI Message Listener
// ============================================================

window.addEventListener('message', (event) => {
    const { action, ...data } = event.data;
    if (action && handlers[action]) {
        handlers[action](data);
    }
});
