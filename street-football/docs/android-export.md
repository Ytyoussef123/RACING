# Getting the game on your Android phone

There are two ways. **Way A needs nothing on your PC** and is the one to use for phase tests.

## Way A: download the APK built by GitHub (recommended)

Every push that changes `street-football/` starts the workflow **"Street Football - Android debug APK"**.

1. On your phone (or PC), open the repository on github.com and tap **Actions**. You must be signed in to GitHub.
2. Open the latest run of **Street Football - Android debug APK** for your branch. Wait for the green check (about 3–5 minutes).
3. At the bottom, under **Artifacts**, tap **street-football-debug-apk-…**. You get a `.zip` file.
4. Open the zip in your phone's **Files** app and extract `street-football-debug.apk`.
5. Tap the APK. The first time, Android asks you to allow **"Install unknown apps"** for the Files app (or your browser). Allow it, go back, then tap **Install**.
6. Open **Street Football 5v5** from your app drawer.

All CI builds are signed with the same debug key (`.github/keystore/debug.keystore`), so a new build installs over the old one without uninstalling.
If Android says "App not installed" (for example after a build you made yourself with another key), uninstall the old version first.

If the run is red, the build failed: open it to see the log, or tell Claude.

## Way B: export from Godot on your PC

### One-time setup

1. **Godot 4.7.2**, standard version (not .NET), from godotengine.org.
2. **Export templates:** in Godot, *Editor → Manage Export Templates → Download and Install*.
3. **Java JDK 17:** install "Temurin 17" from adoptium.net.
4. **Android SDK:** the easiest way is to install **Android Studio**, open it once and let it install the SDK. In *SDK Manager* make sure **Android SDK Platform-Tools** and **Android SDK Build-Tools** are installed. Note the SDK path shown at the top (on Windows usually `C:\Users\<you>\AppData\Local\Android\Sdk`).
5. In Godot: *Editor → Editor Settings → Export → Android*:
   - **Java SDK Path:** the JDK 17 folder (for example `C:\Program Files\Eclipse Adoptium\jdk-17...`).
   - **Android SDK Path:** the SDK folder from step 4.
   - **Debug Keystore:** pick `.github/keystore/debug.keystore` from this repository. **Debug Keystore User:** `androiddebugkey`, **Debug Keystore Pass:** `android`. Using the same key as the CI builds means your own builds and the CI builds install over each other.
6. Open the project: in the Godot Project Manager, *Import* → select `street-football/project.godot`.

### Export the APK

1. *Project → Export…* and select the **Android** preset (already configured: arm64, landscape, immersive).
2. Click **Export Project…**, keep **Export With Debug** ticked, and save it as `street-football-debug.apk`. The `build/` folder is ignored by git.
3. Copy the APK to your phone (USB cable, Google Drive, e-mail…) and install it as in Way A, steps 5–6.

### Optional: one-click install over USB

1. On the phone, enable **Developer options** (*Settings → About phone →* tap **Build number** 7 times), then turn on **USB debugging**.
2. Plug in the phone and accept the "Allow USB debugging" prompt.
3. In Godot, the **Android** button appears at the top right of the editor: click it to build, install and launch the game on the phone in one step.
   Or from a terminal: `adb install -r street-football-debug.apk`.

## What to check in the Phase 1 test

- The app opens in **landscape** with the dark screen, the yellow title and the orange stripe at the bottom.
- **Tap me** counts your taps.
- The language button switches English ↔ French (all texts change).
- The **FPS** counter at the top right shows about 60.
- The bottom line shows your screen size, "Android" and the Godot version.
- Turning the phone upside down flips the screen (both landscape directions are allowed).
