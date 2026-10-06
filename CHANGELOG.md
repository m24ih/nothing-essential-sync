# Changelog

All notable changes to the **Nothing Essential Sync** module will be documented in this file.

## [v1.2.2] - 2026-10-06

### Fixed & Hardened
- **Zero-Write Flash Protection (NAND Wear Prevention)**: Eliminated repeated copying of multi-megabyte databases to `/data/local/tmp` during AI polling loops; switched to direct zero-lock SQLite URI mode (`file:...db?mode=ro`).
- **Atomic Concurrency Lock**: Replaced TOCTOU lockfile race with POSIX atomic directory lock (`mkdir`) with PID validation, process debounce, and trap cleanup.
- **Graceful Wait Timeout Protection**: Separated placeholder reconciliation from the 150-second active AI wait filter; unanalyzed legacy notes no longer cause sync timeouts for new captures.
- **Obsidian Multiline Callout Formatting**: Properly escaped and prefixed multiline summaries, Q&As, and meeting analyses with `> ` so lines don't break outside Obsidian callout boxes.
- **Normalized Bullet Points**: Cleaned up empty lines and standardized bullet formatting for AI analysis items.
- **Automatic Log Rotation**: Enforced 512KB file size limit with automatic rotation on both `sync.log` and `daemon.log`.
- **Security Hardening**: Replaced shell `source` of config files with a safe regex key-value parser, added UUID pattern verification to prevent SQL injection, and applied strict input sanitization in setup scripts and WebUI.
- **Scoped Process Lifecycle**: Restricted `inotifyd` checks and termination signals to `ntessentialspace` to avoid killing other modules' background daemons.
- **Dynamic Versioning**: Replaced hardcoded versions across WebUI, `customize.sh`, and update managers with dynamic metadata extraction.

## [v1.2.1] - 2026-10-06

### Added
- **Tasks & Action Items Support (`card_events`)**: Automatically extracts Nothing OS AI tasks and reminders into native Obsidian Markdown checkboxes (`- [ ]` / `- [x]`) with formatted reminder timestamps (`⏰ HH:MM` / `📅 YYYY-MM-DD HH:MM`).
- **Interactive Task State Synchronization**: Tracks `card_events` status changes and update times, keeping task completion states in Obsidian in sync when tasks are checked on the device.

### Fixed
- **Pending Placeholder Auto-Resolution**: Automatically detects any existing unanalyzed placeholder notes in Obsidian (`*Essential Note.md`) and reconciles them when Nothing AI finishes.
- **Graceful AI Wait Query**: Removed invalid `ai_generate = 1` dependency from the wait condition; correctly checks Nothing OS `analysis_state = 0` and unpopulated title/summary fields.
- **Update Time Tracking**: State tracking now observes `update_time` alongside `create_time` so subsequent asynchronous AI analyses or title updates trigger synchronization.
- **Safe Dynamic File Renaming**: Upgrades file cleanup to match by card UUID (`id: <uuid>`), safely replacing placeholders without duplicate ID suffix collisions.

## [v1.2.0] - 2026-10-06

### Added
- **Native Obsidian Audio Player Support (.m4a)**: Essential Record audio captures (`.aac`) are automatically converted to `.m4a` on copy without re-encoding, activating Obsidian's native HTML5 audio playback widget.
- **Rich Multimodal Extraction (card_analysis)**: Fully extracts and formats meeting key topics (`MEETING_MAIN_TOPIC`, `MEETING_KEY_TOPIC_ANALYSIS`), process bullet points (`BULLET_POINTS`), and extracted metadata (`INFO_EXTRACT`) into Markdown callouts.
- **Graceful AI Wait**: Reliably waits for on-device Nothing AI pipeline to complete title, summary, and audio transcription before writing Obsidian notes.
- **Live Progress Logging**: Real-time waiting indicators (`⏳ Nothing AI analizi bekleniyor...`) appear in WebUI Dashboard console until analysis finishes.
- **Automatic Placeholder Cleanup**: Seamlessly deletes any temporary placeholder notes when the finalized AI-analyzed version is synced.

### Fixed
- **Race Condition on Live Captures**: Fixed issue where notes were synced before Nothing AI finished generating title and summaries.
- **Essential Record Audio Missing**: Fixed resource query to properly capture `RECORDING` raw_types alongside `AUDIO`.

## [v1.1.2] - 2026-10-06

### Fixed
- **Single Toast Notification**: Resolved overlapping toast messages in KernelSU by prioritizing native toast notifications.
- **Release Naming**: Placed version number upfront (`v1.1.2 - Nothing Essential Sync`) for cleaner visibility on GitHub Releases.

### Added
- **Hot-Reload Live Updates**: In-app WebUI module updates are now applied immediately to live service files without requiring a device reboot.
- **WebUI Reboot Button**: Added dedicated `🔄 REBOOT PHONE` button for optional KernelSU overlay persistence.

## [v1.1.1] - 2026-10-06

### Added
- **Smart Device Localization (i18n)**: Automatically detects system language (`persist.sys.locale`) and generates note callouts & section headers matching the device language (English, Turkish, German, French, Spanish).
- **WebUI Language Selector**: Note language can now be manually locked or set to auto-detect from the Settings tab.
- **Root Shell Update Fetcher**: Update queries now bypass Android WebView CORS restrictions via root shell `curl`/`wget`.

## [v1.1.0] - 2026-10-06

### Added
- **KernelSU & Magisk Auto-Update Support**: Native `updateJson` specification integration for one-click updates via root managers.
- **In-App WebUI Update Center**: Channel selection (Stable / Nightly), update check against GitHub releases, and direct root flash mechanism.
- **GitHub Actions CI/CD**: Automated nightly releases on every commit + manual/tag-triggered production releases.
- **Process Lock & Debounce**: Prevent duplicate execution and repeated logs when inotify triggers multiple file closure events.

## [v1.0.0] - 2026-10-06

### Added
- **100% Read-Only Snap-to-RAM Sync Engine**: Direct read-only extraction of notes, audio, images, and AI transcripts from Nothing OS Essential Space SQLite database.
- **KernelSU & MMRL WebUI**: Modern Nothing OS styled web interface for monitoring status, changing destinations, format, and triggering syncs.
- **Action Button Integration**: Non-interactive KernelSU Action script allowing one-tap sync with live status in the terminal.
