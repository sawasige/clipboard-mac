#!/bin/bash
set -euo pipefail

APP_NAME="Clipnyx"
SCHEME="Clipnyx"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_DIR}/Clipnyx/Clipnyx.xcodeproj"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export-appstore"
EXPORT_OPTIONS="${PROJECT_DIR}/scripts/ExportOptions-AppStore.plist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving ${APP_NAME}..."
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Uploading to App Store Connect..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Done! Build uploaded to App Store Connect."
echo "    Check TestFlight tab in App Store Connect for the build."
