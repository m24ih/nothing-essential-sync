#!/system/bin/sh
# ==============================================================================
# Module Service Starter (KernelSU / Magisk / APatch)
# Power-Aware Daemon & Inotify Watcher
# ==============================================================================

export PATH="/data/adb/essential-sync/bin:/system/bin:/system/xbin:/apex/com.android.runtime/bin:${PATH:-}"
unset LD_LIBRARY_PATH

MODDIR="${0%/*}"
BASE_DIR="/data/adb/essential-sync"
SYNC_SCRIPT="${BASE_DIR}/sync.sh"
DB_DIR="/data/data/com.nothing.ntessentialspace/databases"
SOURCE_DB="${DB_DIR}/essential_space_database"
STATE_FILE="${BASE_DIR}/last_sync_time.txt"
PENDING_FLAG="${BASE_DIR}/pending_sync"
DAEMON_LOG="${BASE_DIR}/daemon.log"

# 1. Wait until Android boot is complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

# 2. Android File-Based Encryption (FBE) - Wait until user unlocks device for the first time
while [ ! -d "${DB_DIR}" ]; do
    sleep 3
done

# 3. Wait for FUSE storage mount (/storage/emulated/0) to be fully ready
while ! ls -d /storage/emulated/0 >/dev/null 2>&1; do
    sleep 3
done

# 4. Clean up stale locks and temporary residues
rm -rf /data/local/tmp/essential_sync.lock /data/local/tmp/essential_tmp_* /data/local/tmp/essential_sync_pending 2>/dev/null

# 5. Resolve sync script location and permissions
if [ ! -f "${SYNC_SCRIPT}" ]; then
    SYNC_SCRIPT="${MODDIR}/sync.sh"
fi

if [ ! -f "${SYNC_SCRIPT}" ]; then
    exit 0
fi

chmod 755 "${SYNC_SCRIPT}" 2>/dev/null
mkdir -p "${BASE_DIR}"

# 6. Log rotation helper (keep daemon log below 512 KB)
rotate_log() {
    if [ -f "${DAEMON_LOG}" ] && [ "$(wc -c < "${DAEMON_LOG}" 2>/dev/null || echo 0)" -gt 512000 ]; then
        tail -n 1000 "${DAEMON_LOG}" > "${DAEMON_LOG}.tmp" 2>/dev/null && mv -f "${DAEMON_LOG}.tmp" "${DAEMON_LOG}" 2>/dev/null
    fi
}

# 7. Display state detection helper: check if screen is active/awake
is_screen_on() {
    # Check via dumpsys window
    _WIN_STATE=$(dumpsys window 2>/dev/null | grep -m1 'mHoldingDisplaySuspendBlocker=')
    if [ -n "${_WIN_STATE}" ]; then
        if echo "${_WIN_STATE}" | grep -q 'true'; then
            return 0
        else
            return 1
        fi
    fi

    # Check via dumpsys display
    _DISP_STATE=$(dumpsys display 2>/dev/null | grep -m1 'mState=')
    if [ -n "${_DISP_STATE}" ]; then
        if echo "${_DISP_STATE}" | grep -q 'ON'; then
            return 0
        else
            return 1
        fi
    fi

    # Check via dumpsys power
    _PWR_STATE=$(dumpsys power 2>/dev/null | grep -m1 'mWakefulness=')
    if [ -n "${_PWR_STATE}" ]; then
        if echo "${_PWR_STATE}" | grep -q 'Awake'; then
            return 0
        else
            return 1
        fi
    fi

    # Fallback to screen on if command fails or state cannot be determined
    return 0
}

# 8. Early-exit mtime guard helper: check if SQLite DB was modified since last sync
is_db_modified() {
    # If state file does not exist, initial sync is required
    if [ ! -f "${STATE_FILE}" ]; then
        return 0
    fi

    # If pending sync flag exists, execution is required
    if [ -f "${PENDING_FLAG}" ] || [ -f "/data/local/tmp/essential_sync_pending" ]; then
        return 0
    fi

    # If database file does not exist, nothing to sync
    if [ ! -f "${SOURCE_DB}" ]; then
        return 1
    fi

    # Read recorded timestamp from STATE_FILE
    _RECORDED=$(cat "${STATE_FILE}" 2>/dev/null | tr -d '\r\n')
    case "${_RECORDED}" in
        ''|*[!0-9]*) _RECORDED=0 ;;
    esac

    # If state is 0, initial sync has not run yet
    if [ "${_RECORDED}" = "0" ]; then
        return 0
    fi

    # Convert millisecond timestamp to seconds if needed
    if [ ${#_RECORDED} -gt 10 ]; then
        _RECORDED_SEC="${_RECORDED%???}"
    else
        _RECORDED_SEC="${_RECORDED}"
    fi

    # Get DB and WAL modification times (epoch seconds)
    _DB_MTIME=$(stat -c %Y "${SOURCE_DB}" 2>/dev/null || echo 0)
    _WAL_MTIME=0
    if [ -f "${SOURCE_DB}-wal" ]; then
        _WAL_MTIME=$(stat -c %Y "${SOURCE_DB}-wal" 2>/dev/null || echo 0)
    fi

    _MAX_MTIME="${_DB_MTIME}"
    if [ "${_WAL_MTIME}" -gt "${_MAX_MTIME}" ] 2>/dev/null; then
        _MAX_MTIME="${_WAL_MTIME}"
    fi

    # If stat returned valid epoch mtime
    if [ "${_MAX_MTIME}" -gt 0 ] 2>/dev/null; then
        if [ "${_MAX_MTIME}" -gt "${_RECORDED_SEC}" ] 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    # Fallback using shell file test if stat is unavailable
    if [ "${SOURCE_DB}" -nt "${STATE_FILE}" ] || [ -f "${SOURCE_DB}-wal" -a "${SOURCE_DB}-wal" -nt "${STATE_FILE}" ]; then
        return 0
    fi

    return 1
}

# 9. Clean up any previous inotifyd instances monitoring DB_DIR
pkill -f "inotifyd.*${DB_DIR}" 2>/dev/null || true

# 10. Initial sync of pending notes on daemon startup
rotate_log
sh "${SYNC_SCRIPT}" >> "${DAEMON_LOG}" 2>&1
rm -f "${PENDING_FLAG}" "/data/local/tmp/essential_sync_pending" 2>/dev/null

# 11. Start background inotifyd event watcher (instant wakeup on DB changes, 0% idle CPU)
if command -v inotifyd >/dev/null 2>&1; then
    inotifyd "${SYNC_SCRIPT}" "${DB_DIR}:wc" >> "${DAEMON_LOG}" 2>&1 &
else
    toybox inotifyd "${SYNC_SCRIPT}" "${DB_DIR}:wc" >> "${DAEMON_LOG}" 2>&1 &
fi

# 12. Power-aware periodic fallback loop (120s screen-on vs 600s Doze/screen-off)
while true; do
    if is_screen_on; then
        INTERVAL=120
    else
        INTERVAL=600
    fi
    sleep "${INTERVAL}"

    rotate_log

    if is_db_modified; then
        sh "${SYNC_SCRIPT}" >> "${DAEMON_LOG}" 2>&1
        rm -f "${PENDING_FLAG}" "/data/local/tmp/essential_sync_pending" 2>/dev/null
    fi
done
