#!/system/bin/sh
# ==============================================================================
# Nothing Phone Essential Space -> Obsidian One-Way Sync Engine
# Device: Nothing Phone 3a (Android 17 / Nothing OS 5.0)
# Mode: 100% READ-ONLY on Essential Space database and files
# Target: /storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian
# ==============================================================================

set -u

export PATH="/data/adb/essential-sync/bin:/system/bin:/system/xbin:/apex/com.android.runtime/bin:${PATH:-}"
unset LD_LIBRARY_PATH

BASE_DIR="/data/adb/essential-sync"
SQLITE_BIN="${BASE_DIR}/bin/sqlite3"
STATE_FILE="${BASE_DIR}/last_sync_time.txt"
LOG_FILE="${BASE_DIR}/sync.log"
STATUS_FILE="${BASE_DIR}/status.json"

SOURCE_DB_DIR="/data/data/com.nothing.ntessentialspace/databases"
SOURCE_DB="${SOURCE_DB_DIR}/essential_space_database"

# Safe configuration parser (Shell injection & LPE protection)
CONFIG_FILE="${BASE_DIR}/config.env"
get_cfg() {
    _KEY="$1"
    _DEFAULT="$2"
    if [ -f "${CONFIG_FILE}" ]; then
        _VAL=$(grep -m1 "^[[:space:]]*${_KEY}=" "${CONFIG_FILE}" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')
        _VAL=$(echo "${_VAL}" | sed 's/^[[:space:]]*["'\'']\{0,1\}//; s/["'\'']\{0,1\}[[:space:]]*$//')
        if [ -n "${_VAL}" ]; then
            echo "${_VAL}"
            return
        fi
    fi
    echo "${_DEFAULT}"
}

DEST_NOTES=$(get_cfg "DEST_NOTES" "/storage/emulated/0/Documents/EssentialSpaceNotes/00-Zettelkasten")
DEST_ATTACHMENTS=$(get_cfg "DEST_ATTACHMENTS" "/storage/emulated/0/Documents/EssentialSpaceNotes/attachments")
TIME_FORMAT=$(get_cfg "TIME_FORMAT" "%Y-%m-%d %H.%M" | tr -d "'\"")
NOTE_TAG=$(get_cfg "NOTE_TAG" "inbox/essential-space")
NOTE_LANG=$(get_cfg "NOTE_LANG" "auto")

# Detect system language for note template strings (persist.sys.locale -> ro.product.locale -> fallback: en)
DETECTED_LANG="en"
if [ "${NOTE_LANG}" = "auto" ] || [ -z "${NOTE_LANG}" ]; then
    LOCALE_PROP=$(getprop persist.sys.locale 2>/dev/null)
    [ -z "${LOCALE_PROP}" ] && LOCALE_PROP=$(getprop ro.product.locale 2>/dev/null)
    case "${LOCALE_PROP}" in
        tr*|TR*) DETECTED_LANG="tr" ;;
        de*|DE*) DETECTED_LANG="de" ;;
        fr*|FR*) DETECTED_LANG="fr" ;;
        es*|ES*) DETECTED_LANG="es" ;;
        *)       DETECTED_LANG="en" ;;
    esac
else
    DETECTED_LANG="${NOTE_LANG}"
fi

