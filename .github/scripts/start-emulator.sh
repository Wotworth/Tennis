#!/usr/bin/env bash
# Copied from Wotworth/wp-launcher .github/scripts/start-emulator.sh (main, 6 Nov 2026); unchanged below.
# Boots a headless emulator and leaves it running for later steps
# (baseline profile, smoke test). The workflow kills it at the end.
set -euo pipefail

# The standard image (not the stripped-down ATD one) so screenshots show real pixels
# for the end-to-end checks.
IMAGE="system-images;android-34;default;x86_64"
SDK="${ANDROID_HOME:?ANDROID_HOME not set}"
# Later steps need these tools on PATH too.
for d in "$SDK/cmdline-tools/latest/bin" "$SDK/emulator" "$SDK/platform-tools"; do
  echo "$d" >> "$GITHUB_PATH"
done
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/emulator:$SDK/platform-tools:$PATH"
# avdmanager and the emulator must agree on where virtual devices live.
export ANDROID_AVD_HOME="$HOME/.android/avd"
mkdir -p "$ANDROID_AVD_HOME"

echo "Freeing disk space"
sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/.ghcup /usr/local/share/boost /opt/hostedtoolcache/CodeQL /usr/local/lib/node_modules || true
df -h "$HOME" | tail -1

echo "Installing emulator and system image"
yes | sdkmanager --licenses > /dev/null || true
sdkmanager --install "emulator" "platform-tools" "$IMAGE" > "$RUNNER_TEMP/sdk.log" 2>&1 \
  || { tail -20 "$RUNNER_TEMP/sdk.log"; exit 1; }
ls -la /dev/kvm
emulator -accel-check || true

echo "Creating AVD"
echo no | avdmanager create avd --force -n bp -k "$IMAGE" -d pixel_6 -p "$ANDROID_AVD_HOME/bp.avd" > /dev/null
# Default data partition is 7 GB; the profile run needs far less.
cfg="$ANDROID_AVD_HOME/bp.avd/config.ini"
sed -i '/^disk.dataPartition.size/d; /^hw.cpu.ncore/d' "$cfg"
echo "disk.dataPartition.size=2048M" >> "$cfg"
echo "hw.cpu.ncore=2" >> "$cfg"

echo "Starting emulator"
nohup setsid emulator -avd bp -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -camera-back none -camera-front none \
  -accel on -memory 3072 -cores 2 -partition-size 2048 -no-metrics > "$RUNNER_TEMP/emulator.log" 2>&1 &
EMU_PID=$!

# Poll instead of "adb wait-for-device", which hangs forever if the emulator dies.
for i in $(seq 1 120); do
  if [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = "1" ]; then
    echo "Booted after $((i * 5)) s"
    break
  fi
  if ! kill -0 "$EMU_PID" 2> /dev/null; then
    echo "Emulator exited early:"; tail -80 "$RUNNER_TEMP/emulator.log"; exit 1
  fi
  if [ $((i % 12)) -eq 0 ]; then echo "Still booting ($((i * 5)) s)"; adb devices; fi
  sleep 5
done
if [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" != "1" ]; then
  echo "Emulator did not boot in 10 minutes:"; tail -50 "$RUNNER_TEMP/emulator.log"
  adb emu kill > /dev/null 2>&1 || kill "$EMU_PID" 2> /dev/null || true
  exit 1
fi
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
