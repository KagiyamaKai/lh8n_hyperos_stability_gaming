import android.content.Intent;
import android.os.Binder;
import android.os.Bundle;
import android.os.IBinder;
import android.system.Os;
import android.system.StructStat;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.lang.reflect.Method;

public class SysfsSettingsObserver {
    private static final String CMD_FILE = "/data/local/tmp/lh8n_cmd";
    private static final String THERMAL_NODE = "/sys/class/thermal/thermal_zone0/temp";
    private static final String TRAN_LED_CMD = "/sys/led/led/tran_led_cmd";
    private static final String TRAN_LED_CMD_I2C = "/sys/devices/platform/11d21000.i2c/i2c-2/2-006a/tran_led_cmd";
    private static final String AW22_CFG = "/sys/class/leds/aw22xxx_led/cfg";
    private static final String AW22_EFFECT = "/sys/class/leds/aw22xxx_led/effect";
    private static final String[] RGB_NODES = {
        "/sys/class/leds/aw22xxx_led/rgb",
        "/sys/devices/platform/11d21000.i2c/i2c-2/2-006a/leds/aw22xxx_led/rgb"
    };
    private static final String[] DIR_NODES_0755 = {
        "/sys/class/leds",
        "/sys/devices/platform/11d21000.i2c/i2c-2/2-006a",
        "/sys/devices/platform/mtk_leds/leds/lcd-backlight"
    };
    private static final String[] RW_NODES_0666 = {
        "/sys/class/leds/lcd-backlight/brightness",
        "/sys/devices/platform/mtk_leds/leds/lcd-backlight/brightness",
        TRAN_LED_CMD,
        TRAN_LED_CMD_I2C
    };

    private static final String CACHE_STARTUP_CMD = "/data/local/tmp/lh8n_startup_cmd";
    private static final String CACHE_IMAX = "/data/local/tmp/lh8n_imax";
    private static final String CACHE_MASTER = "/data/local/tmp/lh8n_master";
    private static final String CACHE_CHARGE_CMD = "/data/local/tmp/lh8n_charge_cmd";
    private static final String CACHE_STARTUP_BRIGHTNESS = "/data/local/tmp/lh8n_startup_brightness";
    private static final String CACHE_STARTUP_IMAX = "/data/local/tmp/lh8n_startup_imax";
    private static final String CACHE_CHARGE_BRIGHTNESS = "/data/local/tmp/lh8n_charge_brightness";
    private static final String CACHE_CHARGE_IMAX = "/data/local/tmp/lh8n_charge_imax";

    private static final IBinder sToken = new Binder();
    private static Object sSettingsProvider;
    private static Method sProviderCall;
    private static Object sAttrSource;

    private static Object sActivityManager;
    private static Method sBroadcastWithFeature;
    private static Method sBroadcastLegacy;

    private static String sLastPaper = null;
    private static String sLastSmart = null;
    private static String sLastRr = null;
    private static boolean sDefaultsApplied = false;

    private static String readFileTrim(String path) {
        File f = new File(path);
        if (!f.exists()) return "";
        try (BufferedReader br = new BufferedReader(new FileReader(f))) {
            String line = br.readLine();
            return line != null ? line.trim() : "";
        } catch (Throwable t) {
            return "";
        }
    }

    private static int parseIntOr(String val, int fallback) {
        if (val == null || val.isEmpty()) return fallback;
        try {
            return Integer.parseInt(val);
        } catch (Exception e) {
            return fallback;
        }
    }

    private static void writeFile(String path, String value) {
        try (FileWriter fw = new FileWriter(path)) {
            fw.write(value);
        } catch (Throwable ignored) {}
    }

    private static void writeCacheIfChanged(String path, String value) {
        if (value == null || value.isEmpty() || "null".equals(value)) return;
        String current = readFileTrim(path);
        if (!value.equals(current)) {
            writeFile(path, value + "\n");
            try {
                Os.chmod(path, 0666);
            } catch (Throwable ignored) {}
        }
    }

    private static void initSettingsProvider() {
        if (sSettingsProvider != null && sProviderCall != null) return;
        try {
            Class<?> amClass = Class.forName("android.app.ActivityManager");
            Object am = amClass.getMethod("getService").invoke(null);
            if (am == null) return;
            Method getCp = am.getClass().getMethod("getContentProviderExternal", String.class, int.class, IBinder.class, String.class);
            Object holder = getCp.invoke(am, "settings", 0, sToken, null);
            if (holder == null) return;
            Object provider = holder.getClass().getField("provider").get(holder);
            if (provider == null) return;
            Class<?> attrCls = Class.forName("android.content.AttributionSource");
            sAttrSource = attrCls.getMethod("myAttributionSource").invoke(null);
            sProviderCall = provider.getClass().getMethod("call", attrCls, String.class, String.class, String.class, Bundle.class);
            sSettingsProvider = provider;
        } catch (Throwable t) {
            sSettingsProvider = null;
            sProviderCall = null;
        }
    }

