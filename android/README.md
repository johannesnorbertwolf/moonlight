# Moonlight measurement test: Android app

A bare-bones app for the measurement test (see `../docs/measurement-test.md`). It reads the phone's usage data for last night's window, turns it into "phone in use" sessions, and uploads them to Supabase as `open`/`close` events (the same format the iPhone Shortcuts send), plus its own precise minutes for comparison.

Requires Android 10 or newer.

## Build

Build setup: Android Gradle plugin 9.4.1 (with its built-in Kotlin), Gradle 9.9.1 via the wrapper, compile SDK 35. Tested with Android Studio 2026.2, whose bundled Java 25 needs Gradle 9.1 or newer.

1. Install **Android Studio** (it brings Java and the Android SDK).
2. Copy `local.properties.example` to `local.properties` and fill in the Supabase project URL and public key.
3. In Android Studio: **Open** → choose this `android/` folder → wait for Gradle sync.
4. Install on a phone, either:
   - **Cable:** turn on Developer options and USB debugging on the phone, connect it, press **Run**.
   - **File:** **Build → Build App Bundle(s) / APK(s) → Build APK(s)**, send `app/build/outputs/apk/release/app-release.apk` (or the debug APK) to the participant, and have them open it and allow "install unknown apps" for the app they opened it from.

## On the phone

1. Open **Moonlight test**, enter the participant name and goal time, tap **Save**.
2. **Open usage access settings** → find *Moonlight test* → allow.
3. **Open battery optimization settings** → set *Moonlight test* to not optimized / unrestricted. On Samsung also check *Settings → Battery → Background usage limits* and keep the app out of "sleeping apps".
4. Tap **Measure last night now and upload** once to check the connection. The status line shows the result or the error.

From the command line instead of Android Studio:

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

## After installing

After that it runs on its own every morning at about 07:05 and re-uploads the last two nights (duplicates are ignored).

## Files

| File | What it does |
|---|---|
| `NightWindow.kt` | Works out a night's window (goal start → 07:00) and the night date (date it starts) |
| `UsageReader.kt` | Reads `UsageEvents`, ignores launcher and system UI, merges app switches into sessions, computes precise minutes and when the 2-minute margin was crossed |
| `Uploader.kt` | Posts events and the night summary to Supabase's REST API |
| `NightlyWorker.kt` | Daily `WorkManager` job, plus the shared measure-and-upload routine |
| `MainActivity.kt` | Test screen: name, goal time, permission buttons, "measure now" |
| `Prefs.kt` | Stores name, goal time and the last status line |
