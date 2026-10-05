# Nothing Essential Space to Obsidian Sync

An ultra-lightweight, zero-battery, event-driven bridge for **Nothing OS** that seamlessly syncs quick captures, voice notes, screenshots, and AI summaries from **Essential Space** into **Obsidian** (or any Markdown vault) with a native Nothing-style WebUI.

---

## 🌟 Key Highlights

- **🔒 100% Read-Only Safety (Snap-to-RAM):**  
  Never touches or locks Nothing OS's live SQLite database. Queries run strictly on temporary RAM snapshots (`/data/local/tmp`). Your Essential Space data is never altered, deleted, or written to.
- **⚡ Zero Battery & CPU (Event-Driven):**  
  No polling or background battery drain. Uses Linux kernel `toybox inotifyd` to sleep at 0.0% CPU and wake up within milliseconds only when a new capture is saved.
- **📱 Nothing OS Aesthetic WebUI:**  
  Built with Nothing's signature monochrome dot-matrix (N-Dot) design. Works natively in **KernelSU**, **APatch**, and **MMRL (Magisk)**.
- **✨ Rich Multimodal Extraction:**  
  - 📝 **Notes & Captions:** Clean Markdown with YAML frontmatter.
  - 🎙️ **Voice Notes & AI Transcripts:** Audio files (`.wav`) copied to attachments + AI speech-to-text transcription automatically included.
  - 🖼️ **Screenshots:** WebP screenshots copied to vault attachments and embedded (`![[image.webp]]`).
  - 🧠 **AI Summaries:** Nothing AI summaries rendered in Obsidian callouts (`> [!summary]`).
- **🌍 Smart Device Localization (i18n):**  
  Automatically detects your device language (`persist.sys.locale`) and generates note callouts & section headers matching your phone's language (English, Turkish, German, French, Spanish, etc.), or lock your preferred language via WebUI.
- **🛡️ Ghost Note Protection:**  
  State-tracking timestamp ensures that when you triage, move, or delete notes on your PC or tablet, old notes are never resurrected.
- **🧩 Universal Root Compatibility:**  
  Works with KernelSU, KernelSU-Next, Magisk, and APatch.

---

## 📸 WebUI Preview (Nothing OS Design)

When installed as a module, open **KernelSU Manager** or **MMRL** and click **WebUI**:

- **Dashboard:** Live daemon status (`ACTIVE` / `STOPPED`), total synced note counter, last sync time, instant `⚡ SYNC NOW` button, and live activity log console.
- **Settings:** Auto-detects installed `.obsidian` vaults, auto-fills attachments directory from `.obsidian/app.json`, configures timestamp formats, custom tags, and offers a `🔄 RE-SYNC ALL PAST NOTES` button.

---

## 📦 Installation

### Method 1: Magisk / KernelSU / APatch Flashable Module (Recommended)
1. Download the latest `nothing-essential-sync-v1.1.1.zip` from [Stable Releases](https://github.com/m24ih/nothing-essential-sync/releases/latest) (or grab bleeding-edge builds from [Nightly Releases](https://github.com/m24ih/nothing-essential-sync/releases/tag/nightly)).
2. Open **KernelSU**, **APatch**, or **Magisk** app on your phone.
3. Tap **Modules** -> **Install from storage** -> Select the `.zip` file.
4. Reboot or open the module's **WebUI** in KernelSU/MMRL to configure your vault paths!

### Method 2: ADB Deployment (From PC)
Connect your Nothing Phone via USB or Wireless ADB with Root enabled:
```bash
git clone https://github.com/m24ih/nothing-essential-sync.git
cd nothing-essential-sync
./deploy.sh
```

### Method 3: Direct Phone Terminal (Termux / Root Shell)
If you already have root on your phone:
```bash
su
cd /data/adb/essential-sync
sh setup.sh
```

---

## ⚙️ Configuration (`config.env`)

Settings are stored in `/data/adb/essential-sync/config.env` and can be edited via WebUI, `setup.sh`, or manually:

```sh
# Target Obsidian / Markdown inbox directory
DEST_NOTES="/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/00-Zettelkasten"

# Target attachments directory (for images and voice recordings)
DEST_ATTACHMENTS="/storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/99-index/Files"

# Filename timestamp format (SQLite strftime format)
TIME_FORMAT="%Y-%m-%d %H.%M"

# Default tag added to note frontmatter
NOTE_TAG="inbox/essential-space"

# Note section language: "auto" (detect device locale), "en", "tr", "de", "fr", "es"
NOTE_LANG="auto"
```

---

## 📝 Generated Note Example

```markdown
---
id: 2372edbf-e772-46bf-8334-cada555f7c87
type: IMAGE
created: 2026-10-03 16:24:45
tags:
  - inbox/essential-space
---

# Calibre-web Obsidian Plugin

> [!summary] AI Summary
> New Calibre-web plugin for Obsidian enhances reading and note-taking with PDF/EPUB support.

### 🎙️ Voice Transcript
I crown the Cops and downpillaging the dust once again.

### 🎧 Audio Recording
![[52687339-a6f4-4f60-a1ed-49f235bcb851.wav]]

### 🖼️ Screenshot
![[014f109e-f437-4a97-9958-7a51865f564f.webp]]
```

---

## 🛠️ Building the Module ZIP

To build a fresh flashable ZIP module from source:
```bash
./make_module.sh
```
This generates `nothing-essential-sync-v1.1.0.zip` ready to flash.

---

## 🔄 Updates & Auto-Update Mechanism

Essential Sync provides two seamless update methods:
1. **KernelSU / Magisk / MMRL Native Auto-Update:**  
   The module integrates the official `updateJson` specification. When a new release is published to GitHub, your root manager displays an **Update** badge with changelog details for one-click installation.
2. **In-WebUI Update Checker:**  
   Under the **Info** tab in WebUI, tap **Check for Updates** to query GitHub directly. If a newer release is detected, tap **Install Update** to automatically download and flash the module via `ksud`/`apd`/`magisk`.

---

## 🗑️ Uninstallation

- If installed as a module: simply remove it via KernelSU / Magisk / APatch Manager.
- Or run in terminal:
  ```bash
  su -c 'sh /data/adb/essential-sync/uninstall.sh'
  ```
*Note: Your Obsidian notes and media attachments are never deleted or affected.*

---

## 📜 License
MIT License. Created by [Melih Ak (@m24ih)](https://github.com/m24ih).