    private static String getSetting(String table, String key) {
        initSettingsProvider();
        if (sSettingsProvider != null && sProviderCall != null && sAttrSource != null) {
            try {
                Bundle args = new Bundle();
                args.putInt("_user", 0);
                Bundle res = (Bundle) sProviderCall.invoke(sSettingsProvider, sAttrSource, "settings", "GET_" + table, key, args);
                if (res != null) {
                    String val = res.getString("value");
                    return val != null ? val.trim() : "";
                }
            } catch (Throwable t) {
                sSettingsProvider = null;
                sProviderCall = null;
            }
        }
        return "";
    }

    private static void putSettingIfDifferent(String table, String key, String target) {
        if (target == null) return;
        String cur = getSetting(table, key);
        if (target.equals(cur)) return;
        initSettingsProvider();
        if (sSettingsProvider != null && sProviderCall != null && sAttrSource != null) {
            try {
                Bundle args = new Bundle();
                args.putString("value", target);
                args.putInt("_user", 0);
                sProviderCall.invoke(sSettingsProvider, sAttrSource, "settings", "PUT_" + table, key, args);
            } catch (Throwable t) {
                sSettingsProvider = null;
                sProviderCall = null;
            }
        }
    }

    private static String fallbackStartupCmd(String idx) {
        switch (idx) {
            case "0": return "00 03 01 00 00 00"; // Dreamy Illusion
            case "1": return "00 31 02 00 00 00"; // Racing / Speed
            case "2": return "00 04 00 00 00 00"; // Soft Wave
            case "3": return "00 20 02 00 00 00"; // Breathing Pulse
            case "4": return "00 20 03 00 00 00"; // Party Rhythm
            case "5": return "00 01 00 00 00 00"; // Off
            default: return "";
        }
    }

    private static void syncDisplayAndRefreshSettings() {
        initSettingsProvider();
        if (sSettingsProvider == null) return;

        if (!sDefaultsApplied) {
            putSettingIfDifferent("global", "disable_window_blurs", "0");
            putSettingIfDifferent("secure", "background_blur_enable", "1");
            putSettingIfDifferent("system", "background_blur_enable", "1");
            sDefaultsApplied = true;
        }

        // Reading Mode -> Night Display sync
        String paper = getSetting("system", "screen_paper_mode_enabled");
        if (paper.isEmpty()) paper = "0";
        if (!paper.equals(sLastPaper)) {
            sLastPaper = paper;
            putSettingIfDifferent("secure", "night_display_activated", "1".equals(paper) ? "1" : "0");
        }

        // Smart FPS / Refresh Rate sync
        String smart = getSetting("system", "is_smart_fps");
        String userRr = getSetting("secure", "user_refresh_rate");
        if ("1".equals(smart)) {
            if (!"1".equals(sLastSmart)) {
                sLastSmart = "1";
                sLastRr = "smart";
                putSettingIfDifferent("system", "min_refresh_rate", "60.0");
                putSettingIfDifferent("system", "peak_refresh_rate", "120.0");
            }
        } else {
            sLastSmart = "0";
            if (!userRr.isEmpty() && !userRr.equals(sLastRr)) {
                if ("60".equals(userRr) || "90".equals(userRr) || "120".equals(userRr)) {
                    String rate = userRr + ".0";
                    putSettingIfDifferent("system", "min_refresh_rate", rate);
                    putSettingIfDifferent("system", "peak_refresh_rate", rate);
                    sLastRr = userRr;
                }
            }
        }
    }

    private static void syncLightBeltCache() {
        if (sSettingsProvider == null) return;
        String sCmd = getSetting("global", "tran_led_startup_cmd");
        if (sCmd.isEmpty() || "null".equals(sCmd)) {
            sCmd = fallbackStartupCmd(getSetting("global", "tran_led_startup_settings"));
        }
        writeCacheIfChanged(CACHE_STARTUP_CMD, sCmd);
        writeCacheIfChanged(CACHE_IMAX, getSetting("global", "tran_led_imax"));
        writeCacheIfChanged(CACHE_MASTER, getSetting("global", "tran_led_lighting_settings"));
        writeCacheIfChanged(CACHE_CHARGE_CMD, getSetting("global", "tran_led_charge_effect_cmd"));
        writeCacheIfChanged(CACHE_STARTUP_BRIGHTNESS, getSetting("global", "tran_led_startup_brightness"));
        writeCacheIfChanged(CACHE_STARTUP_IMAX, getSetting("global", "tran_led_startup_imax"));
        writeCacheIfChanged(CACHE_CHARGE_BRIGHTNESS, getSetting("global", "tran_led_charge_brightness"));
        writeCacheIfChanged(CACHE_CHARGE_IMAX, getSetting("global", "tran_led_charge_imax"));
    }

