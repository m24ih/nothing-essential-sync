#!/system/bin/sh
# ==============================================================================
# Nothing Phone Essential Space -> Obsidian One-Way Sync Engine
# Device: Nothing Phone 3a (Android 17 / Nothing OS 5.0)
# Mode: 100% READ-ONLY on Essential Space database and files
# Target: /storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian
# ==============================================================================

set -u

BASE_DIR="/data/adb/essential-sync"
SQLITE_BIN="${BASE_DIR}/bin/sqlite3"
STATE_FILE="${BASE_DIR}/last_sync_time.txt"
LOG_FILE="${BASE_DIR}/sync.log"

SOURCE_DB_DIR="/data/data/com.nothing.ntessentialspace/databases"
SOURCE_DB="${SOURCE_DB_DIR}/essential_space_database"
SOURCE_FILES_DIR="/data/data/com.nothing.ntessentialspace/files"

# Konfigürasyon Yükleme
CONFIG_FILE="${BASE_DIR}/config.env"
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${CONFIG_FILE}"
fi

DEST_NOTES="${DEST_NOTES:-/storage/emulated/0/Documents/EssentialSpaceNotes/00-Zettelkasten}"
DEST_ATTACHMENTS="${DEST_ATTACHMENTS:-/storage/emulated/0/Documents/EssentialSpaceNotes/attachments}"
TIME_FORMAT="${TIME_FORMAT:-%Y-%m-%d %H.%M}"
NOTE_TAG="${NOTE_TAG:-inbox/essential-space}"
NOTE_LANG="${NOTE_LANG:-auto}"

# Sistem dili algılama (persist.sys.locale -> ro.product.locale -> fallback: en)
DETECTED_LANG="en"
if [ "${NOTE_LANG}" = "auto" ] || [ -z "${NOTE_LANG}" ]; then
    LOCALE_PROP=$(getprop persist.sys.locale 2>/dev/null)
    [ -z "${LOCALE_PROP}" ] && LOCALE_PROP=$(getprop ro.product.locale 2>/dev/null)
    case "${LOCALE_PROP}" in
        tr*|TR*) DETECTED_LANG="tr" ;;
        de*|DE*) DETECTED_LANG="de" ;;
        fr*|FR*) DETECTED_LANG="fr" ;;
        es*|ES*) DETECTED_LANG="es" ;;
        it*|IT*) DETECTED_LANG="it" ;;
        ru*|RU*) DETECTED_LANG="ru" ;;
        ja*|JA*) DETECTED_LANG="ja" ;;
        zh*|ZH*) DETECTED_LANG="zh" ;;
        *)       DETECTED_LANG="en" ;;
    esac
else
    DETECTED_LANG="${NOTE_LANG}"
fi

case "${DETECTED_LANG}" in
    tr)
        STR_SUMMARY="AI Özeti"
        STR_NOTE="Not"
        STR_TRANSCRIPT="Ses Dökümü"
        STR_AUDIO="Ses Kaydı"
        STR_SCREENSHOT="Ekran Görüntüsü"
        STR_DEFAULT_TITLE="Essential Not"
        STR_SYNCED="Senkronize edildi"
        STR_COMPLETED="Senkronizasyon tamamlandı. Durum güncellendi"
        ;;
    de)
        STR_SUMMARY="KI-Zusammenfassung"
        STR_NOTE="Notiz"
        STR_TRANSCRIPT="Sprachtranskript"
        STR_AUDIO="Audioaufnahme"
        STR_SCREENSHOT="Screenshot"
        STR_DEFAULT_TITLE="Essential Notiz"
        STR_SYNCED="Synchronisiert"
        STR_COMPLETED="Synchronisierung abgeschlossen. Status aktualisiert"
        ;;
    fr)
        STR_SUMMARY="Résumé IA"
        STR_NOTE="Note"
        STR_TRANSCRIPT="Transcription vocale"
        STR_AUDIO="Enregistrement audio"
        STR_SCREENSHOT="Capture d'écran"
        STR_DEFAULT_TITLE="Note Essential"
        STR_SYNCED="Synchronisé"
        STR_COMPLETED="Synchronisation terminée. État mis à jour"
        ;;
    es)
        STR_SUMMARY="Resumen de IA"
        STR_NOTE="Nota"
        STR_TRANSCRIPT="Transcripción de voz"
        STR_AUDIO="Grabación de audio"
        STR_SCREENSHOT="Captura de pantalla"
        STR_DEFAULT_TITLE="Nota Essential"
        STR_SYNCED="Sincronizado"
        STR_COMPLETED="Sincronización completada. Estado actualizado"
        ;;
    *)
        # Default (en)
        STR_SUMMARY="AI Summary"
        STR_NOTE="Note"
        STR_TRANSCRIPT="Voice Transcript"
        STR_AUDIO="Audio Recording"
        STR_SCREENSHOT="Screenshot"
        STR_DEFAULT_TITLE="Essential Note"
        STR_SYNCED="Synced"
        STR_COMPLETED="Sync completed. State updated"
        ;;
