#!/bin/bash
set -e  # <--- This stops the script immediately if the build fails

# 1. Generate unique Version
VERSION_CODE=$(date +%s)
DATE_TIME=$(date "+%Y-%m-%d %H:%M")

echo "🚀 Building new version: 1.0.$VERSION_CODE"

# 2. Build the APK
flutter build apk --release --build-number=$VERSION_CODE --build-name="1.0.$VERSION_CODE"

# 3. Upload to Firebase
echo "📤 Uploading to Firebase..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
--app "1:1032660381224:android:64f3f0d9d231d85ff68f1d" \
--testers "mohamedyounis93838@gmail.com" \
--release-notes "Update: $DATE_TIME"

echo "✅ Done! Check your phone for version 1.0.$VERSION_CODE"