    private static void sendQuickChargeBroadcast(int type, int watts) {
        try {
            if (sActivityManager == null) {
                Class<?> amClass = Class.forName("android.app.ActivityManager");
                sActivityManager = amClass.getMethod("getService").invoke(null);
                if (sActivityManager != null) {
                    for (Method m : sActivityManager.getClass().getMethods()) {
                        if (m.getName().equals("broadcastIntentWithFeature") && m.getParameterTypes().length == 16) {
                            sBroadcastWithFeature = m;
                            break;
                        } else if (m.getName().equals("broadcastIntent") && m.getParameterTypes().length == 13) {
                            sBroadcastLegacy = m;
                        }
                    }
                }
            }
            Intent intent = new Intent("miui.intent.action.ACTION_QUICK_CHARGE_TYPE");
            intent.putExtra("miui.intent.extra.quick_charge_type", type);
            intent.putExtra("miui.intent.extra.POWER_MAX", watts);
            if (sActivityManager != null && sBroadcastWithFeature != null) {
                sBroadcastWithFeature.invoke(
                    sActivityManager,
                    null, null, intent, null,
                    null, -1, null, null,
                    null, null, null, -1,
                    null, false, false, -1
                );
            } else if (sActivityManager != null && sBroadcastLegacy != null) {
                sBroadcastLegacy.invoke(
                    sActivityManager,
                    null, intent, null,
                    null, -1, null, null,
                    null, -1, null, false, false, -1
                );
            }
        } catch (Throwable t) {
            sActivityManager = null;
            sBroadcastWithFeature = null;
            sBroadcastLegacy = null;
        }
    }

    private static void handleCmdFile() {
        File f = new File(CMD_FILE);
        if (!f.exists() || f.length() == 0L) return;
        String cmd = readFileTrim(CMD_FILE);
        writeFile(CMD_FILE, "");
        if (cmd.isEmpty()) return;

        if (cmd.contains("BYPASS") && cmd.contains("1")) {
            writeFile("/sys/devices/platform/charger/bypass_charger", "110\n");
        } else if (cmd.contains("BYPASS") && cmd.contains("0")) {
            writeFile("/sys/devices/platform/charger/bypass_charger", "0\n");
        } else if (cmd.contains("LED") && cmd.contains("0")) {
            writeFile(AW22_CFG, "9\n");
            writeFile(AW22_EFFECT, "0\n");
            writeFile(TRAN_LED_CMD, "00 01 00 00 00 00\n");
        } else if (cmd.contains("LED") && cmd.contains("1")) {
            writeFile(AW22_CFG, "13\n");
            writeFile(AW22_EFFECT, "7\n");
        } else if (cmd.contains("LED") && cmd.contains("2")) {
            writeFile(AW22_CFG, "4\n");
            writeFile(AW22_EFFECT, "4\n");
        } else if (cmd.contains("LED") && cmd.contains("3")) {
            writeFile(AW22_CFG, "1\n");
            writeFile(AW22_EFFECT, "1\n");
        } else if (cmd.contains("LED") && cmd.contains("4")) {
            writeFile(AW22_CFG, "0\n");
            writeFile(AW22_EFFECT, "1\n");
        } else if (cmd.contains("QC_TYPE")) {
            String[] parts = cmd.trim().split("\\s+");
            if (parts.length >= 3) {
                sendQuickChargeBroadcast(parseIntOr(parts[1], 0), parseIntOr(parts[2], 0));
            }
        }
    }

    private static void guardSysfsPermissionsIfDrifted() {
        for (String node : RGB_NODES) {
            try {
                StructStat st = Os.stat(node);
                if (st.st_uid != 0 || st.st_gid != 1000 || (st.st_mode & 0777) != 0640) {
                    Os.chown(node, 0, 1000);
                    Os.chmod(node, 0640);
                }
            } catch (Throwable ignored) {}
        }
        for (String d : DIR_NODES_0755) {
            try {
                StructStat st = Os.stat(d);
                if ((st.st_mode & 0777) != 0755) {
                    Os.chmod(d, 0755);
                }
            } catch (Throwable ignored) {}
        }
        for (String p : RW_NODES_0666) {
            try {
                StructStat st = Os.stat(p);
                if ((st.st_mode & 0777) != 0666) {
                    Os.chmod(p, 0666);
                }
            } catch (Throwable ignored) {}
        }
    }

    public static void main(String[] args) {
        System.out.println("[LH8nObserver] Zero-fork Sysfs Watchdog + Settings Sync started.");
        int ticks = 0;

        while (true) {
            try {
                // 1. Emergency 70 C thermal cutoff (pure file read, zero forks, u:r:ksu:s0)
                int socTemp = parseIntOr(readFileTrim(THERMAL_NODE), 0);
                if (socTemp >= 70000) {
                    writeFile(TRAN_LED_CMD, "00 01 00 00 00 00\n");
                    writeFile(AW22_CFG, "9\n");
                }

                // 2. Command file check (only opens if size > 0)
                handleCmdFile();

                // 3. Cached-Binder Settings sync every 5s (zero process forks / zero AVC spam)
                syncDisplayAndRefreshSettings();

                // 4. LightBelt cache sync every 30s (6 ticks) & sysfs permission stat guard every 60s (12 ticks)
                if ((ticks % 6) == 0) {
                    syncLightBeltCache();
                }
                if (ticks >= 12) {
                    ticks = 0;
                    guardSysfsPermissionsIfDrifted();
                } else {
                    ticks++;
                }
            } catch (Throwable ignored) {}

            try {
                Thread.sleep(5000L);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
}
