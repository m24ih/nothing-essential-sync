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
        STR_KEY_TOPICS="Ana Konu"
        STR_ANALYSIS="Analiz & Detaylar"
        STR_EXTRACTED_INFO="Önemli Bilgi"
        STR_TASKS="Görevler"
        LOG_WARN_NO_DB="UYARI: Essential Space veritabanı bulunamadı"
        LOG_ERR_NO_SQLITE="HATA: sqlite3 ikili dosyası bulunamadı veya çalıştırılamıyor"
        LOG_CARDS_FOUND="Yeni kartlar bulundu. Senkronizasyon başlatılıyor..."
        LOG_WAITING_AI="⏳ Nothing AI analizi bekleniyor"
        LOG_AI_TIMEOUT="⚠️ Nothing AI bekleme süresi doldu"
        LOG_AI_TIMEOUT_DESC="Kartlar mevcut haliyle senkronize ediliyor..."
        LOG_AI_DONE="✨ Nothing AI analizi tamamlandı"
        LOG_START_SYNC="Senkronizasyon başlatılıyor..."
        LOG_SYNCED="Senkronize edildi"
        LOG_COMPLETED="Senkronizasyon tamamlandı. Durum güncellendi"
        LOG_CLEANED_OLD="Temizlendi (Eski geçici not)"
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
        LOG_WARN_NO_DB="WARNUNG: Essential Space-Datenbank nicht gefunden"
        LOG_ERR_NO_SQLITE="FEHLER: sqlite3-Binärdatei nicht gefunden oder nicht ausführbar"
        LOG_CARDS_FOUND="Neue Karten gefunden. Synchronisierung wird gestartet..."
        LOG_WAITING_AI="⏳ Warte auf Nothing AI-Analyse"
        LOG_AI_TIMEOUT="⚠️ Nothing AI-Zeitüberschreitung"
        LOG_AI_TIMEOUT_DESC="Karten werden mit aktuellen Daten synchronisiert..."
        LOG_AI_DONE="✨ Nothing AI-Analyse abgeschlossen"
        LOG_START_SYNC="Synchronisierung wird gestartet..."
        LOG_SYNCED="Synchronisiert"
        LOG_COMPLETED="Synchronisierung abgeschlossen. Status aktualisiert"
        LOG_CLEANED_OLD="Bereinigt (Alte temporäre Notiz)"
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
        LOG_WARN_NO_DB="AVERTISSEMENT : Base de données Essential Space introuvable"
        LOG_ERR_NO_SQLITE="ERREUR : Exécutable sqlite3 introuvable ou non exécutable"
        LOG_CARDS_FOUND="Nouvelles cartes trouvées. Démarrage de la synchronisation..."
        LOG_WAITING_AI="⏳ En attente de l'analyse Nothing AI"
        LOG_AI_TIMEOUT="⚠️ Délai d'attente Nothing AI dépassé"
        LOG_AI_TIMEOUT_DESC="Synchronisation avec les données actuelles..."
        LOG_AI_DONE="✨ Analyse Nothing AI terminée"
        LOG_START_SYNC="Démarrage de la synchronisation..."
        LOG_SYNCED="Synchronisé"
        LOG_COMPLETED="Synchronisation terminée. État mis à jour"
        LOG_CLEANED_OLD="Nettoyé (Ancienne note temporaire)"
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
        LOG_WARN_NO_DB="ADVERTENCIA: Base de datos Essential Space no encontrada"
        LOG_ERR_NO_SQLITE="ERROR: Binario sqlite3 no encontrado o no ejecutable"
        LOG_CARDS_FOUND="Nuevas tarjetas encontradas. Iniciando sincronización..."
        LOG_WAITING_AI="⏳ Esperando análisis de Nothing AI"
        LOG_AI_TIMEOUT="⚠️ Tiempo de espera de Nothing AI agotado"
        LOG_AI_TIMEOUT_DESC="Sincronizando con los datos actuales..."
        LOG_AI_DONE="✨ Análisis de Nothing AI completado"
        LOG_START_SYNC="Iniciando sincronización..."
        LOG_SYNCED="Sincronizado"
        LOG_COMPLETED="Sincronización completada. Estado actualizado"
        LOG_CLEANED_OLD="Limpiado (Nota temporal anterior)"
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
        LOG_WARN_NO_DB="WARNING: Essential Space database not found"
        LOG_ERR_NO_SQLITE="ERROR: sqlite3 binary not found or not executable"
        LOG_CARDS_FOUND="New cards found. Starting sync..."
        LOG_WAITING_AI="⏳ Waiting for Nothing AI analysis"
        LOG_AI_TIMEOUT="⚠️ Nothing AI wait timeout"
        LOG_AI_TIMEOUT_DESC="Syncing cards with current data..."
        LOG_AI_DONE="✨ Nothing AI analysis completed"
        LOG_START_SYNC="Starting sync..."
        LOG_SYNCED="Synced"
        LOG_COMPLETED="Sync completed. State updated"
        LOG_CLEANED_OLD="Cleaned (Old temporary note)"
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
    log "${LOG_WARN_NO_DB}: ${SOURCE_DB}"
    rm -f "${LOCK_FILE}"
    exit 0
