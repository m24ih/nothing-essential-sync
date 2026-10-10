#!/system/bin/sh
# ==============================================================================
# Module Service Starter (KernelSU / Magisk / APatch)
# ==============================================================================

export PATH="/data/adb/essential-sync/bin:/system/bin:/system/xbin:/apex/com.android.runtime/bin:${PATH:-}"
unset LD_LIBRARY_PATH

MODDIR="${0%/*}"
BASE_DIR="/data/adb/essential-sync"
SYNC_SCRIPT="${BASE_DIR}/sync.sh"
DB_DIR="/data/data/com.nothing.ntessentialspace/databases"

# 1. Boot tamamlanana kadar bekle
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

# 2. Android File-Based Encryption (FBE) - Kullanıcı ilk kilidi açana kadar bekle
while [ ! -d "${DB_DIR}" ]; do
    sleep 3
done

# 3. FUSE depolama montajının (/storage/emulated/0) tam oturması için bekle
while ! ls -d /storage/emulated/0 >/dev/null 2>&1; do
    sleep 3
done

# 4. Eski kilit ve geçici kalıntıları temizle
rm -rf /data/local/tmp/essential_sync.lock /data/local/tmp/essential_tmp_* 2>/dev/null

if [ ! -f "${SYNC_SCRIPT}" ]; then
    SYNC_SCRIPT="${MODDIR}/sync.sh"
fi

if [ ! -f "${SYNC_SCRIPT}" ]; then
    exit 0
fi

chmod 755 "${SYNC_SCRIPT}" 2>/dev/null
mkdir -p "${BASE_DIR}"

DAEMON_LOG="${BASE_DIR}/daemon.log"
rotate_log() {
    if [ -f "${DAEMON_LOG}" ] && [ "$(wc -c < "${DAEMON_LOG}" 2>/dev/null || echo 0)" -gt 512000 ]; then
        tail -n 1000 "${DAEMON_LOG}" > "${DAEMON_LOG}.tmp" 2>/dev/null && mv -f "${DAEMON_LOG}.tmp" "${DAEMON_LOG}" 2>/dev/null
    fi
}

# 4. Varsa eski inotifyd süreçlerini temizle
pkill -f "inotifyd.*${DB_DIR}" 2>/dev/null || true

# 5. Başlangıçta bekleyen notları senkronize et
rotate_log
sh "${SYNC_SCRIPT}" >> "${DAEMON_LOG}" 2>&1

# 6. inotify ile anlık olay tetikleyiciyi arka planda başlat (0% CPU, anlık uyandırma)
toybox inotifyd "${SYNC_SCRIPT}" "${DB_DIR}:wc" >> "${DAEMON_LOG}" 2>&1 &

# 7. Dayanıklılık için 2 dakikalık periyodik fallback döngüsü
while true; do
    sleep 120
    rotate_log
    sh "${SYNC_SCRIPT}" >> "${DAEMON_LOG}" 2>&1
done
