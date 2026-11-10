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
    [ -w /proc/sys/vm/swappiness ] && echo 60 > /proc/sys/vm/swappiness 2>/dev/null
    [ -w /proc/sys/vm/watermark_scale_factor ] && echo 50 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    [ -w /proc/sys/vm/compaction_proactiveness ] && echo 0 > /proc/sys/vm/compaction_proactiveness 2>/dev/null
    [ -w /proc/sys/vm/page-cluster ] && echo 0 > /proc/sys/vm/page-cluster 2>/dev/null
    [ -w /proc/sys/vm/vfs_cache_pressure ] && echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    [ -w /proc/sys/vm/dirty_background_ratio ] && echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    [ -w /proc/sys/vm/dirty_ratio ] && echo 15 > /proc/sys/vm/dirty_ratio 2>/dev/null
    for mc in /dev/memcg/apps /dev/memcg/game /dev/memcg/protected-app /dev/memcg/system; do
        [ -w "$mc/memory.swappiness" ] && echo 60 > "$mc/memory.swappiness" 2>/dev/null
    done
    [ -w /dev/cpuset/dex2oat/cpus ] && echo 0-5 > /dev/cpuset/dex2oat/cpus 2>/dev/null
    command -v resetprop >/dev/null 2>&1 && resetprop dalvik.vm.background-dex2oat-threads 4 2>/dev/null

    # 2. UFS & dm-block queue latency tuning
    for b in /sys/block/sda /sys/block/sdb /sys/block/sdc /sys/block/mmcblk0 /sys/block/dm-*; do
        [ -d "$b/queue" ] || continue
        [ -w "$b/queue/iostats" ] && echo 0 > "$b/queue/iostats" 2>/dev/null
    done
    [ -w /sys/block/sdc/queue/read_ahead_kb ] && echo 256 > /sys/block/sdc/queue/read_ahead_kb 2>/dev/null
    [ -w /sys/block/dm-42/queue/read_ahead_kb ] && echo 256 > /sys/block/dm-42/queue/read_ahead_kb 2>/dev/null

    # 3. Scheduler latency-sensitive hint for foreground games and touch pipeline
    for c in /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive /dev/cpuctl/touch/cpu.uclamp.latency_sensitive; do
        [ -w "$c" ] && echo 1 > "$c" 2>/dev/null
    done

    # 4. Dynamic GPU DVFS responsiveness (MediaTek GED smart boost)
    [ -w /sys/module/ged/parameters/ged_smart_boost ] && echo 1 > /sys/module/ged/parameters/ged_smart_boost 2>/dev/null

    # 5. Reduce debug-level console printk chatter while keeping warnings/errors intact
    [ -w /proc/sys/kernel/printk ] && echo "4 4 1 7" > /proc/sys/kernel/printk 2>/dev/null
}

apply_tunings
# Re-apply after init's on-boot_completed queue resets settle
sleep 6
apply_tunings