fi

if [ ! -x "${SQLITE_BIN}" ]; then
    log "${LOG_ERR_NO_SQLITE}: ${SQLITE_BIN}"
    rm -f "${LOCK_FILE}"
    exit 1
fi

mkdir -p "${DEST_NOTES}" "${DEST_ATTACHMENTS}"

# 2. Snap-to-RAM (Nothing OS kütüğünü riske atmamak için RAM kopyası)
rm -rf "${TMP_DIR}" 2>/dev/null
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"; rm -f "${LOCK_FILE}" 2>/dev/null' EXIT INT TERM

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

# 4. Henüz çözümlenmemiş geçici taslak/placeholder dosyaları tespit et
PLACEHOLDER_IDS=""
for PH in "${DEST_NOTES}"/*" - ${STR_DEFAULT_TITLE}.md" "${DEST_NOTES}"/*" - Essential Note.md" "${DEST_NOTES}"/*" - Essential Not.md"; do
    [ -f "${PH}" ] || continue
    PID=$(grep -m1 '^id: ' "${PH}" 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    if [ -n "${PID}" ]; then
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

# Yeni veya henüz güncellenmiş/çözümlenmemiş kartları çek
CARDS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT card_id, create_time, update_time, strftime('${TIME_FORMAT}', create_time/1000, 'unixepoch', 'localtime'), strftime('%Y-%m-%d %H:%M:%S', create_time/1000, 'unixepoch', 'localtime') FROM cards WHERE ${QUERY_FILTER} AND soft_delete_at <= 0 ORDER BY create_time ASC, update_time ASC;")

if [ -z "${CARDS}" ]; then
    # Yeni veya güncellenmiş kart yok
    exit 0
fi

# AI analizinin bitmesini bekleme mekanizması (Graceful Wait):
# Nothing OS görsel notları ~6-18 saniyede, ses kayıtlarını (Essential Record) ~60-80 saniyede analiz eder.
# Kart henüz analiz ediliyorsa (analysis_state = 0 veya summary/title henüz boşsa), AI bitene kadar bekle.
MAX_WAIT_SECONDS=150
POLL_INTERVAL=2
ELAPSED=0

while [ ${ELAPSED} -lt ${MAX_WAIT_SECONDS} ]; do
    PENDING_COUNT=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT count(*) FROM cards WHERE ${QUERY_FILTER} AND soft_delete_at <= 0 AND (analysis_state = 0 OR summary IS NULL OR trim(summary) = '' OR title IS NULL OR trim(title) = '');")
    if [ "${PENDING_COUNT}" = "0" ] || [ -z "${PENDING_COUNT}" ]; then
        break
    fi

    # Her 6 saniyede bir log bildirimi üret (WebUI Dashboard'da canlı akar)
    if [ $((ELAPSED % 6)) -eq 0 ]; then
        PENDING_TYPES=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT group_concat(type) FROM cards WHERE ${QUERY_FILTER} AND soft_delete_at <= 0 AND (analysis_state = 0 OR summary IS NULL OR trim(summary) = '' OR title IS NULL OR trim(title) = '');")
        log "${LOG_WAITING_AI} (${PENDING_TYPES}) [${ELAPSED}s/${MAX_WAIT_SECONDS}s]..."
    fi

    sleep ${POLL_INTERVAL}
    ELAPSED=$((ELAPSED + POLL_INTERVAL))

    # Güncel veritabanı durumunu RAM snap kopyasına yenile
    cp "${SOURCE_DB}" "${SNAP_DB}" 2>/dev/null
    [ -f "${SOURCE_DB}-wal" ] && cp "${SOURCE_DB}-wal" "${TMP_DIR}/snap.db-wal" 2>/dev/null
    [ -f "${SOURCE_DB}-shm" ] && cp "${SOURCE_DB}-shm" "${TMP_DIR}/snap.db-shm" 2>/dev/null
done

if [ ${ELAPSED} -gt 0 ]; then
    if [ ${ELAPSED} -ge ${MAX_WAIT_SECONDS} ]; then
        log "${LOG_AI_TIMEOUT} (${MAX_WAIT_SECONDS}s). ${LOG_AI_TIMEOUT_DESC}"
    else
        log "${LOG_AI_DONE} (${ELAPSED}s)! ${LOG_START_SYNC}"
    fi
    # Son güncel kart listesini tekrar çek
    CARDS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT card_id, create_time, update_time, strftime('${TIME_FORMAT}', create_time/1000, 'unixepoch', 'localtime'), strftime('%Y-%m-%d %H:%M:%S', create_time/1000, 'unixepoch', 'localtime') FROM cards WHERE ${QUERY_FILTER} AND soft_delete_at <= 0 ORDER BY create_time ASC, update_time ASC;")
fi

log "${LOG_CARDS_FOUND}"
SYNC_COUNT=0
CURRENT_MAX_TIME=${LAST_SYNC}

echo "${CARDS}" | while IFS='|' read -r CARD_ID CREATE_TIME UPDATE_TIME DATE_STR DATE_ISO; do
    [ -z "${CARD_ID}" ] && continue

    TITLE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(title, '') FROM cards WHERE card_id = '${CARD_ID}';")
    SUMMARY=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(summary, '') FROM cards WHERE card_id = '${CARD_ID}';")
    CARD_TYPE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(type, 'NOTE') FROM cards WHERE card_id = '${CARD_ID}';")

    NOTE_TEXT=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type IN ('TEXT', 'NOTE_TEXT') LIMIT 1;")
    TRANSCRIPTION=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type = 'TRANSCRIPTION' LIMIT 1;")
    IMAGE_URI=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type = 'IMAGE' LIMIT 1;")
    AUDIO_URI=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT data FROM card_resources WHERE card_id = '${CARD_ID}' AND raw_type IN ('AUDIO', 'RECORDING') LIMIT 1;")

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
            # Obsidian .aac uzantılı dosyaları yerel ses oynatıcısında oynatamaz.
            # Ancak Nothing OS bu kayıtları ISO MP42 (M4A) formatında üretir.
            # Uzantıyı .m4a yaparak Obsidian'da doğrudan oynatılabilir (HTML5 audio) hale getiriyoruz.
            case "${AUDIO_FILENAME}" in
                *.aac) AUDIO_FILENAME="${AUDIO_FILENAME%.aac}.m4a" ;;
            esac
            cp -f "${AUDIO_SRC}" "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
            chmod 660 "${DEST_ATTACHMENTS}/${AUDIO_FILENAME}" 2>/dev/null
        fi
    fi

    # Dosya adı temizleme
    CLEAN_TITLE=$(echo "${TITLE}" | tr '/\\:*?"<>|#' '_' | tr '\n\r' ' ' | sed 's/^[ .]*//; s/[ .]*$//' | cut -c 1-50)
    if [ -z "${CLEAN_TITLE}" ]; then
        CLEAN_TITLE="${STR_DEFAULT_TITLE}"
    fi

    SHORT_ID=$(echo "${CARD_ID}" | cut -c 1-8)
    TARGET_FILENAME="${DATE_STR} - ${CLEAN_TITLE}.md"

    # Varsa bu karta ait eski/farklı isimli dosyayı temizle (placeholder veya eski başlıklı dosya)
    for EXISTING_FILE in "${DEST_NOTES}/${DATE_STR} - "*.md; do
        [ -f "${EXISTING_FILE}" ] || continue
        if grep -q "id: ${CARD_ID}" "${EXISTING_FILE}" 2>/dev/null; then
            EXISTING_NAME=$(basename "${EXISTING_FILE}")
            if [ "${EXISTING_NAME}" != "${TARGET_FILENAME}" ]; then
                rm -f "${EXISTING_FILE}" 2>/dev/null
                log "${LOG_CLEANED_OLD}: ${EXISTING_NAME}"
            fi
        fi
    done

    if [ -f "${DEST_NOTES}/${TARGET_FILENAME}" ] && ! grep -q "id: ${CARD_ID}" "${DEST_NOTES}/${TARGET_FILENAME}" 2>/dev/null; then
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

    # Görevler / Yapılacaklar (card_events)
    EVENT_ROWS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT \"check\", CASE WHEN content IS NOT NULL AND trim(content) != '' THEN content ELSE title END, time, strftime('%Y-%m-%d', time/1000, 'unixepoch', 'localtime'), strftime('%H:%M', time/1000, 'unixepoch', 'localtime') FROM card_events WHERE card_id = '${CARD_ID}' AND deleted = 0 ORDER BY card_event_id ASC;")
    if [ -n "${EVENT_ROWS}" ]; then
        cat <<EOF >> "${TMP_NOTE}"