# Multi-language dictionary for Obsidian note templates
case "${DETECTED_LANG}" in
    tr)
        STR_SUMMARY="AI Özeti"
        STR_NOTE="Not"
        STR_TRANSCRIPT="Ses Dökümü"
        STR_AUDIO="Ses Kaydı"
        STR_SCREENSHOT="Ekran Görüntüsü"
        STR_DEFAULT_TITLE="Essential Not"
        STR_KEY_TOPICS="Ana Konu"
        STR_ANALYSIS="Analiz & Detaylar"
        STR_EXTRACTED_INFO="Önemli Bilgi"
        STR_TASKS="Görevler"
        ;;
    de)
        STR_SUMMARY="KI-Zusammenfassung"
        STR_NOTE="Notiz"
        STR_TRANSCRIPT="Sprachtranskript"
        STR_AUDIO="Audioaufnahme"
        STR_SCREENSHOT="Screenshot"
        STR_DEFAULT_TITLE="Essential Notiz"
        STR_KEY_TOPICS="Hauptthema"
        STR_ANALYSIS="Analyse & Details"
        STR_EXTRACTED_INFO="Wichtige Information"
        STR_TASKS="Aufgaben"
        ;;
    fr)
        STR_SUMMARY="Résumé IA"
        STR_NOTE="Note"
        STR_TRANSCRIPT="Transcription vocale"
        STR_AUDIO="Enregistrement audio"
        STR_SCREENSHOT="Capture d'écran"
        STR_DEFAULT_TITLE="Note Essential"
        STR_KEY_TOPICS="Sujet principal"
        STR_ANALYSIS="Analyse & Détails"
        STR_EXTRACTED_INFO="Information importante"
        STR_TASKS="Tâches"
        ;;
    es)
        STR_SUMMARY="Resumen de IA"
        STR_NOTE="Nota"
        STR_TRANSCRIPT="Transcripción de voz"
        STR_AUDIO="Grabación de audio"
        STR_SCREENSHOT="Captura de pantalla"
        STR_DEFAULT_TITLE="Nota Essential"
        STR_KEY_TOPICS="Tema principal"
        STR_ANALYSIS="Análisis & Detalles"
        STR_EXTRACTED_INFO="Información importante"
        STR_TASKS="Tareas"
        ;;
    *)
        # Default (en)
        STR_SUMMARY="AI Summary"
        STR_NOTE="Note"
        STR_TRANSCRIPT="Voice Transcript"
        STR_AUDIO="Audio Recording"
        STR_SCREENSHOT="Screenshot"
        STR_DEFAULT_TITLE="Essential Note"
        STR_KEY_TOPICS="Key Topics"
        STR_ANALYSIS="Detailed Analysis"
        STR_EXTRACTED_INFO="Key Information"
        STR_TASKS="Tasks"
        ;;
esac

# Live status reporter helper for WebUI and system status tracking
set_status() {
    echo "{\"status\": \"$1\", \"updated_at\": $(date +%s)}" > "${STATUS_FILE}" 2>/dev/null || true
}

LOCK_DIR="/data/local/tmp/essential_sync.lock"

# Process check helper to prevent parallel or double executions
is_process_sync() {
    _PID="$1"
    [ -z "${_PID}" ] && return 1
    kill -0 "${_PID}" 2>/dev/null || return 1
    grep -qa "sync.sh" "/proc/${_PID}/cmdline" 2>/dev/null || return 1
    return 0
}

# Acquire atomic execution lock
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    OLD_PID=$(cat "${LOCK_DIR}/pid" 2>/dev/null)
    if [ -z "${OLD_PID}" ]; then
        # Micro race condition grace period
        sleep 1
        OLD_PID=$(cat "${LOCK_DIR}/pid" 2>/dev/null)
    fi
    if [ -n "${OLD_PID}" ] && is_process_sync "${OLD_PID}"; then
        exit 0
    fi
    # Clean stale/dead lock
    rm -rf "${LOCK_DIR}" 2>/dev/null
    if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "${LOCK_DIR}/pid"
set_status "syncing"

# Short debounce to quell inotify event bursts
sleep 1

TMP_DIR="/data/local/tmp/essential_tmp_$$"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    # Limit log file to 512 KB (automatic rotation)
    if [ -f "${LOG_FILE}" ] && [ "$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)" -gt 512000 ]; then
        tail -n 1000 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && mv -f "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null
    fi
}

cleanup() {
    rm -rf "${TMP_DIR}" 2>/dev/null
    if [ -f "${LOCK_DIR}/pid" ] && [ "$(cat "${LOCK_DIR}/pid" 2>/dev/null)" = "$$" ]; then
        rm -rf "${LOCK_DIR}" 2>/dev/null
        set_status "idle"
    fi
}
trap cleanup EXIT INT TERM

