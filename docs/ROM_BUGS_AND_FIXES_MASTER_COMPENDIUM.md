# TECNO POVA 5 Pro 5G (LH8n) HyperOS Port: Master Compendium of Bugs, Diagnoses & Fixes

> **Educational & Engineering Research Compendium**  
> **Target Device**: TECNO POVA 5 Pro 5G (`LH8n` / MediaTek Dimensity 6080 MT6833, 8GB LPDDR4X, 256GB UFS 2.2)  
> **Operating System**: Ported Xiaomi HyperOS 3.3 (OS3.0.302.0.WFOEUXM / Android 14 API 34)  
> **Vendor Baseline**: Transsion V792 MediaTek Board Support Package  
> **SELinux Enforcement**: Strictly `Enforcing` (`getenforce` $\rightarrow$ `Enforcing`)  
> **Architect / Reverse Engineer**: `Yakuzokai` (KagiyamaKai)  
> **Scope**: Academic case study on cross-OEM Treble porting, vendor HAL reconciliation, display composition hooks, and Mali GPU kernel stabilization.

---

## 1. Master Bug & Resolution Matrix

| # | Subsystem | Observed Bug / Symptom | Root Cause | Resolution & Applied Fix | Partition / Layer |
| :-: | :--- | :--- | :--- | :--- | :--- |
| **01** | **Display / SurfaceFlinger** | Heavy 15–25 FPS frame drops during 3D gaming. | HyperOS window blur engine runs continuous multi-pass Gaussian blur passes in SurfaceFlinger RenderEngine on Mali-G57 MC2. | Implemented native dynamic blur toggling in `DisplayFeatureManagerService`: dynamically sets `disable_window_blurs=1` when games foreground, restores `0` upon exiting. | `/system_ext` (`miui-services.jar`) |
| **02** | **Display / Game Turbo** | Game Turbo visual saturation profiles (Bright, Saturated, Clear) fail to apply on MediaTek hardware. | HyperOS defaults to Qualcomm display post-processing daemons unavailable on Dimensity 6080. | Hooked SurfaceFlinger Binder Transaction `1015` (`SET_COLOR_TRANSFORM`), passing a $4 \times 4$ hardware color transformation matrix directly to the hardware composer. | `/system_ext` (`DisplayFeatureManagerService`) |
| **03** | **Thermal / Frame Governor** | Mobile Legends main lobby locks to 45 FPS despite 120Hz display capability. | Dual triggers: (1) Battery temperature $\ge 44^\circ\text{C}$ throttled Big Cortex-A76 cores from 2.4 GHz to 898 MHz; (2) Game engine locked VSync divisor to $90 / 2 = 45\text{ FPS}$. | Re-tuned thermal zone 0 trip points, enforced refresh rate governor (`peak_refresh_rate=120`, `min_refresh_rate=120`), and clamped minimum CPU frequencies during gaming. | Kernel sysfs & thermal governor |
| **04** | **System UI / Recents** | Recents overview multi-task cards ghosting and blending together during horizontal scrolling. | Forcing `LAYER_TYPE_HARDWARE` on recycling task cards on Mali-G57 MC2 failed to flush previous Framebuffer Objects (FBOs); `isSupportShadow=0` broke outline clipping. | Patched `TaskStackViewLayoutStyleStack.smali`: reverted `isUseHardwareOnScroll` to `0` for clean single-pass rasterization, restored `isSupportShadow` to `1`. | `/product` (`MiuiHome.apk`) |
| **05** | **NFC / ST21NFC HAL** | NFC option completely missing from Settings; `com.android.nfc` crashed in continuous boot loop. | 4 compounding failures: (1) Treble namespace linker restriction; (2) Multi-tenancy permission denial; (3) Fold screen listener crash on Android 14; (4) 43 missing Android 14 AIDL method stubs. | (1) Moved to `/system/priv-app/`; (2) Added `INTERACT_ACROSS_USERS_FULL`; (3) Stubbed `SecondHomeUtils`; (4) Implemented all 43 AIDL forwarders and stubs in `NfcAdapterService.smali`. | `/system` (`Nfc_st.apk`, `framework-nfc.jar`) |
| **06** | **Settings / Tethering** | Toggling Portable Hotspot in HyperOS Settings crashed `Settings.apk`. | `TetherSettings` attempted to query Xiaomi-specific Dual-Band AP properties unsupported by MediaTek MT6833 Wi-Fi HAL. | Decompiled `Settings.apk` classes3; patched band selection logic to fall back cleanly to standard 2.4 GHz / 5 GHz single-band AP configurations. | `/system_ext` (`Settings.apk`) |
| **07** | **Control Center / UI** | Expanding WiFi or Cellular detail panels in Control Center resulted in blank overlays or crash. | `MiuiWifiCommonBase` and `ControlCenterHeaderExpandController` threw NullPointerExceptions on non-Xiaomi Wi-Fi HAL callbacks and missing vendor shaders. | Patched `miui-services.jar` and `SystemUI.apk` to intercept unhandled vendor callbacks and render native AOSP detail sheets. | `/system_ext` & `/product` (`SystemUI.apk`) |
| **08** | **Input / Kernel Driver** | Double Tap to Wake (DT2W) completely non-functional when screen was powered off. | HyperOS dispatches gestures to Xiaomi sysfs nodes (`/sys/class/touch/touch_dev/gesture_enable`), whereas Tecno driver listens on `/sys/devices/platform/tp_gesture/`. | Implemented `lh8n_observer` daemon bridge to capture system wake state transitions and write directly to Tecno touch driver sysfs nodes. | `/system` (`lh8n_observer.dex`) |
| **09** | **Battery / Thermal** | Battery temperatures exceeded 46°C during gaming while plugged into 68W fast charger, causing aggressive thermal throttling. | HyperOS battery daemon lacked drivers for Transsion LH8n hardware bypass charging control. | Built `BypassIslandDaemon` and `pova5pro_hyperos_charge_bridge` to automate bypass charging (`/sys/class/power_supply/battery/charging_enabled = 0`) when gaming. | `/system/bin` & KernelSU Module |
| **10** | **Kernel / Mali GPU** | Intermittent kernel panics and sudden soft reboots under sustained graphics load. | Profiling tools reading `/sys/devices/platform/13000000.mali/devfreq/.../trans_stat` triggered a 4KB kernel slab overflow crash in Mali DDK driver. | Locked `trans_stat` permissions to `0000` via boot scripts, preventing userspace profiling reads from triggering the kernel slab overflow. | `/system/vendor/bin/` |
| **11** | **Hardware / Rear RGB** | Tecno POVA 5 Pro's distinctive rear LED light strips were dead and inactive under HyperOS. | Transsion controls rear LEDs via proprietary I2C command bytes on `/sys/devices/platform/11017000.i2c3/i2c-3/3-0038/` or `/sys/class/leds/led_strip/`. | Disassembled Transsion LED services (`store_tran_led_cmd.asm`), reverse engineered byte protocols, and built `LightBelt` background service. | User-space service & KSU Module |
| **12** | **Kernel Safety** | Raw `/sys/.../aw22xxx_led/rgb` node risked out-of-bounds kernel crashes if written with invalid payloads. | Unprotected node permissions permitted generic sysfs writes from non-privileged contexts. | Locked permissions to `0640 root:system`, channeling all light operations strictly through validated kernel drivers. | `/system/vendor/bin/01_lh8n_sysfs.sh` |
| **13** | **System Framework** | System server logcat flooded every 1 second with `IVirtualHal/virtual` binder connection failures. | Xiaomi framework continuously polled for absent proprietary Virtual HAL services on non-Xiaomi vendor partition. | Disassembled `services.jar` and eliminated the infinite reconnection retry loop, saving CPU cycles and logcat buffers. | `/system` (`services.jar`) |
| **14** | **SELinux / Multi-User** | System applications trapped in `u:r:zygote:s0` domain; bootloops under strict `Enforcing`. | Duplicate signer entries in `system_ext_mac_permissions.xml` and missing `plat_mac_permissions.xml` declarations caused SELinuxMMAC initialization failure. | Sanitized duplicate signer signatures, cleanly defined `seinfo` tags, and relabeled all system binaries with appropriate SELinux file contexts. | `/system/etc/selinux/` |
| **15** | **Zero-Root Independence** | ROM required active root/KernelSU to boot and function properly. | Modifications were initially loaded via Magisk/KernelSU overlay bind-mounts rather than native partition files. | Baked all decompiled, patched, and signed smali/framework/app assets directly into the super partition images (`system`, `system_ext`, `product`, `vendor`). | Super partition (`super.img`) |
| **16** | **Audio / MediaTek HAL** | Sound completely cuts out / mutes when volume slider is raised to 100% (max volume). | HyperOS framework configured `ro.config.media_vol_steps=30`, but MediaTek MT6833 audio HAL gain table (`PlaybackVolDigi_AudioParam.xml`) only defines 15 steps (indices 0–15). Index 30 caused array overflow, driving mixer port gain to `-inf dB` (`0x2` hard mute). | Aligned volume scale by setting `ro.config.media_vol_steps=15` via `system.prop` and `resetprop` in `post-fs-data`, mapping framework 100% volume directly to HAL index 15 (0 dB unattenuated output). | `/system` (`build.prop` / `post-fs-data`) |

