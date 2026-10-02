#!/bin/zsh
set -euo pipefail
GYMBLOCK_PROJECT="$(cd "$(dirname "$0")" && pwd)"
GYMBLOCK_WORK="$GYMBLOCK_PROJECT/build"
mkdir -p "$GYMBLOCK_WORK"
GYMBLOCK_DEVICE="$(xcrun simctl list devices available --json | python3 -c 'import sys,json; devices=[d for ds in json.load(sys.stdin)["devices"].values() for d in ds if "iPhone" in d["name"]]; chosen=next((d for d in devices if d["state"]=="Booted"),devices[0] if devices else None); print(chosen["udid"] if chosen else "")')"
if [[ -z "$GYMBLOCK_DEVICE" ]]; then
  print 'No available iPhone simulator. Add one in Xcode Device Hub first.'
  exit 1
fi
xcrun simctl boot "$GYMBLOCK_DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$GYMBLOCK_DEVICE" -b
xcodebuild -project "$GYMBLOCK_PROJECT/GymBlock.xcodeproj" -scheme GymBlock -destination "platform=iOS Simulator,id=$GYMBLOCK_DEVICE" -derivedDataPath "$GYMBLOCK_WORK/DerivedData" build
xcrun simctl install "$GYMBLOCK_DEVICE" "$GYMBLOCK_WORK/DerivedData/Build/Products/Debug-iphonesimulator/GymBlock.app"
xcrun simctl terminate "$GYMBLOCK_DEVICE" com.sirish.gymblock.prototype 2>/dev/null || true
xcrun simctl launch "$GYMBLOCK_DEVICE" com.sirish.gymblock.prototype --demo
open -b com.apple.dt.Devices
print 'GymBlock is running. Select the iPhone in Device Hub to use it.'
