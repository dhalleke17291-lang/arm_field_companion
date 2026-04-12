#!/usr/bin/env bash
set -euo pipefail

cd ~/Desktop/arm_field_companion

echo "==> Clean"
flutter clean

echo "==> Get packages"
flutter pub get

echo "==> Build generated files"
dart run build_runner build --delete-conflicting-outputs

echo "==> Analyze"
flutter analyze

echo "==> Format check"
dart format --set-exit-if-changed .

echo "==> Unit and widget tests"
flutter test --coverage --reporter expanded

echo "==> Integration tests"
flutter test integration_test/ -d emulator-5554

echo "==> Android build check"
flutter build apk --debug

# Requires iOS 18.4 simulator runtime installed via Xcode → Settings → Platforms
echo "==> iOS simulator build check"
flutter build ios --simulator

echo "✅ Deep check passed"