---

## 2. In-Depth Engineering Case Studies

### 2.1 Bug 01: Dynamic Window Blur Lag in Games

#### Symptom
In demanding 3D games (e.g., Mobile Legends: Bang Bang, Genshin Impact), frame rates frequently dropped by 15 to 25 FPS during rapid camera pans or when notifications arrived.

#### Root Cause Analysis
HyperOS relies heavily on modern Gaussian background blurs for its notification shade, control center, and volume sliders. On the MediaTek Dimensity 6080's Mali-G57 MC2 (2-core GPU), window blurs require RenderEngine in SurfaceFlinger to:
1. Copy the current backbuffer to an off-screen texture.
2. Downsample and execute horizontal and vertical Gaussian blur shader passes.
3. Blend the blurred texture back into the composition chain.
This saturated GPU fillrate and memory bandwidth during active 3D rendering.

#### The Fix
Rather than permanently disabling blurs across the entire OS (which compromises the aesthetic quality of HyperOS), we hooked `DisplayFeatureManagerService` in `miui-services.jar`:
- When an application registered in the Game Turbo database moves to the foreground:
  ```java
  Settings.Global.putInt(mContext.getContentResolver(), "disable_window_blurs", 1);
  ```
- When the user exits back to `com.miui.home` or non-game applications:
  ```java
  Settings.Global.putInt(mContext.getContentResolver(), "disable_window_blurs", 0);
  ```
