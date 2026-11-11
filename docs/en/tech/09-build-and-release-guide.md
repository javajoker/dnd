# tech/09 · Build and Release Guide — Android and iOS

> Status: **Android debug APK verified on this Mac (2026-11-12)**; Android release (AAB) and iOS steps are the exact procedure, not yet run here. Related: tech/06 (English mobile plan), `docs/en/store/` (listing, privacy, billing adapters), `game/export_presets.cfg`.
> Engine: **Godot 4.7.2 stable**. Commands assume the macOS Godot app at `/Applications/Godot.app` and the repo root as the working directory.

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

## 0. Export presets in this repo

| Preset | Platform | Output | Signing | Use |
|---|---|---|---|---|
| `Android Debug APK` | Android | `game/build/android/age-of-the-codex-debug.apk` | editor debug keystore | sideload on a test phone |
| `Android` | Android | `game/build/android/age-of-the-codex.aab` (Gradle) | your **upload keystore** via environment variables | Google Play |
| `iOS` | iOS | `game/build/ios/AgeOfTheCodex.ipa` (via Xcode) | your Apple team + provisioning | TestFlight / App Store |
| `Desktop PCK check` | macOS | `game/build/check/game.pck` | none | size / content check only |

All presets ship pack data (`*.json`) and the font licences, and exclude `tools/`, `tests/` and `kit/`. **No signing secret is ever stored in the repo**; `game/build/` is git-ignored.

## 1. One-time setup (both platforms)

1. **Export templates** (1.28 GB download, contains every platform):
   ```bash
   curl -fL -o /tmp/godot_templates.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
   mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
   unzip -j -o /tmp/godot_templates.tpz 'templates/android_*' 'templates/ios.zip' 'templates/version.txt' \
     -d "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
   rm /tmp/godot_templates.tpz
   ```
   (Or in the editor: *Editor → Manage Export Templates → Download and Install*.) Only the Android and iOS files are kept to save ~1 GB.
2. **Re-import once** after a fresh clone: `$GODOT --headless --path game --import`.
3. **Run the checks before any release build**:
   ```bash
   $GODOT --headless --path game -s tests/run.gd
   ```
   ```bash
   $GODOT --headless --path game -s tools/packlint.gd -- packs/campaign01
   ```

## 2. Android

### 2.1 Tools (one time)

