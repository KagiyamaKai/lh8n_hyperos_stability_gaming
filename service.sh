#!/system/bin/sh
MODDIR=${0%/*}
PATH="$PATH:/data/adb/ksu/bin"

# Re-assert kernel crash guards after early init/module loading settles
chmod 0000 /sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat 2>/dev/null

for node in /sys/class/leds/aw22xxx_led/rgb /sys/devices/platform/11d21000.i2c/i2c-2/2-006a/leds/aw22xxx_led/rgb; do
    if [ -e "$node" ]; then
        chown root:system "$node" 2>/dev/null
        chmod 0640 "$node" 2>/dev/null
    fi
done

# Wait up to 120s for Android boot completion (including first-boot ART compile)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
    sleep 1
    i=$((i + 1))
done

# Launch zero-fork Settings Sync & Sysfs Watchdog under u:r:ksu:s0 (eliminates init AVC bursts)
pkill -f "SysfsSettingsObserver" 2>/dev/null || true
if [ -f "$MODDIR/lh8n_observer.dex" ]; then
    cd /
    nohup /system/bin/app_process -Djava.class.path="$MODDIR/lh8n_observer.dex" /system/bin SysfsSettingsObserver >/dev/null 2>&1 &
fi

# Re-assert once more post-boot in case vendor scripts touched permissions
chmod 0000 /sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat 2>/dev/null
for node in /sys/class/leds/aw22xxx_led/rgb /sys/devices/platform/11d21000.i2c/i2c-2/2-006a/leds/aw22xxx_led/rgb; do
    if [ -e "$node" ]; then
        chown root:system "$node" 2>/dev/null
        chmod 0640 "$node" 2>/dev/null
    fi
done

apply_tunings() {
    # 1. VM & ZRAM stability/gaming tuning (8GB RAM + LZ4 ZRAM)
    # Reduce premature swap thrashing and prevent direct-reclaim micro-stutters
    [ -w /proc/sys/vm/swappiness ] && echo 100 > /proc/sys/vm/swappiness 2>/dev/null
    [ -w /proc/sys/vm/watermark_scale_factor ] && echo 30 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    [ -w /proc/sys/vm/compaction_proactiveness ] && echo 0 > /proc/sys/vm/compaction_proactiveness 2>/dev/null
    [ -w /proc/sys/vm/page-cluster ] && echo 0 > /proc/sys/vm/page-cluster 2>/dev/null
    [ -w /proc/sys/vm/vfs_cache_pressure ] && echo 70 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    [ -w /proc/sys/vm/dirty_background_ratio ] && echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    [ -w /proc/sys/vm/dirty_ratio ] && echo 20 > /proc/sys/vm/dirty_ratio 2>/dev/null
    for mc in /dev/memcg/apps /dev/memcg/game /dev/memcg/protected-app /dev/memcg/system; do
        [ -w "$mc/memory.swappiness" ] && echo 60 > "$mc/memory.swappiness" 2>/dev/null
    done
    [ -w /dev/cpuset/dex2oat/cpus ] && echo 0-5 > /dev/cpuset/dex2oat/cpus 2>/dev/null
    command -v resetprop >/dev/null 2>&1 && resetprop dalvik.vm.background-dex2oat-threads 4 2>/dev/null

    # 2. UFS & dm-block queue latency tuning
    for b in /sys/block/sda /sys/block/sdb /sys/block/sdc /sys/block/mmcblk0 /sys/block/dm-*; do
        [ -d "$b/queue" ] || continue
        [ -w "$b/queue/iostats" ] && echo 0 > "$b/queue/iostats" 2>/dev/null
        [ -w "$b/queue/read_ahead_kb" ] && echo 512 > "$b/queue/read_ahead_kb" 2>/dev/null
    done

    # 3. Dynamic GPU DVFS & MediaTek GED Gaming Mode
    [ -w /sys/module/ged/parameters/ged_smart_boost ] && echo 1 > /sys/module/ged/parameters/ged_smart_boost 2>/dev/null
    [ -w /sys/module/ged/parameters/boost_gpu_enable ] && echo 1 > /sys/module/ged/parameters/boost_gpu_enable 2>/dev/null
    [ -w /sys/module/ged/parameters/g_fb_dvfs_threshold ] && echo 65 > /sys/module/ged/parameters/g_fb_dvfs_threshold 2>/dev/null
    [ -w /sys/module/ged/parameters/gx_fb_dvfs_margin ] && echo 80 > /sys/module/ged/parameters/gx_fb_dvfs_margin 2>/dev/null
    [ -w /sys/module/ged/parameters/gpu_cust_boost_freq ] && echo 800000 > /sys/module/ged/parameters/gpu_cust_boost_freq 2>/dev/null

    # 4. Low-Latency Network & TCP Gaming Ping Stabilization
    [ -w /proc/sys/net/ipv4/tcp_low_latency ] && echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null
    [ -w /proc/sys/net/ipv4/tcp_fastopen ] && echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
    [ -w /proc/sys/net/ipv4/tcp_tw_reuse ] && echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null
    [ -w /proc/sys/net/ipv4/tcp_fin_timeout ] && echo 15 > /proc/sys/net/ipv4/tcp_fin_timeout 2>/dev/null

    # 5. Reduce debug-level console printk chatter
    [ -w /proc/sys/kernel/printk ] && echo "4 4 1 7" > /proc/sys/kernel/printk 2>/dev/null

    # 6. Battery & Deep Sleep Optimization:
    # Terminate background MTK engineering and debug logging daemons
    for s in connsyslogger mobile_log_d aee_aed aee_aed64 aee_aedv aee_aedv64 em_svr atci_service mdlogger emdlogger; do
        stop "$s" 2>/dev/null
        killall -9 "$s" 2>/dev/null
        setprop ctl.stop "$s" 2>/dev/null
    done
    setprop persist.vendor.mdlog.enable 0 2>/dev/null
    setprop persist.vendor.em.dy.debug 0 2>/dev/null

    # Telemetry and unused bloatware debloat
    for p in com.miui.daemon com.miui.bugreport com.miui.vsimcore com.miui.yellowpage; do
        pm disable-user --user 0 "$p" 2>/dev/null
    done

    # Fast-Doze Deep Sleep tuning (15s light doze, 30s deep sleep)
    CONSTANTS="inactive_to=30000,sensing_to=0,locating_to=0,location_accuracy=20.0,motion_inactive_to=0,idle_after_inactive_to=0,idle_pending_to=30000,max_idle_pending_to=60000,idle_pending_factor=2.0,idle_to=900000,max_idle_to=21600000,idle_factor=2.0,min_time_to_alarm=3600000,max_temp_app_allowlist_duration_ms=60000,mms_temp_app_allowlist_duration_ms=60000,sms_temp_app_allowlist_duration_ms=60000,notification_allowlist_duration_ms=60000,light_after_inactive_to=15000,light_pre_idle_to=30000,light_idle_to=120000,light_idle_factor=2.0,light_max_idle_to=900000"
    settings put global device_idle_constants "$CONSTANTS" 2>/dev/null

    # Wi-Fi Power Save & Scan Throttling
    settings put global wifi_scan_throttle_enabled 1 2>/dev/null
    settings put global wifi_scan_always_enabled 0 2>/dev/null
    settings put global ble_scan_always_enabled 0 2>/dev/null

    # Keep GPU warm during screen-on (eliminates cold-collapse animation stutter)
    [ -w /sys/devices/platform/13000000.mali/power_policy ] && echo always_on > /sys/devices/platform/13000000.mali/power_policy 2>/dev/null

    # 7. Touch & Gaming Latency Optimization (240Hz Response + SurfaceFlinger Pacing)
    echo sugov_ext > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
    echo sugov_ext > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor 2>/dev/null
    [ -w /dev/cpuctl/touch/cpu.uclamp.min ] && echo 30.00 > /dev/cpuctl/touch/cpu.uclamp.min 2>/dev/null
    [ -w /dev/cpuctl/touch/cpu.uclamp.latency_sensitive ] && echo 1 > /dev/cpuctl/touch/cpu.uclamp.latency_sensitive 2>/dev/null
    [ -w /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive ] && echo 1 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null

    # Hardware FT8726 TDDI touch responsiveness & game state
    [ -w /sys/devices/platform/11018000.spi4/spi_master/spi4/spi4.0/fts_glove_mode ] && echo 0 > /sys/devices/platform/11018000.spi4/spi_master/spi4/spi4.0/fts_glove_mode 2>/dev/null
    [ -w /proc/game_state ] && echo 1 > /proc/game_state 2>/dev/null
    [ -w /proc/tp_transient_report_rate_switch ] && echo 1 > /proc/tp_transient_report_rate_switch 2>/dev/null
    [ -w /proc/tp_report_rate_switch ] && echo 1 > /proc/tp_report_rate_switch 2>/dev/null
}

apply_tunings
sleep 6
apply_tunings