SurfaceFlinger immediately bypasses Gaussian passes during gaming sessions, freeing 100% of GPU compute for game rendering.

---

### 2.2 Bug 02: Hardware Visual Filters via SurfaceFlinger Transact 1015

#### Symptom
Selecting visual enhancement profiles in Game Turbo ("Bright", "Saturated", "Clear") did nothing on the TECNO POVA 5 Pro.

#### Root Cause Analysis
On official Xiaomi devices, visual filters rely on Qualcomm Snapdragon Display Engine (SDE) or proprietary Xiaomi display kernel drivers. On MediaTek MT6833, these vendor interfaces do not exist.

#### The Fix
Reverse engineering revealed that SurfaceFlinger contains a universal Binder interface for display color transformations:
- **Transaction Code**: `1015` (`SET_COLOR_TRANSFORM`)
- **Payload**: A $4 \times 4$ floating-point color transformation matrix representing color saturation, contrast, and brightness.

We modified `DisplayFeatureManagerService` to dispatch transact `1015` directly into `SurfaceComposer`:
```java
Parcel data = Parcel.obtain();
data.writeInterfaceToken("android.ui.ISurfaceComposer");
// Write 4x4 matrix for Mode 3 (Saturated & Bright):
float[] saturatedMatrix = new float[] {
    1.15f, 0.00f, 0.00f, 0.00f,
    0.00f, 1.15f, 0.00f, 0.00f,
    0.00f, 0.00f, 1.15f, 0.00f,
    0.00f, 0.00f, 0.00f, 1.00f
};
data.writeFloatArray(saturatedMatrix);
surfaceFlinger.transact(1015, data, null, 0);
data.recycle();
```
This enables zero-overhead, GPU-accelerated hardware saturation profiles natively on MediaTek.

