# Nothing Essential Space to Obsidian Sync

> [!CAUTION]
> ### ⚠️ Disclaimer & Privacy Notice
> - **Independent Project:** This is an independent open-source tool developed solely for personal workflow needs, educational exploration, and software interoperability. It is **not** affiliated with, endorsed by, maintained by, or associated with **Nothing Technology Limited** in any way. "Nothing", "Nothing OS", and "Essential Space" are registered trademarks of Nothing Technology Limited.
> - **Use at Your Own Risk:** This software is provided "AS IS", without warranty of any kind, express or implied. Root access carries inherent system responsibilities. Use this module entirely at your own risk. The author accepts no liability or responsibility for any data loss, system instability, or unintended consequences.
> - **100% On-Device & Zero Cloud (Privacy-First):** All processing and synchronization occurs **strictly locally on your device**. No notes, voice recordings, screenshots, metadata, or telemetry are ever transmitted outside your device. No third-party servers, external cloud services, or remote APIs are used.

An ultra-lightweight, zero-battery, event-driven bridge for **Nothing OS** that seamlessly syncs quick captures, voice notes, screenshots, action tasks, and AI summaries from **Essential Space** into **Obsidian** (or any Markdown vault) with a native Nothing-style WebUI.

---

## 🌟 Key Highlights

- **🔒 100% Read-Only Safety (Zero-Lock SQLite URI):**  
  Direct read-only URI mode (`file:...db?mode=ro`). Never locks or touches Nothing OS's live SQLite database, with zero temporary storage writes and zero flash wear. Your Essential Space data is never altered, deleted, or written to.
- **⚡ Zero Battery & CPU (Event-Driven & Doze-Aware):**  
  Uses Linux kernel `toybox inotifyd` to sleep at 0.0% CPU and wake up within milliseconds only when a new capture is saved. Screen-off / Doze detection intelligently relaxes background checks to eliminate wakelocks.
- **🚀 Single-Pass Batch Processing:**  
  Extracts all cards, audio attachments, task checklists, and AI analyses in a single consolidated SQL pass with sub-100ms execution times.
- **📱 Nothing OS Aesthetic WebUI & Theme Engine:**  
  Built with Nothing's signature monochrome dot-matrix (N-Dot) design. Features a live status badge (`Idle`, `Waiting AI`, `Syncing`), live logs, and a 3-way Theme Engine (`System Auto`, `Light`, `Dark`). Works natively in **KernelSU**, **APatch**, and **MMRL (Magisk)**.
- **✨ Rich Multimodal Extraction:**  
  - 📝 **Notes & Captions:** Clean Markdown with YAML frontmatter.
  - 🎙️ **Voice Notes & AI Transcripts:** Voice recordings converted to `.m4a` for Obsidian's native HTML5 audio player + AI speech-to-text transcription automatically included.
  - 🖼️ **Screenshots:** WebP screenshots copied to vault attachments and embedded (`![[image.webp]]`).
  - ✅ **Tasks & Action Items:** Extracts checklists (`card_events`) with reminder dates into interactive Markdown checkboxes (`- [ ]` / `- [x]`).
  - 🧠 **AI Summaries & Meeting Analysis:** Nothing AI summaries, bullet points, key meeting topics, and Q&A rendered in clean Obsidian callouts (`> [!summary]`, `> [!abstract]`, `> [!info]`).
- **🌍 Smart Device Localization (i18n):**  
  Automatically detects your device language (`persist.sys.locale`) or lets you configure preferred languages (English, Turkish, German, French, Spanish) for note section headers and callouts.
- **🛡️ Ghost Note Protection & Stale Lock Prevention:**  
  State-tracking ensures deleted or moved notes in Obsidian are never resurrected. Strict PID cmdline validation prevents stale locks across reboots.
- **🧩 Universal Root Compatibility:**  
  Works with KernelSU, KernelSU-Next, Magisk, and APatch.

---

## 📸 WebUI Preview (Nothing OS Design)

When installed as a module, open **KernelSU Manager**, **APatch**, or **MMRL** and tap **WebUI**:

- **Dashboard:** Real-time animated status pill (`Idle` / `Waiting AI` / `Syncing`), daemon status (`ACTIVE` / `STOPPED`), total synced card counter, last sync time, instant `⚡ SYNC NOW` button, and incremental live activity log console.
- **Settings:** Auto-detects installed `.obsidian` vaults, auto-fills attachments directory from `.obsidian/app.json`, configures timestamp formats, custom tags, note language, theme switcher (`Auto` / `Light` / `Dark`), and a `🔄 RE-SYNC ALL PAST NOTES` button.
- **Info & Updates:** In-app GitHub release checker with one-click direct update flashing.

---

## 📦 Installation

### Method 1: Magisk / KernelSU / APatch Flashable Module (Recommended)
1. Download the latest `nothing-essential-sync-v1.3.0.zip` (or the latest release asset) from [GitHub Releases](https://github.com/m24ih/nothing-essential-sync/releases/latest) (or grab bleeding-edge builds from [Nightly Releases](https://github.com/m24ih/nothing-essential-sync/releases/tag/nightly)).
2. Open **KernelSU**, **APatch**, or **Magisk** app on your phone.
3. Tap **Modules** -> **Install from storage** -> Select the downloaded `.zip` file.
4. Reboot or open the module's **WebUI** in your root manager to configure your vault paths!

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

# Project Kickoff & Roadmap

> [!summary] AI Summary
> Team discussed the upcoming Q4 deliverables, milestones, and architecture refactoring for offline synchronization.

### 🎯 Key Topics
Product Roadmap, Synchronization Engine, Mobile Usability

### 📌 Key Points
- Finalize SQLite single-pass batch query architecture.
- Verify zero-lock memory access modes.
- Publish documentation and user guides.

### ✅ Action Items
- [ ] Review PR for battery optimization ⏰ 17:00
- [x] Merge localization template fixes

### 🎙️ Voice Transcript
We agreed to optimize the background worker to sleep during Doze mode and keep battery drain at zero percent.

### 🎧 Audio Recording
![[audio_recording_52687339.m4a]]

### 🖼️ Screenshot
![[screenshot_014f109e.webp]]
```

---

## 🛠️ Building the Module ZIP

To build a fresh flashable ZIP module from source:
```bash
./make_module.sh
```
This generates `nothing-essential-sync-v1.3.0.zip` (matching the current version in `module.prop`) ready to flash.

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

