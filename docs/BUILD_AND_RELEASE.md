# ShopHisab build and release

The app remains Flutter, offline-first, with the original green visual identity.
The Android application ID stays `com.businessos.businessos`. Renaming that ID
would create a separate app and could strand existing device data. Launcher
label, in-app title and distributed APK filename are ShopHisab.

## Easy build: GitHub Actions

1. Put the CONTENTS of this project in your repository root.
2. Open Actions → Build ShopHisab → Run workflow.
3. Analyzer warnings/errors and regression test failures stop the build.
4. Download ShopHisab-APK, extract the artifact, and install ShopHisab.apk.

This workflow uses the original committed debug key so test builds can update
older builds signed with that same key. This is a TEST distribution key, not a
private production signing key. Do not uninstall an existing app to fix signing
errors without first making and independently checking an encrypted backup.

## Local build (Flutter 3.47.5; JDK 17; Android SDKs 34–36)

Use a full JDK (including `javac`), not a Java runtime alone. The app targets
SDK 36. The root Gradle configuration aligns Android library compilation to at
least SDK 36, including older plugins that declare SDK 34 or 35, so their newer
transitive dependencies pass Android metadata checks. Minimum SDK remains 24.

```bash
sdkmanager "platforms;android-34" "platforms;android-35" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "cmake;3.22.1"
flutter pub get
# Only needed if android/ is absent:
flutter create --platforms=android --org com.businessos --project-name businessos .
python3 tool/configure_android.py
dart run build_runner build
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

Output: build/app/outputs/flutter-apk/app-release.apk. Rename it ShopHisab.apk.
CI environments should set `CI=true` and `FLUTTER_SUPPRESS_ANALYTICS=true` to
avoid cloud-host environment probes and Flutter analytics.

## Play Store release

Use your own private keystore. Configure these environment variables before
building (store passwords as CI secrets, never in Git):

- SHOPHISAB_KEYSTORE: absolute path to your private keystore
- SHOPHISAB_STORE_PASSWORD
- SHOPHISAB_KEY_ALIAS
- SHOPHISAB_KEY_PASSWORD

Run `python3 tool/configure_android.py`, then `flutter build appbundle --release`.
The script uses the private release configuration only when these values are
provided. Keep the same signing identity for subsequent production updates.
Increase the pubspec build number above the last published build before upload.

## Google Drive setup

The supplied public Web OAuth client ID is preserved. Override it at build time
with `--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID` if using a new
Google project. Do not embed a client secret in the app.

Enable Drive API, configure the consent screen, and register an Android OAuth
client matching the package ID and signing SHA-1/SHA-256. Play App Signing uses
a different signing certificate from local test builds: register the production
certificate too. Configure the consent screen for your real audience and privacy
policy. Test account switching and a restore on a separate phone before release.

Local backup works without a Google account. Google Drive is an optional private
app-data backup destination, not live synchronization or a shared business server.
A successful upload does not mean multiple phones have merged their records.

## Important migration details

- Existing database name and app ID are preserved.
- Schema versions 1–5 are supported; old databases migrate automatically.
- Currency defaults to INR for existing records. New businesses choose one of
  INR, USD, EUR, GBP, AED, CAD or AUD. All supported currencies use two decimals.
- Legacy .bosb AES-CBC exports remain readable, including legacy empty-password
  files. New exports require at least 10 characters and use authenticated AES-GCM.
- Backup passphrases are separate from the app PIN. Keep them outside the phone.
- Theme, language, PIN and biometric settings are device settings and are not
  transferred by a business-record restore.
- The unrelated original native SelfTrack project is preserved in legacy_selftrack/
  and is not built as ShopHisab.
