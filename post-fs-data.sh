#!/system/bin/sh
MODDIR=${0%/*}
PATH="$PATH:/data/adb/ksu/bin"
MARKER="/data/adb/lh8n_stability_svc_ver"
TARGET_VER="102"

# Bind-mount module overlays explicitly so KernelSU Next v3 without a metamodule applies them cleanly
bind_override() {
    rel="$1"
    dst="$2"
    ctx="$3"
    mode="$4"
    owner="$5"
    src=""
    if [ -f "$MODDIR/$rel" ]; then
        src="$MODDIR/$rel"
    elif [ -f "$MODDIR/system/$rel" ]; then
        src="$MODDIR/system/$rel"
    fi
    [ -n "$src" ] && [ -f "$dst" ] || return 0
    [ -n "$owner" ] && chown "$owner" "$src" 2>/dev/null
    [ -n "$mode" ] && chmod "$mode" "$src" 2>/dev/null
    [ -n "$ctx" ] && chcon "$ctx" "$src" 2>/dev/null
    if ! cmp -s "$src" "$dst" 2>/dev/null; then
        mount --bind "$src" "$dst" 2>/dev/null
    fi
}

bind_override "system/framework/services.jar" "/system/framework/services.jar" "u:object_r:system_file:s0" "0644" "0:0"
bind_override "system_ext/etc/selinux/system_ext_mac_permissions.xml" "/system_ext/etc/selinux/system_ext_mac_permissions.xml" "u:object_r:mac_perms_file:s0" "0644" "0:0"
bind_override "product/etc/selinux/product_mac_permissions.xml" "/product/etc/selinux/product_mac_permissions.xml" "u:object_r:mac_perms_file:s0" "0644" "0:0"
bind_override "vendor/bin/01_lh8n_sysfs.sh" "/vendor/bin/01_lh8n_sysfs.sh" "u:object_r:vendor_file:s0" "0755" "0:2000"

# Fix unlabeled SELinux file context on /system/etc/selinux/plat_mac_permissions.xml (ro erofs)
PLAT_MAC_DST="/system/etc/selinux/plat_mac_permissions.xml"
PLAT_MAC_SRC="$MODDIR/.cache_plat_mac_permissions.xml"
if [ -f "$PLAT_MAC_DST" ] && ! grep -q " $PLAT_MAC_DST " /proc/mounts 2>/dev/null; then
    if [ ! -f "$PLAT_MAC_SRC" ] || ! cmp -s "$PLAT_MAC_DST" "$PLAT_MAC_SRC" 2>/dev/null; then
        cp "$PLAT_MAC_DST" "$PLAT_MAC_SRC" 2>/dev/null
    fi
    if [ -s "$PLAT_MAC_SRC" ]; then
        chown 0:0 "$PLAT_MAC_SRC" 2>/dev/null
        chmod 0644 "$PLAT_MAC_SRC" 2>/dev/null
        chcon u:object_r:mac_perms_file:s0 "$PLAT_MAC_SRC" 2>/dev/null
        mount --bind "$PLAT_MAC_SRC" "$PLAT_MAC_DST" 2>/dev/null
    fi
fi

# Refresh ART dalvik-cache AFTER bind-mounting patched services.jar when module version changes
CUR_VER=""
[ -f "$MARKER" ] && IFS= read -r CUR_VER < "$MARKER" 2>/dev/null
if [ "$CUR_VER" != "$TARGET_VER" ]; then
    rm -f /data/misc/apexdata/com.android.art/dalvik-cache/arm64/system@framework@services.jar@classes.* 2>/dev/null
    echo "$TARGET_VER" > "$MARKER"
    chmod 0600 "$MARKER" 2>/dev/null
fi

[ -d /product/priv-app/LightBelt ] && chcon -R u:object_r:system_file:s0 /product/priv-app/LightBelt 2>/dev/null

# Lock dangerous sysfs nodes immediately before apps start
chmod 0000 /sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat 2>/dev/null

for node in /sys/class/leds/aw22xxx_led/rgb /sys/devices/platform/11d21000.i2c/i2c-2/2-006a/leds/aw22xxx_led/rgb; do
    if [ -e "$node" ]; then
        chown root:system "$node" 2>/dev/null
        chmod 0640 "$node" 2>/dev/null
    fi
done

# Remove dead gamedriver and contradicting donor zram-disable properties
if command -v resetprop >/dev/null 2>&1; then
    resetprop -d ro.gfx.driver.0 2>/dev/null
    resetprop -d vendor.zram.disable 2>/dev/null
fi

