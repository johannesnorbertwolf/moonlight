# Moonlight iPhone app

Native SwiftUI app that measures the night with Apple's **Screen Time API** (Family Controls + DeviceActivity) and shows the group board, reactions and history, the same screens as the web app. Replaces the Shortcuts route for iPhone users; Android and the web app keep working alongside it.

## How the measurement works

Apple never gives an app raw usage minutes or app names. What it allows:

1. The app asks for Screen Time permission for this person (`AuthorizationCenter.requestAuthorization(for: .individual)`).
2. The person picks what counts in Apple's picker (all categories → all apps, including ones installed later).
3. The app schedules a repeating window, goal time → 07:00, with four events: 2, 5, 15 and 60 minutes of use inside the window.
4. iOS wakes the **monitor extension** (`MonitorExtension/NightMonitor.swift`) at window start, when a threshold is reached, and at window end. It writes "at least N minutes" (and the time 2 minutes were reached) into the App Group and uploads it to Supabase through `report_screen_time_night()` (migration 0004).
5. When the app opens, it uploads anything still pending and loads the group.

So an iPhone-app night is "phone-free" (< 2 min), or "at least 2 / 5 / 15 / 60 minutes": exactly the buckets from CONCEPT.md §3. A night with no report shows as "Not reported".

Known iOS behavior handled: thresholds that fire right after the window starts (a bug on some iOS versions) are ignored, because N minutes can't have been used less than N minutes in. Settings → Diagnostics shows what the extension recorded and its log.

## Build

```bash
cd ios
xcodegen generate     # only after changing project.yml; the generated project is committed
open Moonlight.xcodeproj
```

Team `8XRKL83C4V`, bundle IDs `nl.moonlight.app` and `nl.moonlight.app.monitor`, App Group `group.nl.moonlight.app`, automatic signing. Select your iPhone and press Run.

Debug builds launched with the argument `-demo` show a made-up group (Scheme → Run → Arguments), for checking screens in the simulator. Screen Time itself doesn't work in the simulator.

## Distribution: the Family Controls entitlement

- **Development** (Xcode → Run on a phone registered in your account): works now with the paid account.
- **TestFlight and App Store** need Apple's **Family Controls (Distribution)** entitlement, which you request per bundle ID at <https://developer.apple.com/contact/request/family-controls-distribution>. Request it for both `nl.moonlight.app` and `nl.moonlight.app.monitor`. Approval takes days to weeks.
- Until then, other participants' iPhones can run development builds: register each phone's UDID in the developer account (Xcode does this when the phone is plugged in) and install from Xcode. Development installs last as long as the profile (a year), not 7 days.

## Files

| File | What it does |
|---|---|
| `project.yml` | XcodeGen spec (targets, signing, entitlements) |
| `Shared/Shared.swift` | Night window, App Group store, upload; used by app and extension |
| `MonitorExtension/NightMonitor.swift` | The DeviceActivity monitor: window start/end, thresholds |
| `Moonlight/ScreenTime.swift` | Permission, app picker selection, the nightly schedule |
| `Moonlight/Remote.swift` | Supabase: anonymous sign-in, join, group data, reactions, goal |
| `Moonlight/Model.swift` | Buckets, nights per member (port of `web/estimate.js` and `web/data.js`), streaks |
| `Moonlight/AppModel.swift` | App state, rejoin, reactions, the 09:00 local reminder |
| `Moonlight/OnboardingView.swift` | Welcome → name and goal → Screen Time → what counts → notifications |
| `Moonlight/Screens.swift` | Today, your night, group (tap = 🌙, hold = all nine), history |
| `Moonlight/SettingsView.swift` | Goal time, Screen Time status, language, diagnostics |
| `Moonlight/Strings.swift` | English and Dutch strings (same keys as `web/i18n.js`) |
| `Moonlight/DemoGroup.swift` | Made-up group for `-demo` (debug only) |

## Not yet

- **Push when everyone has reported:** needs an APNs key and a Supabase Edge Function. For now the app sets a daily local reminder at 09:00.
- Changing the goal time takes effect from the next window (iOS restarts the schedule).