### ✅ ${STR_TASKS}
EOF
        NOTE_DAY=$(echo "${DATE_ISO}" | cut -d' ' -f1)
        echo "${EVENT_ROWS}" | while IFS='|' read -r EV_CHECK EV_TEXT EV_TIME EV_DATE EV_HM; do
            [ -z "${EV_TEXT}" ] && continue
            TASK_BOX="[ ]"
            [ "${EV_CHECK}" = "1" ] && TASK_BOX="[x]"
            TIME_SUFFIX=""
            if [ -n "${EV_TIME}" ] && [ "${EV_TIME}" -gt 0 ] 2>/dev/null; then
                if [ "${EV_DATE}" = "${NOTE_DAY}" ]; then
                    TIME_SUFFIX=" ⏰ ${EV_HM}"
                else
                    TIME_SUFFIX=" 📅 ${EV_DATE} ${EV_HM}"
                fi
            fi
            echo "- ${TASK_BOX} ${EV_TEXT}${TIME_SUFFIX}" >> "${TMP_NOTE}"
        done
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

    # AI Analiz Bölümleri (BULLET_POINTS, INFO_EXTRACT, MEETING_*, ANSWER, FREEFORM)
    ANALYSIS_IDS=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT card_analysis_id FROM card_analysis WHERE card_id = '${CARD_ID}' ORDER BY card_analysis_id ASC;")
    if [ -n "${ANALYSIS_IDS}" ]; then
        for AID in ${ANALYSIS_IDS}; do
            [ -z "${AID}" ] && continue
            A_TYPE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT raw_type FROM card_analysis WHERE card_analysis_id = '${AID}';")
            A_TITLE=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT CASE WHEN json_valid(metadata) THEN coalesce(json_extract(metadata, '$.title'), '') ELSE '' END FROM card_analysis WHERE card_analysis_id = '${AID}';")
            A_CONTENT=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT CASE WHEN json_valid(metadata) THEN coalesce(json_extract(metadata, '$.bulletPointItem'), json_extract(metadata, '$.content'), json_extract(metadata, '$.detailed_summary'), json_extract(metadata, '$.extractedInformation'), '') ELSE metadata END FROM card_analysis WHERE card_analysis_id = '${AID}';")
            A_TIME=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT CASE WHEN json_valid(metadata) THEN coalesce(json_extract(metadata, '$.timestamp_reference'), '') ELSE '' END FROM card_analysis WHERE card_analysis_id = '${AID}';")

            [ -z "${A_CONTENT}" ] && continue

            case "${A_TYPE}" in
                BULLET_POINTS)
                    [ -z "${A_TITLE}" ] && A_TITLE="${STR_ANALYSIS}"
                    FORMATTED_BULLETS=$(echo "${A_CONTENT}" | sed 's/^[[:space:]]*/- /')
                    cat <<EOF >> "${TMP_NOTE}"

