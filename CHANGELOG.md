# Changelog

All notable changes to the **Nothing Essential Sync** module will be documented in this file.

## [v1.0.0] - 2026-10-06

### Added
- **100% Read-Only Snap-to-RAM Sync Engine**: Direct read-only extraction of notes, audio, images, and AI transcripts from Nothing OS Essential Space SQLite database.
- **KernelSU & MMRL WebUI**: Modern Nothing OS styled web interface for monitoring status, changing destinations, format, and triggering syncs.
- **Action Button Integration**: Non-interactive KernelSU Action script allowing one-tap sync with live status in the terminal.
- **Auto-Update Support**: Native KernelSU/Magisk `updateJson` specification support.
- **Debounce Lock**: Process lock mechanism in `sync.sh` to prevent concurrent triggers and duplicate logs.
