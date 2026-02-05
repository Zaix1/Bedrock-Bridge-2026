#!/bin/bash
set -e  # Stop immediately if anything fails

# --- CONFIGURATION ---
# Change this number when you are ready for 1.0.1 or 2.0.0
STABLE_VERSION="4.0.0"
# ---------------------

# Generate a hidden internal number so the phone accepts the update
INTERNAL_BUILD_ID=$(date +%s)

echo "🚀 Building Official Stable Release: v$STABLE_VERSION"

# Build the APK
# We force the name to be "1.0.0" so it looks clean,
# but we use the timestamp for the internal number so updates works.
flutter build apk --release --build-number=$INTERNAL_BUILD_ID --build-name="$STABLE_VERSION"

echo "📤 Uploading Stable Release to Firebase..."

firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
--app "1:1032660381224:android:64f3f0d9d231d85ff68f1d" \
--testers "mohamedyounis93838@gmail.com" \
--release-notes "⭐ OFFICIAL STABLE RELEASE v$STABLE_VERSION"

echo "✅ Success! Version $STABLE_VERSION is ready on your phone."