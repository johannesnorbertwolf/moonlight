# Moonlight Android app

The complete Moonlight app for Android, native (Kotlin, Jetpack Compose): setup, Today, your night, the group board with reactions, history and settings. It measures the night with Android's usage data and uploads it to Supabase. No browser and no group choice: every Android user joins the trial group with the code in `Remote.kt` (`GROUP_CODE = "675D89"`), because this app is only sideloaded for the trial and needs no store rules. Participant steps: [SETUP.md](SETUP.md).

Requires Android 10 or newer.

## Build

Build setup: Android Gradle plugin 9.4.1 (with its built-in Kotlin), Gradle 9.9.1 via the wrapper, compile SDK 35. Tested with Android Studio 2026.2, whose bundled Java 25 needs Gradle 9.1 or newer.

1. Install **Android Studio** (it brings Java and the Android SDK).
2. Copy `local.properties.example` to `local.properties` and fill in the Supabase project URL and public key.
3. In Android Studio: **Open** → choose this `android/` folder → wait for Gradle sync.
4. Install on a phone, either:
   - **Cable:** turn on Developer options and USB debugging on the phone, connect it, press **Run**.
   - **File:** **Build → Build App Bundle(s) / APK(s) → Build APK(s)**, send `app/build/outputs/apk/release/app-release.apk` (or the debug APK) to the participant, and have them open it and allow "install unknown apps" for the app they opened it from.

From the command line instead of Android Studio:

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

The APK to share is copied to `Moonlight test.apk` (gitignored). It's signed with this Mac's debug key, so newer builds install over older ones and keep the setup.

## How it runs

Every morning at about 07:05, and whenever the app opens, it measures the last two nights and uploads them under the participant id (duplicates are ignored), then loads the group board. If the anonymous sign-in is lost, it rejoins with the saved name, which takes over the same participant.

## Files

| File | What it does |
|---|---|
| `MainActivity.kt` | Setup on first start, then the four tabs |
| `OnboardingScreen.kt` | Language → name and goal (joins the group) → usage access → battery → notifications |
| `Screens.kt` | Today, your night, group board (tap = 🌙, hold = all nine), history, settings |
| `Theme.kt` | Colors, moon icons per bucket, cards and buttons (same look as the iPhone app) |
| `AppState.kt` | App state and actions: join, load, react, goal, leave; text helper `t()` |
| `Remote.kt` | Supabase: anonymous sign-in, join_group, group_data, set_reaction, update_goal, leave_group; `GROUP_CODE` |
| `GroupModel.kt` | Buckets, nights per member, streaks (port of the iPhone `Model.swift`) |
| `Strings.kt` | English and Dutch strings, generated from `ios/Moonlight/Strings.swift` plus Android-only keys |
| `NightWindow.kt` | A night's window (goal start → 07:00) and the night date (date it starts) |
| `UsageReader.kt` | Reads `UsageEvents`, ignores launcher and system UI, merges app switches into sessions |
| `Uploader.kt` | Posts events and the night summary to Supabase under the participant id |
| `NightlyWorker.kt` | Daily 07:05 `WorkManager` job, plus the shared measure-and-upload routine |
| `MorningReminder.kt` | Daily 09:00 notification |
| `Prefs.kt` | Name, goal, participant id, session, last status |
