#!/bin/bash
# Archive Release and upload to App Store Connect (TestFlight/App Store) with automatic signing.
cd "$(dirname "$0")/.."
rm -rf build/Zenith.xcarchive build/export
xcodebuild -project Zenith.xcodeproj -scheme Zenith -configuration Release -destination 'generic/platform=iOS' -archivePath build/Zenith.xcarchive -allowProvisioningUpdates archive 2>&1 | tail -5
xcodebuild -exportArchive -archivePath build/Zenith.xcarchive -exportOptionsPlist tools/ExportOptionsUpload.plist -exportPath build/export -allowProvisioningUpdates 2>&1 | tail -15