esac

LOCK_FILE="/data/local/tmp/essential_sync.lock"

# 0. Paralel veya çifte tetiklemeyi önleme kilidi
if [ -f "${LOCK_FILE}" ]; then
    OLD_PID=$(cat "${LOCK_FILE}" 2>/dev/null)
    if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "${LOCK_FILE}"

TMP_DIR="/data/local/tmp/essential_snap_$$"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 1. Kontroller
if [ ! -f "${SOURCE_DB}" ]; then
    log "UYARI: Essential Space veritabanı bulunamadı: ${SOURCE_DB}"
    rm -f "${LOCK_FILE}"
    exit 0
fi

if [ ! -x "${SQLITE_BIN}" ]; then
    log "HATA: sqlite3 ikili dosyası bulunamadı veya çalıştırılamıyor: ${SQLITE_BIN}"
    rm -f "${LOCK_FILE}"
    exit 1
fi

mkdir -p "${DEST_NOTES}" "${DEST_ATTACHMENTS}"

# 2. Snap-to-RAM (Nothing OS kütüğünü riske atmamak için RAM kopyası)
rm -rf "${TMP_DIR}" 2>/dev/null
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}" "${LOCK_FILE}"' EXIT INT TERM

cp "${SOURCE_DB}" "${TMP_DIR}/snap.db" 2>/dev/null || exit 1
[ -f "${SOURCE_DB}-wal" ] && cp "${SOURCE_DB}-wal" "${TMP_DIR}/snap.db-wal" 2>/dev/null
[ -f "${SOURCE_DB}-shm" ] && cp "${SOURCE_DB}-shm" "${TMP_DIR}/snap.db-shm" 2>/dev/null

SNAP_DB="${TMP_DIR}/snap.db"

# 3. Son senkronizasyon zamanını oku
LAST_SYNC=0
if [ -f "${STATE_FILE}" ]; then
    LAST_SYNC=$(cat "${STATE_FILE}" 2>/dev/null | tr -d '\r\n')
    case "${LAST_SYNC}" in
        ''|*[!0-9]*) LAST_SYNC=0 ;;
    esac
fi

# 4. Yeni veya henüz senkronize edilmemiş kartları çek
CARDS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT card_id, create_time, strftime('${TIME_FORMAT}', create_time/1000, 'unixepoch', 'localtime'), strftime('%Y-%m-%d %H:%M:%S', create_time/1000, 'unixepoch', 'localtime') FROM cards WHERE create_time > ${LAST_SYNC} AND soft_delete_at <= 0 ORDER BY create_time ASC;")

if [ -z "${CARDS}" ]; then
    # Yeni kart yok
    exit 0
fi

log "Yeni kartlar bulundu. Senkronizasyon başlatılıyor..."
SYNC_COUNT=0
CURRENT_MAX_TIME=${LAST_SYNC}

