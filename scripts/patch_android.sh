#!/usr/bin/env bash
# Patches the auto-generated Android project so it matches our requirements:
# - minSdk 21, targetSdk/compileSdk 33 (Android 13)
# - custom URL scheme for GitHub OAuth callback
# - Internet permission (for OAuth + mail API)
set -euo pipefail

ANDROID_DIR="android"
MANIFEST="$ANDROID_DIR/app/src/main/AndroidManifest.xml"
APP_GRADLE="$ANDROID_DIR/app/build.gradle"
APP_GRADLE_KTS="$ANDROID_DIR/app/build.gradle.kts"

echo "==> Patching Android SDK levels"
if [ -f "$APP_GRADLE_KTS" ]; then
  sed -i \
    -e 's/compileSdk *= *flutter.compileSdkVersion/compileSdk = 33/' \
    -e 's/targetSdk *= *flutter.targetSdkVersion/targetSdk = 33/' \
    -e 's/minSdk *= *flutter.minSdkVersion/minSdk = 21/' \
    "$APP_GRADLE_KTS"
elif [ -f "$APP_GRADLE" ]; then
  sed -i \
    -e 's/compileSdkVersion .*/compileSdkVersion 33/' \
    -e 's/targetSdkVersion .*/targetSdkVersion 33/' \
    -e 's/minSdkVersion .*/minSdkVersion 21/' \
    "$APP_GRADLE"
fi

echo "==> Adding INTERNET permission + OAuth callback intent-filter"
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
if "android.permission.INTERNET" not in s:
    s = s.replace("<manifest", '<manifest', 1)
    s = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', s, count=1)

callback_activity = '''
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="okitakoymail" />
            </intent-filter>
        </activity>
'''
if "flutter_web_auth_2.CallbackActivity" not in s:
    s = s.replace("</application>", callback_activity + "    </application>")
p.write_text(s)
print("Manifest patched.")
PY

echo "==> Done."
