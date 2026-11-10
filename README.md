# TECNO LH8n HyperOS Stability & Gaming Fix

KernelSU / Magisk root module (`v1.0.4`, author: **Kagiyama**) targeting HyperOS 3.x ports on the **TECNO POVA 5 Pro 5G (`LH8n` / MT6833 / V792 vendor)**.

## What It Fixes & Tunes

- **Kernel Crash Guards (`post-fs-data.sh`, `service.sh`, `customize.sh`):**
  - Locks `/sys/devices/platform/13000000.mali/devfreq/13000000.mali/trans_stat` to `0000` to prevent Mali `trans_stat` 4KB slab overflow reads.
  - Locks `aw22xxx_led/rgb` to `root:system` `0640` to prevent out-of-bounds UBSAN kernel panics.
- **SELinuxMMAC & System App Context (`post-fs-data.sh`, `system/*_mac_permissions.xml`):**
  - Resolves duplicate signer entries in `system_ext_mac_permissions.xml` and `product_mac_permissions.xml` and labels `plat_mac_permissions.xml` cleanly so system apps leave `u:r:zygote:s0` properly.
  - Supports metamodule-less KernelSU Next bind-mounting directly in `post-fs-data.sh` with ART dalvik-cache invalidation tracking (`TARGET_VER="102"`).
- **Patched `services.jar`:**
  - Stops the infinite 1-second `IVirtualHal/virtual` retry loop.
- **Zero-Fork Sysfs & Settings Observer (`lh8n_observer.dex`, `src/SysfsSettingsObserver.java`, `system/vendor/bin/01_lh8n_sysfs.sh`):**
  - Keeps `01_lh8n_sysfs.sh` strictly for early-boot permissions/startup LED playback and boot completion handoff before idling silently (`sleep 3600`), eliminating continuous `settings` `app_process` forks and `u:r:init:s0` SELinux `audit_lost` bursts.
  - Offloads Reading Mode (`night_display_activated`), Refresh Rate (`min/peak_refresh_rate`), LightBelt `/data/local/tmp/lh8n_*` cache sync, 70°C thermal watchdog, `/data/local/tmp/lh8n_cmd` handling, and `Os.stat`-guarded permission enforcement cleanly into `SysfsSettingsObserver` (`service.sh`, `u:r:ksu:s0`) via cached `IContentProvider` Binder calls.
- **Dalvik / ART & Frame Rate (`system.prop`):**
  - `persist.graphics.game_default_frame_rate.enabled=false` and `ro.surface_flinger.game_default_frame_rate_override=0`
  - `dalvik.vm.image-dex2oat-cpu-set=0,1,2,3,4,5`, `dalvik.vm.background-dex2oat-cpu-set=0,1,2,3,4,5`, `dalvik.vm.background-dex2oat-threads=4`
  - `dalvik.vm.madvise.vdexfile.size=104857600`, `dalvik.vm.madvise.odexfile.size=104857600`, `dalvik.vm.madvise.artfile.size=8388608`
- **VM, memcg, UFS, Scheduler & GPU (`post-fs-data.sh`, `service.sh`):**
  - Clears dead `ro.gfx.driver.0` and contradicting `vendor.zram.disable` properties via `resetprop -d`.
  - Tunes VM (`swappiness=60`, `watermark_scale_factor=50`, `compaction_proactiveness=0`, `page-cluster=0`, `vfs_cache_pressure=80`, `dirty_background_ratio=5`, `dirty_ratio=15`), `memcg` `memory.swappiness=60`, `/dev/cpuset/dex2oat/cpus=0-5`, UFS/dm-block `iostats=0` and `read_ahead_kb=256`, `top-app`/`touch` `cpu.uclamp.latency_sensitive=1`, `ged_smart_boost=1`, and `printk="4 4 1 7"`.

## Packaging

```bash
python build.py
```

Generates `LH8n_HyperOS_Stability_Gaming_v1.0.4.zip`.

## Diagnostics

Tap **Action** in KernelSU Manager (`action.sh`) to inspect sysfs node guards, process SELinux contexts, `IVirtualHal` logcat counts, FPS override props, VM/UFS/uclamp/GED state, and dex2oat/ART settings.