1. **JDK 17** (Godot 4.x Android export needs 17; older JDKs fail):
   ```bash
   brew install openjdk@17
   ```
   Path: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`.
2. **Android SDK** command-line tools, then platform-tools and build-tools (requires accepting Google's Android SDK licences):
   ```bash
   SDK=$HOME/Library/Android/sdk; mkdir -p $SDK/cmdline-tools
   curl -fL -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
   unzip -q /tmp/clt.zip -d /tmp/clt && mv /tmp/clt/cmdline-tools $SDK/cmdline-tools/latest && rm -rf /tmp/clt /tmp/clt.zip
   export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
   yes | $SDK/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK --licenses
   $SDK/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK "platform-tools" "build-tools;35.0.0"
   ```
   For release AABs also install the platform: `sdkmanager --sdk_root=$SDK "platforms;android-35"`.
3. **Godot editor settings** (*Editor → Editor Settings → Export → Android*, or `~/Library/Application Support/Godot/editor_settings-4.7.tres`):
   - `Java SDK Path` = the JDK 17 path above;
   - `Android SDK Path` = `~/Library/Android/sdk`;
   - `Debug Keystore` = `~/Library/Application Support/Godot/keystores/debug.keystore` (the editor creates it; user `androiddebugkey`, the standard debug password).

### 2.2 Debug APK (test phones)

Project setting already committed: *Rendering → Textures → VRAM Compression → Import ETC2 ASTC* = on (`textures/vram_compression/import_etc2_astc=true`) — Android export refuses to run without it. After changing it, re-import (`--import`).


```bash
mkdir -p game/build/android
$GODOT --headless --path game --export-debug "Android Debug APK" build/android/age-of-the-codex-debug.apk
```

Verify and install (USB debugging on, phone plugged in):

```bash
$HOME/Library/Android/sdk/build-tools/35.0.0/apksigner verify --print-certs game/build/android/age-of-the-codex-debug.apk
```

```bash
$HOME/Library/Android/sdk/platform-tools/adb install -r game/build/android/age-of-the-codex-debug.apk
```

Result on 2026-11-12: `age-of-the-codex-debug.apk`, 65 MB, arm64-v8a, `com.example.ageofthecodex` 1.0.0 (code 1), target SDK 36, APK signature v2 + v3 with the debug key; contains the 50 pack JSON files and the font licences, no `tools/` / `tests/` / `kit/`. The Godot runtime is ~73 MB of it uncompressed.

Without a cable: copy the APK to the phone and open it (allow "install unknown apps" for the file manager). The debug build is arm64 only (all current phones); emulators need `architectures/x86_64=true` in the preset.

### 2.3 Release AAB (Google Play)

1. **Package id:** replace `com.example.ageofthecodex` in preset `Android` (`package/unique_name`) with your own reverse-domain id — Play rejects `com.example.*`, and the id can never change after the first upload. Bump `version/code` (integer, +1 every upload) and `version/name` per release.
2. **Upload keystore** (create once, keep it and its passwords outside the repo, back it up — losing it means Play App Signing key reset):
   ```bash
   keytool -genkeypair -v -keystore ~/keys/age-of-the-codex-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```
3. **Gradle build template** (the preset uses Gradle for AABs): in the editor *Project → Install Android Build Template* — creates `game/android/build/` (commit it; it is the Android project source). Install the SDK platform `platforms;android-35` (2.1).
4. **Export** with the keystore passed through environment variables (never written to `export_presets.cfg`):
   ```bash
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/age-of-the-codex-upload.jks
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='<your keystore password>'
   $GODOT --headless --path game --export-release "Android" build/android/age-of-the-codex.aab
   ```
   The first Gradle build downloads ~1 GB of dependencies.
5. **Play Console:** create the app, enable **Play App Signing**, upload the AAB to an **internal testing** track, add testers, then fill the listing (`docs/en/store/store-listing.md`), Data safety and content rating. In-app purchases need the billing plugin (`docs/en/store/billing-adapter.md`).

## 3. iOS

### 3.1 Requirements

- A Mac with the **full Xcode** from the App Store (the command-line tools alone are not enough), opened once to install its components and accept its licence: `sudo xcodebuild -license accept`.
- An **Apple Developer Program** membership (paid) and your **Team ID** (Membership page, 10 characters).
- In Xcode → Settings → Accounts, sign in with the developer Apple ID so Xcode can manage signing.
- The `ios.zip` export template (step 1.1).

### 3.2 Configure the preset (`iOS` in `export_presets.cfg`, or the export dialog)

- `application/app_store_team_id` = your Team ID (currently empty);
- `application/bundle_identifier` = your id (currently `com.example.ageofthecodex`; must match the App ID you create in the developer portal);
- `application/short_version` / `application/version` = marketing version / build number (+1 every upload);
- Icons, launch storyboard (key art) and portrait-only orientation are already set; minimum iOS 15.

### 3.3 Build

```bash
mkdir -p game/build/ios
$GODOT --headless --path game --export-release "iOS" build/ios/AgeOfTheCodex.ipa
```

Godot writes an Xcode project next to the output and runs `xcodebuild` to produce the signed `.ipa` (automatic signing with your team). If signing fails, open the generated `.xcodeproj` in Xcode, pick your team under *Signing & Capabilities*, then *Product → Archive* and *Distribute App → App Store Connect*.

### 3.4 Device test and release

- **Quick device test:** in Xcode select your plugged-in iPhone and press Run (the generated project), or install a development-signed build.
- **TestFlight:** upload the archive (Xcode Organizer or Transporter), add internal testers in App Store Connect.
- **Release:** App Store Connect listing, privacy labels (`docs/en/store/privacy-policy.md`), in-app purchases (`billing-adapter.md`), then submit for review.

## 4. Before every store upload

- [ ] Tests, packlint and the bot simulation green (section 1)
- [ ] Version code / build number bumped; package / bundle id final
- [ ] Real-device pass on at least one small and one large phone: safe areas, portrait lock, text size, purchase + restore (store sandbox)
- [ ] Icon and splash look right on the device (Android adaptive mask; iOS icon set)
- [ ] Credits / licences reachable (fonts are SIL OFL; texts ship in `assets/fonts/`)
