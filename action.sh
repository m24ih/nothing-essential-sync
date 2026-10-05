#!/system/bin/sh
# ==============================================================================
# KernelSU / APatch Action Script
# Executed when user taps the [ACTION] button in KernelSU Manager
# ==============================================================================

clear 2>/dev/null || true
echo "=================================================="
echo "  Nothing Essential Space -> Obsidian Sync"
echo "  Quick Action Menu"
echo "=================================================="
echo ""
echo "  [1] ⚡ Run Sync Now"
echo "  [2] 🧙 Interactive Setup Wizard"
echo "  [3] 📜 View Recent Activity Logs"
echo "  [4] 🔍 Check Service Daemon Status"
echo ""
printf "Select option [1]: "
read -r CHOICE

case "$CHOICE" in
    2)
        sh /data/adb/essential-sync/setup.sh
        ;;
    3)
        echo ""
        echo "=== Activity Logs (Last 30 lines) ==="
        tail -n 30 /data/adb/essential-sync/sync.log 2>/dev/null || echo "No logs found."
        echo ""
        ;;
    4)
        echo ""
        echo "=== Daemon Process Status ==="
        ps -ef | grep inotifyd | grep -v grep || echo "Warning: inotifyd is NOT running."
        echo ""
        ;;
    *)
        echo ""
        echo "Running instant sync..."
        sh /data/adb/essential-sync/sync.sh
        echo ""
        echo "✓ Sync execution finished."
        ;;
esac
