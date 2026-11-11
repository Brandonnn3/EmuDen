#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
archive=$(python3 -c 'import json; d=json.load(open("TestFlight/AppInformation.json")); print("build/TestFlight/EmuDen-"+d["version"]+"-"+d["build"]+".xcarchive")')
mkdir -p build/TestFlight
if [ -e "$archive" ]; then
    echo "Archive already exists: $archive. Preserve it or increment the build number before archiving again."
    exit 1
fi
python3 Scripts/validate-testflight.py
xcodebuild archive -project EmulatorApp.xcodeproj -scheme Emulator \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath build/TestFlightDerivedData -archivePath "$archive" -jobs 2
python3 Scripts/validate-testflight.py "$archive"
