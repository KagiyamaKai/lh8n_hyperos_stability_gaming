#!/system/bin/sh
SKIPUNZIP=0

ui_print "***********************************************"
ui_print "*  TECNO LH8n HyperOS Stability & Gaming Fix  *"
ui_print "*             v1.0.4  (By Kagiyama)           *"
ui_print "***********************************************"

ui_print "- Setting module permissions & SELinux contexts..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
[ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
[ -f "$MODPATH/system/framework/services.jar" ] && chcon u:object_r:system_file:s0 "$MODPATH/system/framework/services.jar" 2>/dev/null || true
[ -f "$MODPATH/system/system_ext/etc/selinux/system_ext_mac_permissions.xml" ] && chcon u:object_r:mac_perms_file:s0 "$MODPATH/system/system_ext/etc/selinux/system_ext_mac_permissions.xml" 2>/dev/null || true
[ -f "$MODPATH/system/product/etc/selinux/product_mac_permissions.xml" ] && chcon u:object_r:mac_perms_file:s0 "$MODPATH/system/product/etc/selinux/product_mac_permissions.xml" 2>/dev/null || true
[ -f "$MODPATH/system/vendor/bin/01_lh8n_sysfs.sh" ] && {
    set_perm "$MODPATH/system/vendor/bin/01_lh8n_sysfs.sh" 0 2000 0755
    chcon u:object_r:vendor_file:s0 "$MODPATH/system/vendor/bin/01_lh8n_sysfs.sh" 2>/dev/null || true
}

# Mark stale ART dalvik-cache for cleanup in post-fs-data only if services.jar version changed
CUR_SVC_VER=""
[ -f /data/adb/lh8n_stability_svc_ver ] && IFS= read -r CUR_SVC_VER < /data/adb/lh8n_stability_svc_ver 2>/dev/null
if [ "$CUR_SVC_VER" != "102" ]; then
    rm -f /data/adb/lh8n_stability_svc_ver /data/misc/apexdata/com.android.art/dalvik-cache/arm64/system@framework@services.jar@classes.* 2>/dev/null || true
fi

# Apply safe runtime protections & tunables immediately
chmod 0000 /sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat 2>/dev/null || true
for node in /sys/class/leds/aw22xxx_led/rgb /sys/devices/platform/11d21000.i2c/i2c-2/2-006a/leds/aw22xxx_led/rgb; do
    if [ -e "$node" ]; then
        chown root:system "$node" 2>/dev/null || true
        chmod 0660 "$node" 2>/dev/null || true
    fi
done

# Start/restart zero-fork SysfsSettingsObserver if already booted
pkill -f "SysfsSettingsObserver" 2>/dev/null || true
if [ "$(getprop sys.boot_completed)" = "1" ] && [ -f "$MODPATH/lh8n_observer.dex" ]; then
    cd /
    nohup /system/bin/app_process -Djava.class.path="$MODPATH/lh8n_observer.dex" /system/bin SysfsSettingsObserver >/dev/null 2>&1 &
fi

ui_print "- Stability & Gaming module installed."
ui_print "- Reboot to activate SELinuxMMAC, IVirtualHal, & SurfaceFlinger fixes!"
ui_print "***********************************************"