echo "${CARDS}" | while IFS='|' read -r CARD_ID CREATE_TIME DATE_STR DATE_ISO; do
    [ -z "${CARD_ID}" ] && continue

    TITLE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(title, '') FROM cards WHERE card_id = '${CARD_ID}';")
    SUMMARY=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(summary, '') FROM cards WHERE card_id = '${CARD_ID}';")
    CARD_TYPE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(type, 'NOTE') FROM cards WHERE card_id = '${CARD_ID}';")

    NOTE_TEXT=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type IN ('TEXT', 'NOTE_TEXT') LIMIT 1;")
    TRANSCRIPTION=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type = 'TRANSCRIPTION' LIMIT 1;")
    IMAGE_URI=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type = 'IMAGE' LIMIT 1;")
    AUDIO_URI=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type = 'AUDIO' LIMIT 1;")

    # Medya kopyalama (Görsel)
    IMG_FILENAME=""
    if [ -n "${IMAGE_URI}" ]; then
        IMG_SRC=$(echo "${IMAGE_URI}" | sed 's|^file://||')
        if [ -f "${IMG_SRC}" ]; then
            IMG_FILENAME=$(basename "${IMG_SRC}")
            cp -f "${IMG_SRC}" "${DEST_ATTACHMENTS}/${IMG_FILENAME}" 2>/dev/null
            chmod 660 "${DEST_ATTACHMENTS}/${IMG_FILENAME}" 2>/dev/null
        fi
    fi

    # Medya kopyalama (Ses)
    AUDIO_FILENAME=""
    if [ -n "${AUDIO_URI}" ]; then
        AUDIO_SRC=$(echo "${AUDIO_URI}" | sed 's|^file://||')
        if [ -f "${AUDIO_SRC}" ]; then
            AUDIO_FILENAME=$(basename "${AUDIO_SRC}")
            cp -f "${AUDIO_SRC}" "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
            chmod 660 "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
        fi
    fi

    # Dosya adı temizleme
    CLEAN_TITLE=$(echo "${TITLE}" | tr '/\\:*?"<>|#' '_' | tr '\n\r' ' ' | sed 's/^[ .]*//; s/[ .]*$//' | cut -c 1-50)
    if [ -z "${CLEAN_TITLE}" ]; then
        CLEAN_TITLE="${STR_DEFAULT_TITLE}"
    fi

    TARGET_FILENAME="${DATE_STR} - ${CLEAN_TITLE}.md"
    if [ -f "${DEST_NOTES}/${TARGET_FILENAME}" ]; then
        SHORT_ID=$(echo "${CARD_ID}" | cut -c 1-8)
        TARGET_FILENAME="${DATE_STR} - ${CLEAN_TITLE} - ${SHORT_ID}.md"
    fi

    TARGET_FILE="${DEST_NOTES}/${TARGET_FILENAME}"
    TMP_NOTE="${TMP_DIR}/note.md"
    rm -f "${TMP_NOTE}" 2>/dev/null

    # Markdown dosyasını oluştur
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

    if [ -n "${SUMMARY}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

> [!summary] ${STR_SUMMARY}
> ${SUMMARY}
EOF
    fi

    if [ -n "${NOTE_TEXT}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

### 📝 ${STR_NOTE}
${NOTE_TEXT}
EOF
    fi

    if [ -n "${TRANSCRIPTION}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

### 🎙️ ${STR_TRANSCRIPT}
${TRANSCRIPTION}
EOF
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

    cat <<EOF >> "${TMP_NOTE}"
EOF

    cp -f "${TMP_NOTE}" "${TARGET_FILE}" 2>/dev/null
    chmod 660 "${TARGET_FILE}" 2>/dev/null
    rm -f "${TMP_NOTE}" 2>/dev/null

    log "${STR_SYNCED}: ${TARGET_FILENAME}"

    # En yüksek zaman damgasını güncelle
    echo "${CREATE_TIME}" > "${STATE_FILE}"
done

log "${STR_COMPLETED}: $(cat "${STATE_FILE}" 2>/dev/null)"

