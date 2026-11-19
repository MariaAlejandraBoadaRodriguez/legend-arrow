# Sourced by android_e2e.sh and save_stress.sh (needs $PKG).
# v0.2 API 26 investigation (docs/qa/SAVE_INVESTIGATION.md): when a journey
# fails, record who touched the app's data directory and in what state it is,
# because the failure seen was the app's files vanishing while it ran and
# `run-as` failing at the same moment.

# System log lines that can explain a data-directory change, from a logcat file.
probe_system_lines() {   # logcat_file
  grep -iE "PackageManager|installd|clearApplicationUserData|DATA_CLEARED|Clearing|PackageInstaller|dexopt|BackupManager|FullBackup|Restore|avc: +denied|run-as|storaged|vold|DeviceStorage|Low on storage|Force stopping|Killing [0-9]+:$PKG|Process $PKG .*died|am_kill|wm_on_destroy" \
    "$1" 2>/dev/null | grep -v "GodotPluginRegistry" | tail -120 || true
}

# Current state of the app's data directory, every probe best-effort.
probe_data_dir() {
  echo "---- data dir probe ($(date -u +%H:%M:%S)) ----"
  echo "[run-as ls -la]";   adb shell "run-as $PKG ls -la" 2>&1 | head -20
  echo "[run-as ls -la files]"; adb shell "run-as $PKG ls -la files" 2>&1 | head -30
  echo "[run-as id]";       adb shell "run-as $PKG id" 2>&1 | head -3
  echo "[su ls -laZ]";      adb shell "su 0 ls -laZ /data/data/$PKG /data/data/$PKG/files" 2>&1 | head -40
  echo "[su ls -ldZ /data/user/0]"; adb shell "su 0 ls -ldZ /data/user/0/$PKG /data/data" 2>&1 | head -5
  echo "[packages.list]";   adb shell "su 0 grep $PKG /data/system/packages.list" 2>&1 | head -3
  echo "[dumpsys package]"; adb shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r' | grep -E "dataDir|codePath|firstInstallTime|lastUpdateTime|pkgFlags|privateFlags|versionCode|installerPackageName|User 0:" | head -12
  echo "[df /data]";        adb shell df /data 2>&1 | tail -1
  echo "---- end probe ----"
}
