#!/bin/zsh
# Builds dist/BudgetApp.ipa for sideloading with AltStore/SideStore (they re-sign it with the user's Apple ID).
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=$(mktemp -d)
xcodegen generate
xcodebuild -project BudgetApp.xcodeproj -scheme BudgetApp -configuration Release -sdk iphoneos \
  -derivedDataPath "$BUILD/dd" build CODE_SIGNING_ALLOWED=NO | grep -E "error|BUILD" || true

APP="$BUILD/dd/Build/Products/Release-iphoneos/BudgetApp.app"
[[ -d "$APP" ]] || { echo "Build failed"; exit 1; }

# Ad-hoc sign so the App Group entitlement is embedded; AltStore reads it to set up the widget's shared data.
codesign -f -s - --entitlements BudgetWidget/BudgetWidget.entitlements "$APP/PlugIns/BudgetWidget.appex"
codesign -f -s - --entitlements BudgetApp/BudgetApp.entitlements "$APP"

mkdir -p "$BUILD/ipa/Payload" dist
cp -R "$APP" "$BUILD/ipa/Payload/"
(cd "$BUILD/ipa" && zip -qry BudgetApp.ipa Payload)
cp "$BUILD/ipa/BudgetApp.ipa" dist/BudgetApp.ipa
rm -rf "$BUILD"
echo "Built dist/BudgetApp.ipa"
