#!/usr/bin/env bash
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
APP_GRADLE="android/app/build.gradle"

echo "==> Patching SDK levels to 33"
if [ -f "$APP_GRADLE" ]; then
  sed -i \
    -e 's/compileSdkVersion .*/compileSdkVersion 33/' \
    -e 's/targetSdkVersion .*/targetSdkVersion 33/' \
    -e 's/minSdkVersion .*/minSdkVersion 33/' \
    "$APP_GRADLE"
fi

echo "==> Setting app label to 'Okitakoy Mail'"
sed -i 's/android:label=".*"/android:label="Okitakoy Mail"/' "$MANIFEST"

echo "==> Adding INTERNET permission"
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i '/<manifest[^>]*>/a\    <uses-permission android:name="android.permission.INTERNET"/>' "$MANIFEST"
fi

echo "==> Adding signing config to build.gradle"
if [ -f "$APP_GRADLE" ]; then
  if ! grep -q "signingConfigs" "$APP_GRADLE"; then
    sed -i '/android {/a\
    signingConfigs {\
        release {\
            storeFile file("keystore.jks")\
            storePassword System.getenv("KEYSTORE_PASSWORD")\
            keyPassword System.getenv("KEY_PASSWORD")\
            keyAlias System.getenv("KEY_ALIAS")\
        }\
    }' "$APP_GRADLE"
  fi
  sed -i '/buildTypes {/,/}/ s/signingConfig signingConfigs.debug/signingConfig signingConfigs.release/' "$APP_GRADLE"
fi

echo "==> Done."
