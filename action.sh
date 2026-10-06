#!/system/bin/sh
# ==============================================================================
# KernelSU / APatch Action Script
# Executed when user taps the [ACTION] button in KernelSU Manager
# Non-interactive, prints status & sync results, exits cleanly.
# ==============================================================================

echo "=================================================="
echo "  Nothing Essential Space -> Obsidian Sync"
echo "=================================================="
echo ""

# 1. Check inotifyd daemon status
echo "🔍 Checking background service..."
if ps -ef | grep inotifyd | grep ntessentialspace | grep -v grep >/dev/null 2>&1; then
    echo "   ✓ Background watcher (inotifyd) is ACTIVE"
else
    echo "   ⚠️ Background watcher is not running (will start after unlock)"
fi

echo ""
echo "⚡ Triggering sync now..."
echo "--------------------------------------------------"

if [ -f "/data/adb/essential-sync/sync.sh" ]; then
    sh /data/adb/essential-sync/sync.sh
elif [ -f "${0%/*}/sync.sh" ]; then
    sh "${0%/*}/sync.sh"
else
    echo "❌ Error: sync.sh script not found!"
    exit 1
fi

echo "--------------------------------------------------"
echo "✓ Sync completed successfully."
echo "=================================================="

exit 0