### 📌 ${A_TITLE}
${FORMATTED_BULLETS}
EOF
                    ;;
                INFO_EXTRACT)
                    [ -z "${A_TITLE}" ] && A_TITLE="${STR_EXTRACTED_INFO}"
                    cat <<EOF >> "${TMP_NOTE}"

> [!info] ${A_TITLE}
> ${A_CONTENT}
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
                    cat <<EOF >> "${TMP_NOTE}"

> [!abstract] ${HEADER}
> ${A_CONTENT}
EOF
                    ;;
                MEETING_EMOTIONAL_SUMMARY|FREEFORM)
                    [ -z "${A_TITLE}" ] && A_TITLE="${STR_SUMMARY}"
                    cat <<EOF >> "${TMP_NOTE}"

> [!note] ${A_TITLE}
> ${A_CONTENT}
EOF
                    ;;
                ANSWER)
                    cat <<EOF >> "${TMP_NOTE}"

> [!faq] Q&A
> ${A_CONTENT}
EOF
                    ;;
            esac
        done
    fi

    cat <<EOF >> "${TMP_NOTE}"
EOF

    cp -f "${TMP_NOTE}" "${TARGET_FILE}" 2>/dev/null
    chmod 660 "${TARGET_FILE}" 2>/dev/null
    rm -f "${TMP_NOTE}" 2>/dev/null

    log "${LOG_SYNCED}: ${TARGET_FILENAME}"

    # En yüksek zaman damgasını güncelle
    MAX_EV_TIME=$("${SQLITE_BIN}" "${SNAP_DB}" "SELECT coalesce(max(update_time), 0) FROM card_events WHERE card_id = '${CARD_ID}' AND deleted = 0;")
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

log "${LOG_COMPLETED}: $(cat "${STATE_FILE}" 2>/dev/null)"


