# ==============================================================================
# Magisk / KernelSU / APatch Module Installation Script
# ==============================================================================

SKIPUNZIP=0

ui_print "***************************************************"
ui_print "  Nothing Essential Space -> Obsidian Sync Engine "
ui_print "  Author: Melih Ak (@m24ih)                       "
ui_print "  Version: v1.0.0                                 "
ui_print "***************************************************"

# 1. Device check
ui_print "- Checking device..."
PACKAGE_EXISTS=$(pm path com.nothing.ntessentialspace 2>/dev/null)
if [ -z "$PACKAGE_EXISTS" ]; then
    ui_print "! Warning: com.nothing.ntessentialspace was not detected."
    ui_print "! This module requires Nothing OS Essential Space."
else
    ui_print "✓ Nothing Essential Space detected."
fi

# 2. Extract and setup permissions
ui_print "- Setting up permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/bin/sqlite3" 0 0 0755
set_perm "$MODPATH/sync.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/setup.sh" 0 0 0755

# 3. Create runtime storage if not existing
mkdir -p /data/adb/essential-sync/bin 2>/dev/null

# Link binaries and scripts to /data/adb/essential-sync for persistent daemon/CLI use
cp -f "$MODPATH/bin/sqlite3" /data/adb/essential-sync/bin/sqlite3
cp -f "$MODPATH/sync.sh" /data/adb/essential-sync/sync.sh
cp -f "$MODPATH/setup.sh" /data/adb/essential-sync/setup.sh
chmod 755 /data/adb/essential-sync/bin/sqlite3 /data/adb/essential-sync/sync.sh /data/adb/essential-sync/setup.sh

# Create initial config if it doesn't already exist
if [ ! -f /data/adb/essential-sync/config.env ]; then
    ui_print "- Creating default configuration..."
    cp -f "$MODPATH/config.env" /data/adb/essential-sync/config.env
    chmod 644 /data/adb/essential-sync/config.env
fi

ui_print "***************************************************"
ui_print "  Installation Complete!                           "
ui_print "  - Open WebUI in KernelSU / MMRL to configure     "
ui_print "  - Or run: su -c 'sh /data/adb/essential-sync/setup.sh'"
ui_print "***************************************************"
