#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'Xcode is required on macOS'; exit 1; }
if ! command -v xcodegen >/dev/null; then
  echo 'XcodeGen not found. Install with: brew install xcodegen'
  exit 1
fi
xcodegen generate
printf '\n✅ Created StreamLab.xcodeproj\n'
echo 'Next: open StreamLab.xcodeproj'
echo 'Build: xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -sdk iphonesimulator -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build'