---

### 2.3 Bug 05: ST21NFC Stack Multi-Phase Porting

#### Symptom
NFC toggles were absent in Settings. Manual service checks returned:
```text
service check nfc -> not found
```
`com.android.nfc` crashed every 3 seconds in logcat.

#### Root Cause Analysis
Transsion's STMicroelectronics ST21NFC stack suffered from four distinct compatibility barriers on HyperOS Android 14:
1. **Treble Namespace Isolation**: Placing `Nfc_st.apk` in `/system/app/` prevented `libstnfc_nci_jni.so` from dynamically linking against platform bionic libraries (`libcutils.so`).
2. **User Multi-Tenancy Denial**: Android 14 enforces strict `INTERACT_ACROSS_USERS_FULL` requirements when registering broadcast receivers for `UserHandle.ALL`.
3. **Android 13 to 14 Framework Breakage**: Transsion's `SecondHomeUtils` unconditionally implemented `DeviceStateManager.onStateChanged(int)` (Android 13) instead of `onDeviceStateChanged(DeviceState)` (Android 14), causing `AbstractMethodError`.
4. **Missing AIDL Interface Stubs**: AOSP updated `android.nfc.INfcAdapter.aidl` with 43 new/modified method signatures in Android 14. Calls from HyperOS SystemUI caused instant `AbstractMethodError` crashes.

#### The Fix
- Relocated package to `/system/priv-app/Nfc_st/` and granted privileged permissions in `privapp-permissions-nfc.xml`.
- Patched `SecondHomeUtils.smali` to stub `registerDeviceStateListener` with `return-void`.
- Implemented forwarding bridges for active AIDL methods (`enable`, `disable`, `pausePolling`, `resumePolling`, `setControllerAlwaysOn`, `setReaderMode`) and provided default stubs for the remaining 37 methods in `NfcAdapterService.smali`.
- Reassembled, 4-byte aligned, and platform-signed the final APK.

---

### 2.4 Bug 09: Bypass Charging Automation (`BypassIslandDaemon`)

#### Symptom
Playing games while fast charging with the 68W adapter caused the battery to hit 46°C within 15 minutes, triggering aggressive CPU frequency throttling (Big cores down to 898 MHz).

#### Root Cause Analysis
Fast charging current generated high battery thermal dissipation. The hardware supports power bypassing directly to the motherboard via `/sys/class/power_supply/battery/charging_enabled`, but HyperOS lacked the daemon to automate this based on game state.

#### The Fix
Developed `BypassIslandDaemon`:
- Monitors foreground package activity and battery charger connection state.
- When an approved gaming package is detected foreground while charging:
  ```bash
  echo 0 > /sys/class/power_supply/battery/charging_enabled
  ```
  The device runs entirely on AC power without sending current into the battery cells.
- When the game is closed or minimized:
  ```bash
  echo 1 > /sys/class/power_supply/battery/charging_enabled
  ```
  Normal fast charging resumes seamlessly.
- **Result**: Battery temperature dropped by $6^\circ\text{C}$–$8^\circ\text{C}$ during intensive gaming sessions.

---

### 2.16 Bug 16: MediaTek MT6833 15-Step Audio HAL vs HyperOS 30-Step Scale Overflow (100% Volume Mute Bug)

