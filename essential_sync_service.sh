#!/system/bin/sh
# ==============================================================================
# KernelSU Service: Nothing Essential Space -> Obsidian Auto-Sync
# Path on device: /data/adb/service.d/essential_sync.sh
# ==============================================================================

# Boot tamamlanana kadar bekle
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

# FUSE ve depolama montajının oturması için kısa bekleme
sleep 10

BASE_DIR="/data/adb/essential-sync"
SYNC_SCRIPT="${BASE_DIR}/sync.sh"
DB_DIR="/data/data/com.nothing.ntessentialspace/databases"

if [ ! -f "${SYNC_SCRIPT}" ]; then
    exit 0
fi

chmod 755 "${SYNC_SCRIPT}"
chmod 755 "${BASE_DIR}/bin/sqlite3" 2>/dev/null

# 1. Başlangıçta bekleyen notları senkronize et
sh "${SYNC_SCRIPT}" >> "${BASE_DIR}/daemon.log" 2>&1

# 2. inotify ile anlık olay tetikleyiciyi başlat (0% CPU, anlık uyandırma)
if [ -d "${DB_DIR}" ]; then
    toybox inotifyd "${SYNC_SCRIPT}" "${DB_DIR}:wc" >> "${BASE_DIR}/daemon.log" 2>&1 &
fi

# 3. Dayanıklılık için 15 dakikalık periyodik fallback döngüsü
while true; do
    sleep 900
    sh "${SYNC_SCRIPT}" >> "${BASE_DIR}/daemon.log" 2>&1
done
