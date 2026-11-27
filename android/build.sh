#!/bin/bash
# Builds MD Reader for Android without Gradle, straight from the SDK tools.
#   android/build.sh            build build/MDReader.apk and install it on the connected phone
#   android/build.sh --no-install
# Needs: Android SDK (build-tools 35, platform android-35), JDK 17, adb. The web viewer is
# android/web: the Android copy, split from the Mac app's ../Web so the two evolve separately.
set -euo pipefail
cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
BT="$SDK/build-tools/35.0.0"
PLATFORM="$SDK/platforms/android-35/android.jar"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export PATH="$JAVA_HOME/bin:$PATH"
KEYSTORE="$HOME/.android/debug.keystore"
OUT=build

rm -rf "$OUT" && mkdir -p "$OUT"/{res-gen,compiled,classes,dex,gen,assets}

echo "==> icon + assets"
swift ../tools/make-android-icon.swift "$OUT/res-gen" 2>&1 | grep -v "search path" || true
cp -R web "$OUT/assets/web"

echo "==> resources"
"$BT/aapt2" compile --dir res -o "$OUT/compiled/res.zip"
"$BT/aapt2" compile --dir "$OUT/res-gen" -o "$OUT/compiled/gen.zip"
"$BT/aapt2" link -o "$OUT/unsigned.apk" -I "$PLATFORM" --manifest AndroidManifest.xml \
    -A "$OUT/assets" --java "$OUT/gen" --auto-add-overlay \
    "$OUT/compiled/res.zip" "$OUT/compiled/gen.zip"

echo "==> java → dex"
javac -source 8 -target 8 -bootclasspath "$PLATFORM" -classpath "$BT/core-lambda-stubs.jar" -Xlint:-options -encoding UTF-8 \
    -d "$OUT/classes" $(find src "$OUT/gen" -name '*.java')
"$BT/d8" --release --min-api 26 --lib "$PLATFORM" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
(cd "$OUT/dex" && zip -q -u ../unsigned.apk classes.dex)

echo "==> align + sign"
if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$(dirname "$KEYSTORE")"
    keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android -alias androiddebugkey \
        -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000
fi
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey --out "$OUT/MDReader.apk" "$OUT/aligned.apk"
echo "==> built android/$OUT/MDReader.apk ($(du -h "$OUT/MDReader.apk" | cut -f1))"

if [[ "${1:-}" != "--no-install" ]]; then
    adb install -r "$OUT/MDReader.apk"
    echo "==> installed on $(adb shell getprop ro.product.model | tr -d '\r')"
fi
