# Changelog

All notable changes to the **Nothing Essential Sync** module will be documented in this file.

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
