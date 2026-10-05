// ==============================================================================
// Nothing Essential Sync - WebUI Logic
// Official KernelSU / APatch / MMRL Async Callback Bridge
// ==============================================================================

const CONFIG_PATH = "/data/adb/essential-sync/config.env";
const STATE_PATH = "/data/adb/essential-sync/last_sync_time.txt";
const LOG_PATH = "/data/adb/essential-sync/sync.log";
const SYNC_SCRIPT = "/data/adb/essential-sync/sync.sh";

let callbackCounter = 0;
function getUniqueCallbackName(prefix) {
    return `${prefix}_cb_${Date.now()}_${callbackCounter++}`;
}

// Official KernelSU / MMRL Execution Bridge
function exec(command, options = {}) {
    return new Promise((resolve) => {
        const callbackName = getUniqueCallbackName("exec");

        // Callback invoked by Android native layer: window[callbackName](errno, stdout, stderr)
        window[callbackName] = (errno, stdout, stderr) => {
            delete window[callbackName];
            resolve({
                errno: typeof errno === 'number' ? errno : 0,
                stdout: stdout || "",
                stderr: stderr || ""
            });
        };

        try {
            if (window.ksu && typeof window.ksu.exec === 'function') {
                window.ksu.exec(command, JSON.stringify(options), callbackName);
            } else if (window.mmrl && typeof window.mmrl.exec === 'function') {
                window.mmrl.exec(command, JSON.stringify(options), callbackName);
            } else {
                delete window[callbackName];
                resolve({ errno: 0, stdout: "Preview mode (no root bridge)", stderr: "" });
            }
        } catch (err) {
            delete window[callbackName];
            resolve({ errno: -1, stdout: "", stderr: String(err) });
        }
    });
}

// Toast Notification
function showToast(msg) {
    if (window.ksu && typeof window.ksu.toast === 'function') {
        try {
            window.ksu.toast(msg);
            return; // KernelSU ortamında çift bildirim oluşmaması için HTML toast'ı tetikleme
        } catch(e) {}
    }
    const toast = document.getElementById("toast");
    if (toast) {
        toast.textContent = msg;
        toast.classList.remove("hidden");
        setTimeout(() => toast.classList.add("hidden"), 2500);
    }
}

// Tab Switching
document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
        document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));

        btn.classList.add("active");
        const target = btn.getAttribute("data-tab");
        const content = document.getElementById(`tab-${target}`);
        if (content) content.classList.add("active");

        if (target === "settings") {
            loadConfig();
            scanVaults();
        } else if (target === "dashboard") {
            refreshDashboard();
        }
    });
});

