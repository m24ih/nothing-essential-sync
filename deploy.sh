#!/bin/bash
# ==============================================================================
# Universal Deploy Script for Nothing Essential Sync via ADB
# Automatically sets up CLI engine, Service hook, and KernelSU/MMRL WebUI
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="/home/melih/Android/Sdk/platform-tools/adb"

# Auto-detect connected ADB device
DEVICE="${DEVICE:-$($ADB devices | grep -w "device" | head -n 1 | awk '{print $1}')}"

if [ -z "$DEVICE" ]; then
    echo "Hata: Bağlı ADB cihazı bulunamadı. Lütfen telefonun USB veya Kablosuz ADB ile bağlı olduğundan emin olun."
    exit 1
fi

echo "=== Nothing Essential Space -> Obsidian Kurulumu ==="
echo "✓ Hedef Cihaz: $DEVICE"

# 1. Dizinleri telefonda hazırla
$ADB -s "$DEVICE" shell "su -c '
mkdir -p /data/adb/essential-sync/bin
mkdir -p /data/adb/service.d
mkdir -p /data/adb/modules/nothing-essential-sync/webroot
mkdir -p /data/adb/modules/nothing-essential-sync/bin
'"

echo "→ Dosyalar telefona aktarılıyor..."

# 2. Dosyaları /data/local/tmp üzerinden güvenle aktar
$ADB -s "$DEVICE" push "$SCRIPT_DIR/bin/sqlite3" /data/local/tmp/sqlite3_tmp
$ADB -s "$DEVICE" push "$SCRIPT_DIR/sync.sh" /data/local/tmp/sync_tmp.sh
$ADB -s "$DEVICE" push "$SCRIPT_DIR/setup.sh" /data/local/tmp/setup_tmp.sh
$ADB -s "$DEVICE" push "$SCRIPT_DIR/config.env" /data/local/tmp/config_tmp.env
$ADB -s "$DEVICE" push "$SCRIPT_DIR/service.sh" /data/local/tmp/service_tmp.sh
$ADB -s "$DEVICE" push "$SCRIPT_DIR/action.sh" /data/local/tmp/action_tmp.sh
$ADB -s "$DEVICE" push "$SCRIPT_DIR/module.prop" /data/local/tmp/module_tmp.prop

# WebUI dosyalarını aktar
$ADB -s "$DEVICE" shell "su -c 'mkdir -p /data/local/tmp/webui_tmp'"
$ADB -s "$DEVICE" push "$SCRIPT_DIR/webroot/index.html" /data/local/tmp/webui_tmp/index.html
$ADB -s "$DEVICE" push "$SCRIPT_DIR/webroot/style.css" /data/local/tmp/webui_tmp/style.css
$ADB -s "$DEVICE" push "$SCRIPT_DIR/webroot/app.js" /data/local/tmp/webui_tmp/app.js

# 3. Root ile kalıcı konumlara yerleştir
$ADB -s "$DEVICE" shell "su -c '
# Motor dizini
mv -f /data/local/tmp/sqlite3_tmp /data/adb/essential-sync/bin/sqlite3
mv -f /data/local/tmp/sync_tmp.sh /data/adb/essential-sync/sync.sh
mv -f /data/local/tmp/setup_tmp.sh /data/adb/essential-sync/setup.sh
[ ! -f /data/adb/essential-sync/config.env ] && mv -f /data/local/tmp/config_tmp.env /data/adb/essential-sync/config.env || rm -f /data/local/tmp/config_tmp.env
chmod 755 /data/adb/essential-sync/bin/sqlite3 /data/adb/essential-sync/sync.sh /data/adb/essential-sync/setup.sh

# Service.d kancası
mv -f /data/local/tmp/service_tmp.sh /data/adb/service.d/essential_sync.sh
chmod 755 /data/adb/service.d/essential_sync.sh

# KernelSU / MMRL Modül & WebUI dizini
mv -f /data/local/tmp/module_tmp.prop /data/adb/modules/nothing-essential-sync/module.prop
mv -f /data/local/tmp/action_tmp.sh /data/adb/modules/nothing-essential-sync/action.sh
cp -f /data/adb/essential-sync/bin/sqlite3 /data/adb/modules/nothing-essential-sync/bin/sqlite3
cp -f /data/adb/essential-sync/sync.sh /data/adb/modules/nothing-essential-sync/sync.sh
cp -f /data/adb/essential-sync/setup.sh /data/adb/modules/nothing-essential-sync/setup.sh
cp -f /data/adb/service.d/essential_sync.sh /data/adb/modules/nothing-essential-sync/service.sh
cp -f /data/local/tmp/webui_tmp/* /data/adb/modules/nothing-essential-sync/webroot/
rm -rf /data/local/tmp/webui_tmp

chmod -R 755 /data/adb/modules/nothing-essential-sync/webroot
chmod 755 /data/adb/modules/nothing-essential-sync/*.sh /data/adb/modules/nothing-essential-sync/bin/*
'"

echo "✓ Dosyalar yerleştirildi ve izinler ayarlandı."
echo "✓ KernelSU / MMRL WebUI aktif: KernelSU Manager üzerinden doğrudan açılabilir."
echo "✓ Kurulum tamamlandı!"
