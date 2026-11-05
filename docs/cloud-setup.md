# Cloud session setup

Paste this as the cloud environment's setup script (title bar → environment menu → Edit → Setup script). It installs the Android SDK, and points Gradle and Robolectric at Google's mirror of Maven Central, because Maven Central's own hosts return "429 Too Many Requests" from cloud sessions. It always exits 0. It also installs Android 36, which the wp-launcher sessions in the same environment need.

```bash
#!/bin/bash
export ANDROID_HOME=/opt/android-sdk
if [ ! -d "$ANDROID_HOME/platforms/android-37.0" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools" && cd /tmp || exit 0
  CLT=$(curl -sSfL https://dl.google.com/android/repository/repository2-3.xml | grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' | sort -V | tail -1)
  curl -sSfL -o clt.zip "https://dl.google.com/android/repository/$CLT" || exit 0
  unzip -q -o clt.zip -d "$ANDROID_HOME/cmdline-tools" && rm -rf "$ANDROID_HOME/cmdline-tools/latest" && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" && rm -f clt.zip
  yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1
  "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --install "platforms;android-37.0" "platforms;android-36" "build-tools;37.0.0" "build-tools;36.0.0" "platform-tools" >/dev/null 2>&1
fi
mkdir -p ~/.gradle/init.d
cat > ~/.gradle/init.d/maven-mirror.gradle <<'G'
def fix = { repos -> repos.withType(MavenArtifactRepository).configureEach { r -> def u = r.url.toString(); if (u.contains('repo.maven.apache.org') || u.contains('repo1.maven.org')) r.url = 'https://maven-central.storage-download.googleapis.com/maven2/' } }
settingsEvaluated { s -> fix(s.pluginManagement.repositories); fix(s.dependencyResolutionManagement.repositories) }
allprojects { fix(repositories); buildscript { fix(repositories) } }
G
grep -q ANDROID_HOME ~/.bashrc 2>/dev/null || echo 'export ANDROID_HOME=/opt/android-sdk' >> ~/.bashrc
grep -q ROBOLECTRIC_REPO_URL ~/.bashrc 2>/dev/null || echo 'export ROBOLECTRIC_REPO_URL=https://maven-central.storage-download.googleapis.com/maven2' >> ~/.bashrc
exit 0
```

Local check before pushing:
`./gradlew :app:assembleRelease :app:testDebugUnitTest -Proborazzi.test.record=true`