// Refresh Dashboard
async function refreshDashboard() {
    const badge = document.getElementById("daemon-badge");
    const statCount = document.getElementById("stat-count");
    const statTime = document.getElementById("stat-time");
    const consoleBox = document.getElementById("log-console");

    badge.className = "badge badge-loading";
    badge.textContent = "CHECKING...";

    // 1. Daemon kontrolü
    const psRes = await exec("ps -ef | grep inotifyd | grep -v grep");
    if (psRes.stdout && psRes.stdout.includes("inotifyd")) {
        badge.className = "badge badge-active";
        badge.textContent = "ACTIVE";
    } else {
        badge.className = "badge badge-stopped";
        badge.textContent = "STOPPED";
    }

    // 2. config.env'den not yolunu oku
    const cfgRes = await exec(`cat "${CONFIG_PATH}" 2>/dev/null`);
    let notesDir = "/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/00-Zettelkasten";
    if (cfgRes.stdout) {
        const match = cfgRes.stdout.match(/DEST_NOTES=["']?([^"'\n]+)/);
        if (match) notesDir = match[1];
    }

    const countRes = await exec(`ls -1 "${notesDir}"/*.md 2>/dev/null | wc -l`);
    statCount.textContent = countRes.stdout ? countRes.stdout.trim() : "0";

    // 3. Son sync zamanını oku
    const timeRes = await exec(`cat "${STATE_PATH}" 2>/dev/null`);
    if (timeRes.stdout && timeRes.stdout.trim().length > 5) {
        const ms = parseInt(timeRes.stdout.trim(), 10);
        if (!isNaN(ms)) {
            const date = new Date(ms);
            statTime.textContent = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
            statTime.textContent = "-";
        }
    } else {
        statTime.textContent = "Never";
    }

    // 4. Log akışını oku (Son 25 satır)
    const logRes = await exec(`tail -n 25 "${LOG_PATH}" 2>/dev/null`);
    consoleBox.textContent = logRes.stdout ? logRes.stdout.trim() : "No log entries yet.";
    consoleBox.scrollTop = consoleBox.scrollHeight;
}

// Load Settings
async function loadConfig() {
    const res = await exec(`cat "${CONFIG_PATH}" 2>/dev/null`);
    if (!res.stdout) return;

    const lines = res.stdout.split("\n");
    lines.forEach(line => {
        const [key, val] = line.split("=");
        if (!key || !val) return;
        const cleanVal = val.replace(/["']/g, "").trim();

        if (key === "DEST_NOTES") {
            const el = document.getElementById("input-notes");
            if (el) el.value = cleanVal;
        }
        if (key === "DEST_ATTACHMENTS") {
            const el = document.getElementById("input-attachments");
            if (el) el.value = cleanVal;
        }
        if (key === "TIME_FORMAT") {
            const el = document.getElementById("select-format");
            if (el) el.value = cleanVal;
        }
        if (key === "NOTE_TAG") {
            const el = document.getElementById("input-tag");
            if (el) el.value = cleanVal;
        }
        if (key === "NOTE_LANG") {
            const el = document.getElementById("select-lang");
            if (el) el.value = cleanVal;
        }
    });
}

// Scan Vaults
async function scanVaults() {
    const select = document.getElementById("select-vault");
    if (!select) return;
    select.innerHTML = '<option value="">Scanning vaults...</option>';

    const res = await exec('find /storage/emulated/0 -maxdepth 5 -type d -name ".obsidian" 2>/dev/null');
    select.innerHTML = '<option value="">-- Select a detected vault --</option>';

    if (res.stdout && res.stdout.trim()) {
        const vaults = res.stdout.trim().split("\n");
        vaults.forEach(vaultPath => {
            const dir = vaultPath.replace("/.obsidian", "").trim();
            if (!dir) return;
            const name = dir.split("/").pop();
            const opt = document.createElement("option");
            opt.value = dir;
            opt.textContent = `${name} (${dir})`;
            select.appendChild(opt);
        });
    }

    select.onchange = async () => {
        const selected = select.value;
        if (!selected) return;

        let notes = `${selected}/00-Zettelkasten`;
        let att = `${selected}/99-index/Files`;

        const appRes = await exec(`cat "${selected}/.obsidian/app.json" 2>/dev/null`);
        if (appRes.stdout) {
            try {
                const appData = JSON.parse(appRes.stdout);
                if (appData.attachmentFolderPath) att = `${selected}/${appData.attachmentFolderPath}`;
                if (appData.newFileFolderPath) notes = `${selected}/${appData.newFileFolderPath}`;
            } catch (e) {}
        }

        document.getElementById("input-notes").value = notes;
        document.getElementById("input-attachments").value = att;
        showToast("Paths auto-filled from vault");
    };
}

// Save Settings
async function saveConfig() {
    const notes = document.getElementById("input-notes").value.trim();
    const att = document.getElementById("input-attachments").value.trim();
    const fmt = document.getElementById("select-format").value;
    const tag = document.getElementById("input-tag").value.trim() || "inbox/essential-space";
    const lang = document.getElementById("select-lang") ? document.getElementById("select-lang").value : "auto";

    if (!notes || !att) {
        showToast("Error: Paths cannot be empty!");
        return;
    }

    const content = `# Generated by WebUI\\nDEST_NOTES=\\"${notes}\\"\\nDEST_ATTACHMENTS=\\"${att}\\"\\nTIME_FORMAT=\\"${fmt}\\"\\nNOTE_TAG=\\"${tag}\\"\\nNOTE_LANG=\\"${lang}\\"\\n`;
    await exec(`mkdir -p "$(dirname "${CONFIG_PATH}")" "${notes}" "${att}"`);
    await exec(`printf "${content}" > "${CONFIG_PATH}"`);

    showToast("Settings saved successfully!");
}

// Trigger Manual Sync
const syncBtn = document.getElementById("btn-sync-now");
if (syncBtn) {
    syncBtn.addEventListener("click", async () => {
        showToast("Running sync...");
        await exec(`sh "${SYNC_SCRIPT}"`);
        showToast("Sync finished!");
        refreshDashboard();
    });
}

// Refresh Log Button
const refreshLogBtn = document.getElementById("btn-refresh-log");
if (refreshLogBtn) {
    refreshLogBtn.addEventListener("click", () => {
        refreshDashboard();
        showToast("Logs refreshed");
    });
}

// Save Settings Button
const saveBtn = document.getElementById("btn-save-config");
if (saveBtn) {
    saveBtn.addEventListener("click", saveConfig);
}

// Re-sync All Past History
const resetBtn = document.getElementById("btn-reset-history");
if (resetBtn) {
    resetBtn.addEventListener("click", async () => {
        if (confirm("Are you sure? This will reset the sync pointer and re-process all notes in Essential Space.")) {
            await exec(`echo "0" > "${STATE_PATH}"`);
            showToast("Pointer reset! Running full sync...");
            await exec(`sh "${SYNC_SCRIPT}"`);
            showToast("Full sync complete!");
            refreshDashboard();
        }
    });
}

// -----------------------------------------------------------------------------
// Software Update Logic (KernelSU, Magisk, MMRL)
// -----------------------------------------------------------------------------
const CURRENT_VERSION = "v1.1.1";
const CURRENT_VERSION_CODE = 111;
const STABLE_UPDATE_URL = "https://raw.githubusercontent.com/m24ih/nothing-essential-sync/main/update.json";
const NIGHTLY_UPDATE_URL = "https://raw.githubusercontent.com/m24ih/nothing-essential-sync/main/update-nightly.json";
let pendingUpdate = null;

const checkUpdateBtn = document.getElementById("btn-check-update");
const installUpdateBtn = document.getElementById("btn-install-update");
const updateBadge = document.getElementById("update-status-badge");
const updateInfo = document.getElementById("update-info-text");
const channelSelect = document.getElementById("select-channel");

if (checkUpdateBtn) {
    checkUpdateBtn.addEventListener("click", async () => {
        checkUpdateBtn.textContent = "CHECKING...";
        checkUpdateBtn.disabled = true;
        const channel = channelSelect ? channelSelect.value : "stable";
        const targetUrl = channel === "nightly" ? NIGHTLY_UPDATE_URL : STABLE_UPDATE_URL;

        try {
            // Android WebView CORS engeline takılmamak için doğrudan Root Shell (curl/wget) üzerinden çekiyoruz
            let rawJson = "";
            const shellRes = await exec(`curl -sL --connect-timeout 8 -H "Cache-Control: no-cache" "${targetUrl}" 2>/dev/null || wget -q -O - "${targetUrl}" 2>/dev/null`);
            if (shellRes.stdout && shellRes.stdout.trim().startsWith("{")) {
                rawJson = shellRes.stdout.trim();
            } else {
                // Fallback: tarayıcı fetch denemesi
                try {
                    const fetchRes = await fetch(`${targetUrl}?t=${Date.now()}`);
                    if (fetchRes.ok) {
                        rawJson = await fetchRes.text();
                    }
                } catch(e) {}
            }

            if (!rawJson) {
                throw new Error("Could not fetch update data (curl/wget/fetch failed)");
            }

            const data = JSON.parse(rawJson);

            if (channel === "nightly" || data.versionCode > CURRENT_VERSION_CODE) {
                pendingUpdate = data;
                if (updateBadge) {
                    updateBadge.className = "badge badge-active";
                    updateBadge.textContent = `${channel.toUpperCase()}: ${data.version}`;
                }
                if (updateInfo) {
                    updateInfo.textContent = `New ${channel} release available (${data.version})!`;
                }
                if (installUpdateBtn) {
                    installUpdateBtn.classList.remove("hidden");
                }
                showToast(`New ${channel} update found!`);
            } else {
                if (updateInfo) {
                    updateInfo.textContent = `You are on the latest stable version (${CURRENT_VERSION}).`;
                }
                showToast("You have the latest version!");
            }
        } catch (err) {
            console.error("Update check failed:", err);
            if (updateInfo) {
                updateInfo.textContent = `Update check failed: ${err.message || err}`;
            }
            showToast("Update check failed");
        } finally {
            checkUpdateBtn.textContent = "🔍 CHECK FOR UPDATES";
            checkUpdateBtn.disabled = false;
        }
    });
}

const rebootBtn = document.getElementById("btn-reboot");

if (installUpdateBtn) {
    installUpdateBtn.addEventListener("click", async () => {
        if (!pendingUpdate || !pendingUpdate.zipUrl) return;
        if (!confirm(`Do you want to download and install Nothing Essential Sync ${pendingUpdate.version}?`)) return;

        installUpdateBtn.disabled = true;
        installUpdateBtn.textContent = "INSTALLING...";
        showToast("Downloading update package...");

        const installCmd = `TMP_ZIP="/data/local/tmp/essential_sync_update.zip"
rm -f "$TMP_ZIP"
curl -L -s -k -f -o "$TMP_ZIP" "${pendingUpdate.zipUrl}" 2>/dev/null || wget --no-check-certificate -q -O "$TMP_ZIP" "${pendingUpdate.zipUrl}" 2>/dev/null
if [ ! -f "$TMP_ZIP" ] || [ ! -s "$TMP_ZIP" ]; then
    echo "DOWNLOAD_FAILED"
    exit 1
fi

# 1. Root manager üzerinden resmi kurulum
if command -v ksud >/dev/null 2>&1; then
    ksud module install "$TMP_ZIP"
elif [ -f "/data/adb/ksu/bin/ksud" ]; then
    /data/adb/ksu/bin/ksud module install "$TMP_ZIP"
elif command -v apd >/dev/null 2>&1; then
    apd module install "$TMP_ZIP"
elif command -v magisk >/dev/null 2>&1; then
    magisk --install-module "$TMP_ZIP"
fi

# 2. Canlı Hot-Reload (Cihazı yeniden başlatmadan anında geçerli kılma)
MOD_DIR="/data/adb/modules/nothing-essential-sync"
UPDATE_DIR="/data/adb/modules_update/nothing-essential-sync"
if [ -d "$UPDATE_DIR" ]; then
    cp -rf "$UPDATE_DIR"/* "$MOD_DIR"/ 2>/dev/null
fi
cp -f "$MOD_DIR/sync.sh" /data/adb/essential-sync/sync.sh 2>/dev/null
chmod 755 /data/adb/essential-sync/sync.sh "$MOD_DIR/sync.sh" 2>/dev/null
chmod -R 644 "$MOD_DIR/webroot/"* 2>/dev/null

# 3. Arka plan servisini anında canlandır
pkill -f inotifyd 2>/dev/null
if [ -f "$MOD_DIR/service.sh" ]; then
    sh "$MOD_DIR/service.sh" >/dev/null 2>&1 &
fi

rm -f "$TMP_ZIP"
exit 0`;

        const res = await exec(installCmd);
        if (res.errno === 0) {
            showToast("Update applied live!");
            if (updateInfo) {
                updateInfo.innerHTML = "✅ <strong>Version " + pendingUpdate.version + " installed!</strong><br><span style='color: var(--accent-green); font-size: 0.75rem;'>Service & WebUI updated live (No reboot required).</span><br><span style='color: var(--text-dim); font-size: 0.75rem;'>You can optionally reboot for KernelSU overlay sync.</span>";
            }
            if (updateBadge) {
                updateBadge.className = "badge badge-active";
                updateBadge.textContent = pendingUpdate.version;
            }
            installUpdateBtn.classList.add("hidden");
            if (rebootBtn) rebootBtn.classList.remove("hidden");
            setTimeout(refreshDashboard, 1500);
        } else {
            showToast("Installation failed: " + (res.stdout || res.stderr || "Unknown error"));
            installUpdateBtn.disabled = false;
            installUpdateBtn.textContent = "🚀 RETRY INSTALL";
        }
    });
}

if (rebootBtn) {
    rebootBtn.addEventListener("click", async () => {
        if (confirm("Reboot your phone now to finalize module overlay?")) {
            showToast("Rebooting device...");
            await exec("reboot");
        }
    });
}

// Initial Load
window.addEventListener("DOMContentLoaded", () => {
    refreshDashboard();
    loadConfig();
    scanVaults();
});

