# Nothing Essential Sync Optimization & English-First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize Nothing Essential Sync for minimal battery consumption (Doze-aware daemon), sub-second single-pass SQLite batching, and modernize the codebase with English-first standards.

**Architecture:** Daemon (`service.sh`) checks display state and DB `mtime` to sleep aggressively during screen-off/Doze. Core sync engine (`sync.sh`) maintains the 2-phase AI wait guard but collapses all subsequent card, media, event, and analysis queries into a single consolidated batch pass. WebUI (`app.js`, `index.html`) transitions to an incremental log reader and live status badge reporter.

**Tech Stack:** POSIX Shell (`/system/bin/sh`), SQLite3 CLI (`bin/sqlite3`), JavaScript (ES6+), HTML5/CSS3.

**Spec:** `docs/superpowers/specs/2026-10-13-optimization-english-first-design.md`

## Global Constraints
- **Platform:** Android 14+ / Nothing OS 3.x+ (arm64-v8a). Root runtime: KernelSU / APatch / Magisk.
- **Safety:** 100% Read-Only SQLite access (`file:...mode=ro`) to prevent locking Nothing OS Essential Space.
- **English-First:** All code comments, daemon/sync engine terminal logs, and WebUI base labels are in English. Locale-specific headers in Markdown notes are preserved with `en` default.
- **No external heavy dependencies:** Use toybox/toolbox built-ins and existing `bin/sqlite3`.

---

### Task 1: Daemon Power & Doze Optimization (`service.sh`)

**Files:**
- Modify: `service.sh`
- Test: Syntax check via `sh -n service.sh` and execution trace simulation.

**Interfaces:**
- Consumes: `dumpsys window`, `dumpsys display`, SQLite DB mtime.
- Produces: Dynamic sleep interval (120s screen-on vs 600s screen-off) and mtime-based early exit guard.

- [ ] **Step 1: Implement Display State & mtime Early-Exit Helpers**
Add functions to check if the display is currently awake and if the database has actually been modified since `last_sync_time.txt`.

- [ ] **Step 2: Update Fallback Loop & inotifyd Debounce**
In `service.sh`, adjust the fallback loop interval based on screen state and wrap the inotifyd call with proper log rotation.

- [ ] **Step 3: Verify and Test `service.sh`**
Run `sh -n service.sh` and verify execution logic.

- [ ] **Step 4: Commit Daemon Changes**
Run `gitleaks git --staged` and commit `feat(daemon): implement doze-aware power saving and db mtime guard`.

---

### Task 2: Core Engine Batch Query & English-First Migration (`sync.sh`)

**Files:**
- Modify: `sync.sh`
- Test: Mock SQLite database query execution and `sh -n sync.sh`.

**Interfaces:**
- Consumes: `essential_space_database`, `bin/sqlite3`, `config.env`.
- Produces: Markdown notes in `$DEST_NOTES`, `/data/adb/essential-sync/status.json` states.

- [ ] **Step 1: Translate Comments & Logs to English-First**
Convert all internal comments, log messages, and default fallback strings to clean English while preserving Turkish/multi-language dictionary for note templates.

- [ ] **Step 2: Add Live Status Reporter Helper**
Add a lightweight `set_status()` function that outputs `{"status": "$1", "updated_at": <epoch>}` to `${BASE_DIR}/status.json` (`syncing`, `waiting_ai`, `idle`).

- [ ] **Step 3: Implement Consolidated Batch Query**
Replace the N+1 per-card queries (10 separate `sqlite3` executions per card) with a consolidated batch query that fetches card details, resources, events, and analyses in a structured pipeline.

- [ ] **Step 4: Verify Syntax & Test with Mock SQLite DB**
Run syntax check `sh -n sync.sh` and verify with a mock database table schema.

- [ ] **Step 5: Commit Core Engine Changes**
Run `gitleaks git --staged` and commit `feat(engine): consolidate batch sqlite queries and modernize english logs`.

---

### Task 3: WebUI Live Status Badge & Incremental Log Reading (`webroot/`)

**Files:**
- Modify: `webroot/index.html`
- Modify: `webroot/app.js`
- Modify: `webroot/style.css`

**Interfaces:**
- Consumes: `/data/adb/essential-sync/status.json`, `/data/adb/essential-sync/sync.log`.
- Produces: Real-time status pill in UI header, efficient `tail -n 100` log reader.

- [ ] **Step 1: Add Status Badge Element to WebUI Header**
Add a visual status pill in `index.html` showing system status (Idle / AI Analysis / Syncing).

- [ ] **Step 2: Implement Status Polling & Incremental Tail in `app.js`**
Update log loading to fetch only the last 100 lines and poll `status.json` every 2.5 seconds to update the badge.

- [ ] **Step 3: English-First Standardization in WebUI**
Ensure all default labels, button texts, and tooltips are primarily English with clear explanations.

- [ ] **Step 4: Test WebUI & Commit**
Verify JS syntax and layout responsiveness. Commit via `feat(webui): add live status badge and incremental log streaming`.