# 1. Environment & Pre-condition checks
if [ ! -f "${SOURCE_DB}" ]; then
    log "WARNING: Essential Space database not found: ${SOURCE_DB}"
    exit 0
fi

if [ ! -x "${SQLITE_BIN}" ]; then
    log "ERROR: sqlite3 binary not found or not executable: ${SQLITE_BIN}"
    exit 1
fi

mkdir -p "${DEST_NOTES}" "${DEST_ATTACHMENTS}" "${TMP_DIR}/cards"

# 2. Direct Read-Only Database Access (Zero Flash Wear / Zero Lock)
SNAP_DB="file:${SOURCE_DB}?mode=ro"

# 3. Read last synchronization timestamp
LAST_SYNC=0
if [ -f "${STATE_FILE}" ]; then
    LAST_SYNC=$(cat "${STATE_FILE}" 2>/dev/null | tr -d '\r\n')
    case "${LAST_SYNC}" in
        ''|*[!0-9]*) LAST_SYNC=0 ;;
    esac
fi

# 4. Detect unresolved draft/placeholder note files
PLACEHOLDER_IDS=""
for PH in "${DEST_NOTES}"/*" - ${STR_DEFAULT_TITLE}.md" "${DEST_NOTES}"/*" - Essential Note.md" "${DEST_NOTES}"/*" - Essential Not.md"; do
    [ -f "${PH}" ] || continue
    PID=$(grep -m1 '^id: ' "${PH}" 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    # SQL injection protection: only accept valid 36-char UUIDs
    if [ -n "${PID}" ] && echo "${PID}" | grep -Eq '^[0-9a-fA-F-]{36}$'; then
        if [ -z "${PLACEHOLDER_IDS}" ]; then
            PLACEHOLDER_IDS="'${PID}'"
        else
            PLACEHOLDER_IDS="${PLACEHOLDER_IDS},'${PID}'"
        fi
    fi
done

if [ -n "${PLACEHOLDER_IDS}" ]; then
    QUERY_FILTER="((create_time > ${LAST_SYNC} OR update_time > ${LAST_SYNC} OR card_id IN (SELECT card_id FROM card_events WHERE update_time > ${LAST_SYNC} AND deleted = 0)) OR card_id IN (${PLACEHOLDER_IDS}))"
else
    QUERY_FILTER="(create_time > ${LAST_SYNC} OR update_time > ${LAST_SYNC} OR card_id IN (SELECT card_id FROM card_events WHERE update_time > ${LAST_SYNC} AND deleted = 0))"
fi

# Fast O(1) existence check for new or updated cards
HAS_CARDS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT 1 FROM cards WHERE ${QUERY_FILTER} AND soft_delete_at <= 0 LIMIT 1;")
if [ -z "${HAS_CARDS}" ]; then
    # No new or updated cards to process
    exit 0
fi

# Phase 1: Graceful AI Wait Guard
# Only wait for cards created or updated within the last 5 minutes (300,000 ms).
# Avoids stalling new syncs for 150s on older unresolved drafts.
PENDING_WAIT_FILTER="(create_time > ${LAST_SYNC} OR update_time > ${LAST_SYNC}) AND (strftime('%s', 'now')*1000 - create_time) < 300000 AND soft_delete_at <= 0 AND (analysis_state = 0 OR summary IS NULL OR trim(summary) = '' OR title IS NULL OR trim(title) = '')"

MAX_WAIT_SECONDS=150
POLL_INTERVAL=2
ELAPSED=0

while [ ${ELAPSED} -lt ${MAX_WAIT_SECONDS} ]; do
    PENDING_COUNT=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT count(*) FROM cards WHERE ${PENDING_WAIT_FILTER};")
    if [ "${PENDING_COUNT}" = "0" ] || [ -z "${PENDING_COUNT}" ]; then
        break
    fi

    set_status "waiting_ai"

    # Emit progress log every 6 seconds (visible on WebUI Dashboard)
    if [ $((ELAPSED % 6)) -eq 0 ]; then
        PENDING_TYPES=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT group_concat(type) FROM cards WHERE ${PENDING_WAIT_FILTER};")
        log "⏳ Waiting for Nothing AI analysis (${PENDING_TYPES}) [${ELAPSED}s/${MAX_WAIT_SECONDS}s]..."
    fi

    sleep ${POLL_INTERVAL}
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ ${ELAPSED} -gt 0 ]; then
    if [ ${ELAPSED} -ge ${MAX_WAIT_SECONDS} ]; then
        log "⚠️ Nothing AI wait timeout (${MAX_WAIT_SECONDS}s). Syncing cards with current data..."
    else
        log "✨ Nothing AI analysis completed (${ELAPSED}s)! Starting sync..."
    fi
    set_status "syncing"
fi

log "New cards found. Starting sync..."

# Phase 2: Consolidated Batch Query & Stream Demuxing
# Single SQL batch extraction for cards, resources, tasks, and analyses
BATCH_SQL="SELECT
  '===ES_SYNC_CARD_START:' || c.card_id || '===' || char(10) ||
  '===ES_SYNC_META===' || char(10) ||
  'CARD_ID=' || c.card_id || char(10) ||
  'CREATE_TIME=' || c.create_time || char(10) ||
  'UPDATE_TIME=' || c.update_time || char(10) ||
  'DATE_STR=' || coalesce(strftime('${TIME_FORMAT}', c.create_time/1000, 'unixepoch', 'localtime'), '') || char(10) ||
  'DATE_ISO=' || coalesce(strftime('%Y-%m-%d %H:%M:%S', c.create_time/1000, 'unixepoch', 'localtime'), '') || char(10) ||
  'CARD_TYPE=' || coalesce(c.type, 'NOTE') || char(10) ||
  'IMAGE_URI=' || coalesce((SELECT data FROM card_resources WHERE card_id = c.card_id AND raw_type = 'IMAGE' LIMIT 1), '') || char(10) ||
  'AUDIO_URI=' || coalesce((SELECT data FROM card_resources WHERE card_id = c.card_id AND raw_type IN ('AUDIO', 'RECORDING') LIMIT 1), '') || char(10) ||
  'MAX_EV_TIME=' || coalesce((SELECT max(update_time) FROM card_events WHERE card_id = c.card_id AND deleted = 0), 0) || char(10) ||
  '===ES_SYNC_TITLE===' || char(10) ||
  coalesce(c.title, '') || char(10) ||
  CASE WHEN c.summary IS NOT NULL AND trim(c.summary) != ''
    THEN '===ES_SYNC_SUMMARY===' || char(10) || c.summary || char(10)
    ELSE ''
  END ||
  coalesce((
    SELECT '===ES_SYNC_NOTE_TEXT===' || char(10) || data || char(10)
    FROM card_resources
    WHERE card_id = c.card_id AND raw_type IN ('TEXT', 'NOTE_TEXT') AND data IS NOT NULL AND trim(data) != ''
    LIMIT 1
  ), '') ||
  coalesce((
    SELECT '===ES_SYNC_TRANSCRIPTION===' || char(10) || data || char(10)
    FROM card_resources
    WHERE card_id = c.card_id AND raw_type = 'TRANSCRIPTION' AND data IS NOT NULL AND trim(data) != ''
    LIMIT 1
  ), '') ||
  coalesce((
    SELECT '===ES_SYNC_EVENTS===' || char(10) ||
      group_concat(
        '- [' || CASE WHEN \"check\" = 1 THEN 'x' ELSE ' ' END || '] ' ||
        CASE WHEN content IS NOT NULL AND trim(content) != '' THEN content ELSE coalesce(title, '') END ||
        CASE
          WHEN time IS NOT NULL AND time > 0 AND strftime('%Y-%m-%d', time/1000, 'unixepoch', 'localtime') = strftime('%Y-%m-%d', c.create_time/1000, 'unixepoch', 'localtime')
            THEN ' ⏰ ' || strftime('%H:%M', time/1000, 'unixepoch', 'localtime')
          WHEN time IS NOT NULL AND time > 0
            THEN ' 📅 ' || strftime('%Y-%m-%d %H:%M', time/1000, 'unixepoch', 'localtime')
          ELSE ''
        END,
        char(10)
      ) || char(10)
    FROM (
      SELECT * FROM card_events
      WHERE card_id = c.card_id AND deleted = 0 AND ((content IS NOT NULL AND trim(content) != '') OR (title IS NOT NULL AND trim(title) != ''))
      ORDER BY card_event_id ASC
    )
    HAVING count(*) > 0
  ), '') ||
  coalesce((
    SELECT '===ES_SYNC_ANALYSES===' || char(10) ||
      group_concat(
        '===ES_SYNC_ANALYSIS_ITEM_START===' || char(10) ||
        'A_TYPE=' || raw_type || char(10) ||
        'A_TITLE=' || replace(coalesce(CASE WHEN json_valid(metadata) THEN json_extract(metadata, '$.title') ELSE '' END, ''), char(10), ' ') || char(10) ||
        'A_TIME=' || replace(coalesce(CASE WHEN json_valid(metadata) THEN json_extract(metadata, '$.timestamp_reference') ELSE '' END, ''), char(10), ' ') || char(10) ||
        '===ES_SYNC_A_CONTENT===' || char(10) ||
        coalesce(CASE WHEN json_valid(metadata) THEN coalesce(json_extract(metadata, '$.bulletPointItem'), json_extract(metadata, '$.content'), json_extract(metadata, '$.detailed_summary'), json_extract(metadata, '$.extractedInformation'), '') ELSE metadata END, '') || char(10) ||
        '===ES_SYNC_ANALYSIS_ITEM_END===',
        char(10)
      ) || char(10)
    FROM (
      SELECT * FROM card_analysis
      WHERE card_id = c.card_id
      ORDER BY card_analysis_id ASC
    )
    HAVING count(*) > 0
  ), '') ||
  '===ES_SYNC_CARD_END==='
FROM cards c
WHERE ${QUERY_FILTER} AND c.soft_delete_at <= 0
ORDER BY c.create_time ASC, c.update_time ASC;"

"${SQLITE_BIN}" "${SNAP_DB}" "${BATCH_SQL}" | awk -v outdir="${TMP_DIR}/cards" '
BEGIN {
    card_id = "";
    cur_file = "";
    a_idx = 0;
}
/^===ES_SYNC_CARD_START:/ {
    line = $0;
    sub(/^===ES_SYNC_CARD_START:/, "", line);
    sub(/===$/, "", line);
    card_id = line;
    cur_file = "";
    a_idx = 0;
    next;
}
/^===ES_SYNC_META===$/ { cur_file = outdir "/" card_id ".meta"; next; }
/^===ES_SYNC_TITLE===$/ { cur_file = outdir "/" card_id ".title"; next; }
/^===ES_SYNC_SUMMARY===$/ { cur_file = outdir "/" card_id ".summary"; next; }
/^===ES_SYNC_NOTE_TEXT===$/ { cur_file = outdir "/" card_id ".note_text"; next; }
/^===ES_SYNC_TRANSCRIPTION===$/ { cur_file = outdir "/" card_id ".transcription"; next; }
/^===ES_SYNC_EVENTS===$/ { cur_file = outdir "/" card_id ".events"; next; }
/^===ES_SYNC_ANALYSES===$/ { cur_file = ""; next; }

/^===ES_SYNC_ANALYSIS_ITEM_START===$/ {
    a_idx++;
    cur_file = outdir "/" card_id ".a_" a_idx ".meta";
    next;
}
/^===ES_SYNC_A_CONTENT===$/ {
    cur_file = outdir "/" card_id ".a_" a_idx ".content";
    next;
}
/^===ES_SYNC_ANALYSIS_ITEM_END===$/ {
    cur_file = "";
    next;
}
/^===ES_SYNC_CARD_END===$/ {
    cur_file = "";
    card_id = "";
    next;
}
cur_file != "" {
    print >> cur_file;
}
'

for META_FILE in "${TMP_DIR}/cards/"*.meta; do
    [ -f "${META_FILE}" ] || continue

    CARD_ID=$(grep '^CARD_ID=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    CREATE_TIME=$(grep '^CREATE_TIME=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    UPDATE_TIME=$(grep '^UPDATE_TIME=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    DATE_STR=$(grep '^DATE_STR=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    DATE_ISO=$(grep '^DATE_ISO=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    CARD_TYPE=$(grep '^CARD_TYPE=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    IMAGE_URI=$(grep '^IMAGE_URI=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    AUDIO_URI=$(grep '^AUDIO_URI=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)
    MAX_EV_TIME=$(grep '^MAX_EV_TIME=' "${META_FILE}" 2>/dev/null | cut -d'=' -f2-)

    [ -z "${CARD_ID}" ] && continue

    TITLE=""
    [ -f "${TMP_DIR}/cards/${CARD_ID}.title" ] && TITLE=$(cat "${TMP_DIR}/cards/${CARD_ID}.title" 2>/dev/null)

    # Media copy (Image)
    IMG_FILENAME=""
    if [ -n "${IMAGE_URI}" ]; then
        IMG_SRC=$(echo "${IMAGE_URI}" | sed 's|^file://||')
        if [ -f "${IMG_SRC}" ]; then
            IMG_FILENAME=$(basename "${IMG_SRC}")
            cp -f "${IMG_SRC}" "${DEST_ATTACHMENTS}/${IMG_FILENAME}" 2>/dev/null
            chmod 660 "${DEST_ATTACHMENTS}/${IMG_FILENAME}" 2>/dev/null
        fi
    fi

    # Media copy (Audio)
    AUDIO_FILENAME=""
    if [ -n "${AUDIO_URI}" ]; then
        AUDIO_SRC=$(echo "${AUDIO_URI}" | sed 's|^file://||')
        if [ -f "${AUDIO_SRC}" ]; then
            AUDIO_FILENAME=$(basename "${AUDIO_SRC}")
            # Obsidian cannot play .aac files in its native audio player.
            # However Nothing OS creates these recordings in ISO MP42 (M4A) format.
            # Changing extension to .m4a makes them playable directly in Obsidian.
            case "${AUDIO_FILENAME}" in
                *.aac) AUDIO_FILENAME="${AUDIO_FILENAME%.aac}.m4a" ;;
            esac
            cp -f "${AUDIO_SRC}" "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
            chmod 660 "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
        fi
    fi

    # Sanitize title for filename
    CLEAN_TITLE=$(echo "${TITLE}" | tr '/\\:*?"<>|#' '_' | tr '\n\r' ' ' | sed 's/^[ .]*//; s/[ .]*$//' | cut -c 1-50)
    [ -z "${CLEAN_TITLE}" ] && CLEAN_TITLE="${STR_DEFAULT_TITLE}"

    SHORT_ID=$(echo "${CARD_ID}" | cut -c 1-8)
    TARGET_FILENAME="${DATE_STR} - ${CLEAN_TITLE}.md"

    # Remove previous temporary or renamed placeholder note for this card
    for EXISTING_FILE in "${DEST_NOTES}/${DATE_STR} - "*.md; do
        [ -f "${EXISTING_FILE}" ] || continue
        if grep -q "id: ${CARD_ID}" "${EXISTING_FILE}" 2>/dev/null; then
            EXISTING_NAME=$(basename "${EXISTING_FILE}")
            if [ "${EXISTING_NAME}" != "${TARGET_FILENAME}" ]; then
                rm -f "${EXISTING_FILE}" 2>/dev/null
                log "Cleaned old temporary note: ${EXISTING_NAME}"
            fi
        fi
    done

    # Collision resolution: if target filename already exists for a different card ID
    if [ -f "${DEST_NOTES}/${TARGET_FILENAME}" ] && ! grep -q "id: ${CARD_ID}" "${DEST_NOTES}/${TARGET_FILENAME}" 2>/dev/null; then
        TARGET_FILENAME="${DATE_STR} - ${CLEAN_TITLE} - ${SHORT_ID}.md"
    fi

    TARGET_FILE="${DEST_NOTES}/${TARGET_FILENAME}"
    TMP_NOTE="${TMP_DIR}/note.md"
    rm -f "${TMP_NOTE}" 2>/dev/null

    # Render Markdown note
    DISPLAY_TITLE="${TITLE}"
    [ -z "${DISPLAY_TITLE}" ] && DISPLAY_TITLE="${STR_DEFAULT_TITLE}"

    cat <<EOF > "${TMP_NOTE}"
