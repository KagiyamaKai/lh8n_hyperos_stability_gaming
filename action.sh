#!/system/bin/sh
echo "=============================================="
echo "  LH8n HyperOS Stability & Gaming Diagnostics "
echo "                  By Kagiyama                 "
echo "=============================================="

# 1. Dangerous sysfs guards (stat only, NEVER read trans_stat contents)
ls -l /sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat 2>/dev/null | awk '{print "Mali trans_stat   : " $1 " " $3 ":" $4}'
ls -l /sys/class/leds/aw22xxx_led/rgb 2>/dev/null | awk '{print "AW22xxx rgb node  : " $1 " " $3 ":" $4}'

# 2. SELinux domain transition verification
SYSUI_CTX=$(cat /proc/$(pidof com.android.systemui 2>/dev/null)/attr/current 2>/dev/null)
PHONE_CTX=$(cat /proc/$(pidof com.android.phone 2>/dev/null)/attr/current 2>/dev/null)
JOY_CTX=$(cat /proc/$(pidof com.xiaomi.joyose 2>/dev/null)/attr/current 2>/dev/null)
echo "SystemUI context  : ${SYSUI_CTX:-not running}"
echo "Phone context     : ${PHONE_CTX:-not running}"
echo "Joyose context    : ${JOY_CTX:-not running}"

# 3. IVirtualHal loop check
VHAL_ERR=$(logcat -b all -t 200 2>/dev/null | grep -c "IVirtualHal/virtual" || true)
echo "IVirtualHal lines : ${VHAL_ERR} (recent 200 logcat lines)"

# 4. Gaming & VM runtime checks
echo "Game default FPS  : enabled=$(getprop persist.graphics.game_default_frame_rate.enabled) override=$(getprop ro.surface_flinger.game_default_frame_rate_override)"
echo "VM swappiness/wmk : $(cat /proc/sys/vm/swappiness) / watermark_scale=$(cat /proc/sys/vm/watermark_scale_factor) / compact=$(cat /proc/sys/vm/compaction_proactiveness)"
echo "UFS sdc ra/iostat : ra=$(cat /sys/block/sdc/queue/read_ahead_kb) iostats=$(cat /sys/block/sdc/queue/iostats)"
echo "uclamp latency    : top-app=$(cat /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null) touch=$(cat /dev/cpuctl/touch/cpu.uclamp.latency_sensitive 2>/dev/null)"
echo "ged_smart_boost   : $(cat /sys/module/ged/parameters/ged_smart_boost 2>/dev/null)"
echo "dex2oat cpus/thrd : cpus=$(cat /dev/cpuset/dex2oat/cpus 2>/dev/null) bg_threads=$(getprop dalvik.vm.background-dex2oat-threads) cpu_set=$(getprop dalvik.vm.background-dex2oat-cpu-set)"
echo "ART madvise       : vdex=$(getprop dalvik.vm.madvise.vdexfile.size) odex=$(getprop dalvik.vm.madvise.odexfile.size) art=$(getprop dalvik.vm.madvise.artfile.size)"
echo "memcg apps swap   : $(cat /dev/memcg/apps/memory.swappiness 2>/dev/null) (vendor.zram.disable='$(getprop vendor.zram.disable)')"
echo "=============================================="

