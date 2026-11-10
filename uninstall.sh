#!/system/bin/sh
# Kill running daemon
pkill -f "SysfsSettingsObserver" 2>/dev/null || true

# Clean up version markers and ART dalvik cache
rm -f /data/adb/lh8n_stability_svc_ver 2>/dev/null
rm -f /data/misc/apexdata/com.android.art/dalvik-cache/arm64/system@framework@services.jar@classes.* 2>/dev/null
rm -f /data/local/tmp/lh8n_observer.log 2>/dev/null