---
id: ${CARD_ID}
type: ${CARD_TYPE}
created: ${DATE_ISO}
tags:
  - ${NOTE_TAG}
---

# ${DISPLAY_TITLE}
EOF

    if [ -f "${TMP_DIR}/cards/${CARD_ID}.summary" ]; then
        SUMMARY=$(cat "${TMP_DIR}/cards/${CARD_ID}.summary" 2>/dev/null)
        if [ -n "${SUMMARY}" ]; then
            ESCAPED_SUMMARY=$(echo "${SUMMARY}" | sed 's/^/> /')
            cat <<EOF >> "${TMP_NOTE}"

> [!summary] ${STR_SUMMARY}
${ESCAPED_SUMMARY}
EOF
        fi
    fi

    if [ -f "${TMP_DIR}/cards/${CARD_ID}.note_text" ]; then
        NOTE_TEXT=$(cat "${TMP_DIR}/cards/${CARD_ID}.note_text" 2>/dev/null)
        if [ -n "${NOTE_TEXT}" ]; then
            cat <<EOF >> "${TMP_NOTE}"

### 📝 ${STR_NOTE}
${NOTE_TEXT}
EOF
        fi
    fi

    # Tasks / Action items
    if [ -f "${TMP_DIR}/cards/${CARD_ID}.events" ]; then
        EVENTS_CONTENT=$(cat "${TMP_DIR}/cards/${CARD_ID}.events" 2>/dev/null)
        if [ -n "${EVENTS_CONTENT}" ]; then
            cat <<EOF >> "${TMP_NOTE}"

