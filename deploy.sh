#!/bin/bash
# ==============================================================================
# Deploy script for Nothing Essential Sync to Nothing Phone 3a via ADB
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="/home/melih/Android/Sdk/platform-tools/adb"
DEVICE="00153154K003066"

echo "=== Nothing Essential Space -> Obsidian Kurulumu Başlatılıyor ==="

# 1. Cihaz kontrolü
if ! $ADB -s $DEVICE get-state >/dev/null 2>&1; then
    echo "Hata: Cihaz ($DEVICE) bağlı değil veya yetkilendirilmemiş!"
    exit 1
fi

echo "✓ Cihaz tespit edildi: Nothing Phone 3a ($DEVICE)"

# 2. Telefonda dizinleri hazırla
$ADB -s $DEVICE shell "su -c 'mkdir -p /data/adb/essential-sync/bin /data/adb/service.d'"
echo "✓ Dizinler hazırlandı: /data/adb/essential-sync/bin"

# 3. Dosyaları /data/local/tmp üzerinden kopyala (Doğrudan su alanına atmak için)
echo "→ Dosyalar telefona aktarılıyor..."
$ADB -s $DEVICE push "$SCRIPT_DIR/bin/sqlite3" /data/local/tmp/sqlite3_tmp
$ADB -s $DEVICE push "$SCRIPT_DIR/sync.sh" /data/local/tmp/sync_tmp.sh
$ADB -s $DEVICE push "$SCRIPT_DIR/essential_sync_service.sh" /data/local/tmp/service_tmp.sh

# 4. Root ile nihai konumlara yerleştir ve izinleri ayarla
$ADB -s $DEVICE shell "su -c '
mv -f /data/local/tmp/sqlite3_tmp /data/adb/essential-sync/bin/sqlite3
chmod 755 /data/adb/essential-sync/bin/sqlite3

mv -f /data/local/tmp/sync_tmp.sh /data/adb/essential-sync/sync.sh
chmod 755 /data/adb/essential-sync/sync.sh

mv -f /data/local/tmp/service_tmp.sh /data/adb/service.d/essential_sync.sh
chmod 755 /data/adb/service.d/essential_sync.sh

# Hedef Obsidian klasörlerinin varlığından emin ol
mkdir -p /storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/00-Zettelkasten
mkdir -p /storage/emulated/0/Sync/Obsidian-Vaults/Personal-Obsidian/99-index/Files
'"

echo "✓ Dosyalar yerleştirildi ve izinler ayarlandı (755)."

# 5. Doğrulama
echo "=== Kurulum Doğrulanıyor ==="
$ADB -s $DEVICE shell "su -c '
ls -la /data/adb/essential-sync/
ls -la /data/adb/essential-sync/bin/
ls -la /data/adb/service.d/essential_sync.sh
/data/adb/essential-sync/bin/sqlite3 --version
'"

echo "✓ Kurulum başarıyla tamamlandı!"
