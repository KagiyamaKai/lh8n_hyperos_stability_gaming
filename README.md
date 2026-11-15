# TECNO POVA 5 Pro 5G (`LH8n`) HyperOS Stability & Master Fixes

> **Educational & Engineering Research Project**  
> Targeting Xiaomi HyperOS 3.x (Android 14 API 34) ports on the **TECNO POVA 5 Pro 5G (`LH8n` / MediaTek Dimensity 6080 MT6833 / Transsion V792 Vendor)**.  
> **Author**: `Yakuzokai` (KagiyamaKai)  
> **SELinux**: Fully `Enforcing`  
> **Master Bug Compendium**: [**`docs/ROM_BUGS_AND_FIXES_MASTER_COMPENDIUM.md`**](docs/ROM_BUGS_AND_FIXES_MASTER_COMPENDIUM.md)

---

## Complete ROM Bugs & Fixes Compendium

An exhaustive engineering analysis of all 15 bugs diagnosed, reverse engineered, and resolved during this porting project is documented in:
👉 [**Master Compendium of All ROM Bugs, Diagnoses & Fixes**](docs/ROM_BUGS_AND_FIXES_MASTER_COMPENDIUM.md)

### Summary of Major Fixes

1. **Dynamic Window Blur Lag in Games (`disable_window_blurs`)**:
   - Automatically disables Gaussian blur passes in SurfaceFlinger when games are foreground, restoring 15–25 FPS on Mali-G57 MC2, and re-enables blurs upon exiting.
2. **MediaTek Hardware Color Filters (SurfaceFlinger Transact `1015`)**:
   - Directly injects $4 \times 4$ color transformation matrices into the hardware display composer, enabling Game Turbo saturation modes (Bright, Saturated, Clear) natively on MediaTek.
3. **Thermal Throttling & 45 FPS VSync Lock Resolution**:
   - Eliminated the Mobile Legends main lobby 45 FPS lock caused by Big Core throttling down to 898 MHz.
4. **Recents Overview Stack Rendering Fix**:
   - Eliminated multi-task snapshot FBO ghosting and restored rounded clipping outlines on Mali-G57 MC2.
5. **Full ST21NFC Stack Integration**:
   - Resolved Treble namespace isolation, multi-tenancy denials, fold listener crashes on Android 14, and patched all 43 missing Android 14 AIDL method stubs.
6. **Bypass Charging Automation (`BypassIslandDaemon`)**:
   - Automatically halts battery charging current while gaming on 68W fast chargers, dropping battery temperatures by $6^\circ\text{C}$–$8^\circ\text{C}$.
7. **Rear LED LightBelt Protocol Integration**:
   - Reverse engineered Transsion I2C commands to drive the physical rear LEDs for notifications, charging, and music.
8. **Mali GPU `trans_stat` Kernel Panic Guard**:
   - Locked node permissions to prevent 4KB slab overflow kernel panics.
9. **SELinux Enforcing & Zero-KSU Native Booting**:
   - Baked all patches directly into `super.img` with proper SELinux file contexts, achieving pure stock boot independence with zero root dependencies.

---

## Project Structure

```
lh8n_hyperos_stability_gaming/
├── docs/
│   ├── ROM_BUGS_AND_FIXES_MASTER_COMPENDIUM.md   # Exhaustive 15-bug technical breakdown
│   └── NFC_AND_SYSTEM_PORTING_MASTER_REPORT.md   # Deep dive on ST21NFC & SystemUI
├── system/vendor/bin/01_lh8n_sysfs.sh            # Boot sysfs permissions & early hooks
├── src/SysfsSettingsObserver.java                # Zero-fork background settings observer
├── post-fs-data.sh                               # Kernel crash guards & memory tuning
├── service.sh                                    # Service orchestrator & daemon launcher
├── system.prop                                   # ART, Dalvik & SurfaceFlinger properties
└── build.py                                      # Module packaging script
```

---

## Disclaimer & GitHub Policy Compliance

This repository contains non-proprietary shell scripts, Smali diffs, and academic technical documentation authored exclusively for operating system research and hardware compatibility analysis. No proprietary OEM framework binaries are distributed within this repository.