### ✅ ${STR_TASKS}
${EVENTS_CONTENT}
EOF
        fi
    fi

    if [ -f "${TMP_DIR}/cards/${CARD_ID}.transcription" ]; then
        TRANSCRIPTION=$(cat "${TMP_DIR}/cards/${CARD_ID}.transcription" 2>/dev/null)
        if [ -n "${TRANSCRIPTION}" ]; then
            cat <<EOF >> "${TMP_NOTE}"

### 🎙️ ${STR_TRANSCRIPT}
${TRANSCRIPTION}
EOF
        fi
    fi

    if [ -n "${AUDIO_FILENAME}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

### 🎧 ${STR_AUDIO}
![[${AUDIO_FILENAME}]]
EOF
    fi

    if [ -n "${IMG_FILENAME}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

### 🖼️ ${STR_SCREENSHOT}
![[${IMG_FILENAME}]]
EOF
    fi

    # AI Analysis Sections
    for A_META in "${TMP_DIR}/cards/${CARD_ID}".a_*.meta; do
        [ -f "${A_META}" ] || continue
        A_CONTENT_FILE="${A_META%.meta}.content"
        [ -f "${A_CONTENT_FILE}" ] || continue

        A_TYPE=$(grep '^A_TYPE=' "${A_META}" 2>/dev/null | cut -d'=' -f2-)
        A_TITLE=$(grep '^A_TITLE=' "${A_META}" 2>/dev/null | cut -d'=' -f2-)
        A_TIME=$(grep '^A_TIME=' "${A_META}" 2>/dev/null | cut -d'=' -f2-)
        A_CONTENT=$(cat "${A_CONTENT_FILE}" 2>/dev/null)
        [ -z "${A_CONTENT}" ] && continue

        case "${A_TYPE}" in
            BULLET_POINTS)
                [ -z "${A_TITLE}" ] && A_TITLE="${STR_ANALYSIS}"
                FORMATTED_BULLETS=$(echo "${A_CONTENT}" | sed '/^[[:space:]]*$/d; s/^[[:space:]]*[-*•]\{0,1\}[[:space:]]*/- /')
                cat <<EOF >> "${TMP_NOTE}"

### 📌 ${A_TITLE}
${FORMATTED_BULLETS}
EOF
                ;;
            INFO_EXTRACT)
                [ -z "${A_TITLE}" ] && A_TITLE="${STR_EXTRACTED_INFO}"
                FORMATTED_CONTENT=$(echo "${A_CONTENT}" | sed 's/^/> /')
                cat <<EOF >> "${TMP_NOTE}"

