#!/bin/bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data_path="$project_root/.build/ReleaseCheckDerivedData"

cd "$project_root"

xcodebuild test \
  -project LeafOrLeave.xcodeproj \
  -scheme LeafOrLeave \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  -only-testing:LeafOrLeaveTests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project LeafOrLeave.xcodeproj \
  -scheme LeafOrLeave \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO

app_path="$derived_data_path/Build/Products/Release/LeafOrLeave.app"
test -d "$app_path"
plutil -lint "$app_path/Contents/Info.plist"

echo "Release verification passed: $app_path"
