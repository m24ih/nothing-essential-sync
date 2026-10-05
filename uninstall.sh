#!/system/bin/sh
# ==============================================================================
# Uninstaller for Nothing Essential Sync
# Completely removes daemon and binaries, preserves user's Obsidian notes!
# ==============================================================================

# Kill running processes
pkill -f "inotifyd.*essential-sync" 2>/dev/null
pkill -f "essential_sync" 2>/dev/null

# Remove service hook
rm -f /data/adb/service.d/essential_sync.sh 2>/dev/null

# Remove engine directory
rm -rf /data/adb/essential-sync 2>/dev/null

echo "✓ Nothing Essential Sync has been completely uninstalled."
echo "  Note: Your Obsidian notes and media files were kept untouched."