> [!info] ${A_TITLE}
${FORMATTED_CONTENT}
EOF
                ;;
            MEETING_MAIN_TOPIC)
                [ -z "${A_TITLE}" ] && A_TITLE="${STR_KEY_TOPICS}"
                cat <<EOF >> "${TMP_NOTE}"

### 🎯 ${A_TITLE}
${A_CONTENT}
EOF
                ;;
            MEETING_KEY_TOPIC_ANALYSIS)
                HEADER="${A_TITLE}"
                [ -n "${A_TIME}" ] && HEADER="${HEADER} (${A_TIME})"
                [ -z "${HEADER}" ] && HEADER="${STR_ANALYSIS}"
                FORMATTED_CONTENT=$(echo "${A_CONTENT}" | sed 's/^/> /')
                cat <<EOF >> "${TMP_NOTE}"

> [!abstract] ${HEADER}
${FORMATTED_CONTENT}
EOF
                ;;
            MEETING_EMOTIONAL_SUMMARY|FREEFORM)
                [ -z "${A_TITLE}" ] && A_TITLE="${STR_SUMMARY}"
                FORMATTED_CONTENT=$(echo "${A_CONTENT}" | sed 's/^/> /')
                cat <<EOF >> "${TMP_NOTE}"

> [!note] ${A_TITLE}
${FORMATTED_CONTENT}
EOF
                ;;
            ANSWER)
                FORMATTED_CONTENT=$(echo "${A_CONTENT}" | sed 's/^/> /')
                cat <<EOF >> "${TMP_NOTE}"