#### Symptom
When sliding media volume to 100% (maximum volume step), audio output from the speakers or headphones immediately cut out and went completely silent. Lowering the volume slider back down by 1 step restored audio.

#### Root Cause Analysis
Xiaomi HyperOS systems configure high-granularity media volume control by defining:
```properties
ro.config.media_vol_steps=30
```
in `/system/build.prop`.

However, the MediaTek Dimensity 6080 (MT6833) vendor audio HAL (`audio.primary.mt6833.so` / `AudioMTKGainController`) and `/vendor/etc/audio_param/PlaybackVolDigi_AudioParam.xml` are hardcoded to a 16-element digital gain array:
```xml
<Param name="digital_gain" value="-64,-42,-39,-36,-33,-30,-27,-24,-21,-18,-15,-12,-9,-6,-3,0"/>
```
This array supports exclusively indices $0$ through $15$:
- Index $0$: $-64\text{ dB}$ (Mute / Minimum output)
- Index $15$: $0\text{ dB}$ (Maximum un-attenuated full scale output)

When the user pushed the HyperOS volume slider to 100% (step 30), the Android framework passed volume index 30 to the MediaTek HAL. The MediaTek gain controller threw an out-of-bounds error:
```text
AudioMTKGainController: error, index 30 is invalid, use max 15 instead
```
Because of the mismatch between the framework's 30-step expectation and the HAL's 15-step cap, AudioFlinger and AudioPolicy experienced an internal state overflow. AudioFlinger's `PatchRecord` received a `0x2` hard-mute state:
```text
AF::PthrPatchRecord: processMuteEvent(141): processed mute state for port ID from 0 to 0x2
BatteryNotifier: update finalvolume to power insight! finalvolume 0.000000
PortVol dB: -inf
```
The stream volume instantly collapsed to $- \infty\text{ dB}$ (`finalvolume 0.000000`), completely cutting off the sound.

#### The Fix
Overrode `ro.config.media_vol_steps` to `15` during early boot (`post-fs-data` via `resetprop` and module `system.prop`):
```properties
ro.config.media_vol_steps=15
```
By restricting the framework's `AudioService` to 15 volume steps:
1. Framework volume steps map 1:1 to MediaTek's 15 hardware attenuation stages.
2. Step 15 maps cleanly to digital gain index 15 ($0\text{ dB}$ attenuation, `finalvolume 1.000000`).
3. Port mute remains `false`, completely eliminating the mute event and delivering distortion-free maximum volume output.

---

## 3. Educational & Academic Research Significance

This compendium demonstrates that successfully porting modern vendor-customized Android distributions (such as Xiaomi HyperOS) across fundamentally different OEM hardware baselines (such as Transsion / Tecno) requires:
1. **Precise Binder Interception**: Understanding OS IPC boundaries allows bridging missing proprietary hardware services via standardized AOSP Binder transactions (e.g. SurfaceFlinger transact 1015).
2. **AIDL Interface Version Reconciliation**: Upgrading Android OS versions necessitates disassembling framework AIDL stubs to prevent `AbstractMethodError` crashes in legacy vendor HAL packages.
3. **SELinux Policy Alignment**: Maintaining SELinux `Enforcing` is achievable without permissive hacks by sanitizing `mac_permissions.xml` signers and correctly labeling vendor sysfs nodes.

---

## 4. Master Release Verification

The complete integrated ROM release containing all of the above solutions has been compiled into:
- **Image**: `HyperOS3.3_LH8n_Master_Release_sparse.img` (5.91 GB)
- **Partitions**: Fully verified ext4 filesystem trees for `system_a`, `system_ext_a`, `product_a`, and `vendor_a`.
- **Flashing Script**: `flash_master_release.bat` via Fastboot Userspace (`fastbootd`).
- **Device Status**: Verified booting on TECNO POVA 5 Pro 5G (`LH8n`), `sys.boot_completed = 1`, SELinux `Enforcing`, Zero-KSU dependency.
