#!/system/bin/sh
# ==============================================================================
# Module Service Starter (KernelSU / Magisk / APatch)
# ==============================================================================

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

# 3. FUSE depolama montajının (/storage/emulated/0) tam oturması için kısa bekleme
sleep 5

if [ ! -f "${SYNC_SCRIPT}" ]; then
    SYNC_SCRIPT="${MODDIR}/sync.sh"
fi

if [ ! -f "${SYNC_SCRIPT}" ]; then
    exit 0
fi

chmod 755 "${SYNC_SCRIPT}" 2>/dev/null
mkdir -p "${BASE_DIR}"

# 4. Varsa eski inotifyd süreçlerini temizle
pkill -f "inotifyd.*${DB_DIR}" 2>/dev/null || true

# 5. Başlangıçta bekleyen notları senkronize et
sh "${SYNC_SCRIPT}" >> "${BASE_DIR}/daemon.log" 2>&1

# 6. inotify ile anlık olay tetikleyiciyi arka planda başlat (0% CPU, anlık uyandırma)
toybox inotifyd "${SYNC_SCRIPT}" "${DB_DIR}:wc" >> "${BASE_DIR}/daemon.log" 2>&1 &

# 7. Dayanıklılık için 15 dakikalık periyodik fallback döngüsü
while true; do
    sleep 900
    sh "${SYNC_SCRIPT}" >> "${BASE_DIR}/daemon.log" 2>&1
done