> [!faq] Q&A
${FORMATTED_CONTENT}
EOF
                ;;
        esac
    done

    cp -f "${TMP_NOTE}" "${TARGET_FILE}" 2>/dev/null
    chmod 660 "${TARGET_FILE}" 2>/dev/null
    rm -f "${TMP_NOTE}" 2>/dev/null

    log "Synced: ${TARGET_FILENAME}"

    # Update state file with maximum timestamp
    NEW_STATE="${UPDATE_TIME}"
    if [ -z "${NEW_STATE}" ] || [ "${NEW_STATE}" = "0" ]; then
        NEW_STATE="${CREATE_TIME}"
    elif [ -n "${CREATE_TIME}" ] && [ "${CREATE_TIME}" -gt "${NEW_STATE}" ] 2>/dev/null; then
        NEW_STATE="${CREATE_TIME}"
    fi
    if [ -n "${MAX_EV_TIME}" ] && [ "${MAX_EV_TIME}" -gt "${NEW_STATE}" ] 2>/dev/null; then
        NEW_STATE="${MAX_EV_TIME}"
    fi
    if [ -n "${NEW_STATE}" ]; then
        CUR_SAVED=$(cat "${STATE_FILE}" 2>/dev/null || echo 0)
        case "${CUR_SAVED}" in
            ''|*[!0-9]*) CUR_SAVED=0 ;;
        esac
        if [ "${NEW_STATE}" -gt "${CUR_SAVED}" ] 2>/dev/null; then
            echo "${NEW_STATE}" > "${STATE_FILE}"
        fi
    fi
done

log "Sync completed. State updated: $(cat "${STATE_FILE}" 2>/dev/null)"
