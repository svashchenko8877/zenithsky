#!/bin/bash
# Build + install + launch Zenith Sky in the booted iPhone simulator. Extra args are passed to the app.
cd "$(dirname "$0")/.."
SIM=${SIM:-C0AF7927-FBEA-42AE-B81A-315089319C15}
xcodebuild -project Zenith.xcodeproj -scheme Zenith -destination "id=$SIM" -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error|BUILD"
APP=$(find build -name "Zenith.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install $SIM "$APP"
xcrun simctl privacy $SIM grant location com.vashchenko.zenithsky
xcrun simctl terminate $SIM com.vashchenko.zenithsky 2>/dev/null
xcrun simctl launch $SIM com.vashchenko.zenithsky "$@"
