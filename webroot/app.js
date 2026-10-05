// ==============================================================================
// Nothing Essential Sync - WebUI Logic
// Works with KernelSU, APatch, and MMRL (Magisk)
// ==============================================================================

const CONFIG_PATH = "/data/adb/essential-sync/config.env";
const STATE_PATH = "/data/adb/essential-sync/last_sync_time.txt";
const LOG_PATH = "/data/adb/essential-sync/sync.log";
const SYNC_SCRIPT = "/data/adb/essential-sync/sync.sh";

// Root Execution Bridge
async function exec(cmd) {
    try {
        if (window.ksu && typeof window.ksu.exec === 'function') {
            return await window.ksu.exec(cmd);
        } else if (window.mmrl && typeof window.mmrl.exec === 'function') {
            return await window.mmrl.exec(cmd);
        } else {
            console.log("[PREVIEW MODE] Command:", cmd);
            return { errno: 0, stdout: "Mock output (preview mode)", stderr: "" };
        }
    } catch (err) {
        console.error("Exec error:", err);
        return { errno: -1, stdout: "", stderr: String(err) };
    }
}

// Toast Notification
function showToast(msg) {
    const toast = document.getElementById("toast");
    toast.textContent = msg;
    toast.classList.remove("hidden");
    setTimeout(() => toast.classList.add("hidden"), 2500);
}

// Tab Switching
document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
        document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));

        btn.classList.add("active");
        const target = btn.getAttribute("data-tab");
        document.getElementById(`tab-${target}`).classList.add("active");

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

    // 2. config.env'den not yolunu al ve not sayısını say
    const cfgRes = await exec(`[ -f "${CONFIG_PATH}" ] && cat "${CONFIG_PATH}"`);
    let notesDir = "/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/00-Zettelkasten";
    if (cfgRes.stdout) {
        const match = cfgRes.stdout.match(/DEST_NOTES=["']?([^"'\n]+)/);
        if (match) notesDir = match[1];
    }

    const countRes = await exec(`ls -1 "${notesDir}"/*.md 2>/dev/null | wc -l`);
    statCount.textContent = countRes.stdout ? countRes.stdout.trim() : "0";

    // 3. Son sync zamanını oku
    const timeRes = await exec(`[ -f "${STATE_PATH}" ] && cat "${STATE_PATH}"`);
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
    const logRes = await exec(`[ -f "${LOG_PATH}" ] && tail -n 25 "${LOG_PATH}"`);
    consoleBox.textContent = logRes.stdout ? logRes.stdout.trim() : "No log entries yet.";
    consoleBox.scrollTop = consoleBox.scrollHeight;
}

// Load Settings
async function loadConfig() {
    const res = await exec(`[ -f "${CONFIG_PATH}" ] && cat "${CONFIG_PATH}"`);
    if (!res.stdout) return;

    const lines = res.stdout.split("\n");
    lines.forEach(line => {
        const [key, val] = line.split("=");
        if (!key || !val) return;
        const cleanVal = val.replace(/["']/g, "").trim();

        if (key === "DEST_NOTES") document.getElementById("input-notes").value = cleanVal;
        if (key === "DEST_ATTACHMENTS") document.getElementById("input-attachments").value = cleanVal;
        if (key === "TIME_FORMAT") document.getElementById("select-format").value = cleanVal;
        if (key === "NOTE_TAG") document.getElementById("input-tag").value = cleanVal;
    });
}

// Scan Vaults
async function scanVaults() {
    const select = document.getElementById("select-vault");
    select.innerHTML = '<option value="">Scanning vaults...</option>';

    const res = await exec('find /storage/emulated/0 -maxdepth 5 -type d -name ".obsidian" 2>/dev/null');
    select.innerHTML = '<option value="">-- Select a detected vault --</option>';

    if (res.stdout && res.stdout.trim()) {
        const vaults = res.stdout.trim().split("\n");
        vaults.forEach(vaultPath => {
            const dir = vaultPath.replace("/.obsidian", "");
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

        // app.json oku
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

    if (!notes || !att) {
        showToast("Error: Paths cannot be empty!");
        return;
    }

    const content = `# Generated by WebUI\nDEST_NOTES="${notes}"\nDEST_ATTACHMENTS="${att}"\nTIME_FORMAT="${fmt}"\nNOTE_TAG="${tag}"\n`;
    await exec(`mkdir -p "$(dirname "${CONFIG_PATH}")" "${notes}" "${att}"`);
    await exec(`cat << 'EOF' > "${CONFIG_PATH}"\n${content}EOF`);

    showToast("Settings saved successfully!");
}

// Trigger Manual Sync
document.getElementById("btn-sync-now").addEventListener("click", async () => {
    showToast("Running sync...");
    const res = await exec(`sh "${SYNC_SCRIPT}"`);
    showToast("Sync finished!");
    refreshDashboard();
});

// Refresh Log Button
document.getElementById("btn-refresh-log").addEventListener("click", () => {
    refreshDashboard();
    showToast("Logs refreshed");
});

// Save Settings Button
document.getElementById("btn-save-config").addEventListener("click", saveConfig);

// Re-sync All Past History
document.getElementById("btn-reset-history").addEventListener("click", async () => {
    if (confirm("Are you sure? This will reset the sync pointer and re-process all notes in Essential Space.")) {
        await exec(`echo "0" > "${STATE_PATH}"`);
        showToast("Pointer reset! Running full sync...");
        await exec(`sh "${SYNC_SCRIPT}"`);
        showToast("Full sync complete!");
        refreshDashboard();
    }
});

// Initial Load
window.addEventListener("DOMContentLoaded", () => {
    refreshDashboard();
});
