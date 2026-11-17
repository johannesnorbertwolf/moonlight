# Moonlight: concept

*Working name. Status: concept plus measurement test. Last updated 2026-11-17.*

## 1. Why this app exists

Moonlight supports an intervention against phone use before sleep. The intervention has three parts, which follow the Theory of Planned Behavior:

| Part | Targets | Role of the app |
|---|---|---|
| Lecture (VIP or Studium Generale): the harms of late-night screen time, the benefits of sleep, and wind-down strategies | Attitude and perceived behavioral control | None directly; the app can repeat wind-down tips |
| 2-week challenge with a personal goal (proposed: phone down by 21:00) | Subjective norms | **The core of the app**: measure each night and compare within a group |
| Evaluation | | Provides the measured data |

The app measures whether you used your phone during your night window. Every morning it reports how everyone in your group did, and sends a notification that compares you with each other.

## 2. Scope of the first version

- **Platforms:** iPhone and Android. **Devices measured:** the phone only.
- **Group size:** at least 2, no upper limit. The first trial runs with **4 people** (2 iPhones, 2 Android phones).
- **One group for now.** The data model supports several groups, but the app assumes everyone is in one.
- **Language:** English and Dutch.
- **No accounts.** You type your name and the group code once (see §8).
- **No paid Apple developer account.** This rules out a native iPhone app that uses Screen Time or push notifications (see §4), and it shapes the whole architecture.

### Architecture

| Part | iPhone | Android |
|---|---|---|
| Measuring | Two **Shortcuts automations** ("app opened" / "app closed") send each event to the server | Small **native Kotlin app** reads the phone's usage data and uploads the same kind of events |
| Screens (board, history, reactions) | **Web app** added to the home screen | The same web app, shown inside the Android app |
| Morning notification | Web push (home-screen web apps support it since iOS 16.4) | Firebase Cloud Messaging (Google's free push service) through the Android app |
| Backend | **Supabase** (Postgres database plus server functions) | same |

The screens are built once as a web app, so both platforms look identical.

## 3. Core rules

These rules are the same on both platforms.

### The night window
- Each person picks their own **start time** (default 21:00). The window always **ends at 07:00**.
- A night belongs to the date it **starts** on, so the night 17→18 November is "night of 17 November".
- A changed start time applies from the next night, never the current one.
- Times are in the group's time zone (Europe/Amsterdam for the trial).

### Measuring a night
Both platforms send **app opened** and **app closed** events. The server combines them into usage sessions and estimates the time spent during the window. Android could measure more precisely, but it uses the same method so both platforms are judged equally.

| Bucket | Estimated use in window | Shown as | Counts as success |
|---|---|---|---|
| `free` | under 2 min | Full moon | Yes (2 min is the margin of error) |
| `light` | 2–5 min | Large crescent | No |
| `medium` | 5–15 min | Crescent | No |
| `heavy` | 15–60 min | Thin crescent | No |
| `very_heavy` | over 60 min | Dark moon | No |
| `missing` | no data by 09:00 (Android only, see below) | Grey moon with "?" | Not counted, shown separately |

- `crossed_at`: the moment estimated use reached 2 minutes, roughly when the night "broke".
- **Sessions with no "closed" event** (for example the phone was locked while an app was open) are capped at a maximum length. The measurement test decides the exact rule.
- **iPhone can't report "missing".** If the automation doesn't fire, no events arrive, which looks the same as a phone-free night. This is a known weakness of the Shortcuts route and has to be checked in the test.

### Streaks
- **Personal streak:** consecutive nights with bucket `free`. A `missing` night pauses the streak without breaking it.
- **Group streak:** consecutive nights on which every member who reported was `free`.

## 4. Measurement per platform

### Why not Screen Time on iPhone
Apple's Screen Time API (Family Controls) and push notifications both require a **paid** Apple Developer account; free accounts can't enable them (Apple confirmed this on its developer forums, October 2025). Free installs also expire after 7 days. So the iPhone side uses no native app at all.

### iPhone: Shortcuts automations
- Each participant creates two personal automations in Apple's built-in **Shortcuts** app: "When [apps] are **opened**" and "When [apps] are **closed**", both set to **Run Immediately**, without notification.
- Each runs a small shortcut that sends `{participant, platform: ios, kind: open|close, occurred_at}` to Supabase.
- Logging both opening and closing matters: someone who opens an app at 20:55 and scrolls until 23:00 is caught by the "closed" event.
- **Limits:** only apps selected in the automation count (participants select all their apps); events are lost if the phone is offline; people can turn the automation off.
- **To verify in the test:** does it fire reliably and silently, also at night? Does a locked phone produce a "closed" event? How much does the estimate differ from the phone's own Screen Time numbers?

### Android: native measuring app
- **Permission:** the user turns on "Usage access" for Moonlight in the Settings app (`PACKAGE_USAGE_STATS`).
- **How:** at about 07:05 a `WorkManager` job reads the `UsageEvents` for the window and uploads app foreground and background changes as `open`/`close` events (the same format as iPhone). Launcher (home screen) and system UI events are ignored.
- **During the test only**, it also uploads its own precise usage minutes, so we can see how good the open/close estimate is.
- **Limits:** battery savers on some brands (Samsung, Xiaomi, etc.) delay background work, so onboarding asks the user to exempt the app.

### Which apps count
All apps, with no exceptions for now (calls, alarm and music included).

## 5. Morning flow

```
07:00          window ends
07:00–09:00    Android phones upload their night (iPhone events arrive live all night)
               after each upload: has everyone reported?
                 yes → build summary, send notification to all members now
09:00          for groups not yet notified: mark missing members, send anyway
```

- One summary notification per group per morning, never more.
- Sent from a Supabase scheduled function: web push for iPhone, Firebase Cloud Messaging for Android.
- **Notification text examples:**
  - "3 of 4 slept phone-free. Alex was on their phone for 5–15 min. Group streak: 4 nights."
  - "Everyone made it. 4 of 4 phone-free, best night yet."
  - "2 of 4 phone-free. Jo hasn't reported yet."

## 6. Social features

### Group board
- Names are shown. Each member has a row with name, moon, bucket and goal time.
- A 7-night grid shows every member's moons. Group streak at the top.

### Automatic messages
Written by the app, identical for every group, so the evaluation stays fair. Examples: group streak milestones (3, 7, 14 nights), "everyone made it", "back on track after a missed night", and the end of the challenge.

### Reactions
- **Nine reactions**, in this order: 🌙 👏 🔥 😴 ❤️ 🛌 🦉 🦥 🥱 (system emoji for now).
- **Tap** a member's result → 🌙. **Press and hold** → a row of all nine; slide and release to pick. Scrolls sideways on small screens.
- One reaction per person per result; it can be changed or removed.
- All nine are allowed on every night, including missed ones. We assume people are kind to each other; if it stings in the trial, we can limit them to successful nights.
- **Reactions never send a notification**, and can only be given outside night windows, so the app never invites late-night use.

## 7. Screens (web app)

1. **Onboarding:** name and group code, explanation, goal time, notifications. Then platform setup: on iPhone, a guided walkthrough for the two Shortcuts automations and "Add to Home Screen"; on Android, usage access and battery exemption.
2. **Home, evening:** tonight's window ("starts at 21:00"), wind-down tip, current streak.
3. **Morning recap:** your night (ring showing the phone-free share, timeline with the time the night broke), then a link to the group board.
4. **Group board:** see §6.
5. **History:** moon calendar of the challenge (14 nights) and further back.
6. **Settings:** name, goal time, notifications, privacy info.

Visual style: a dark night-sky purple background, warm moon yellow for success, muted purple for missed nights, a calm look with no bright colors (see the design sketches).

## 8. Data model (Supabase / Postgres)

| Table | Key fields | Notes |
|---|---|---|
| `profiles` | `id`, `display_name`, `goal_start`, `platform`, `language`, `created_at` | One per participant |
| `groups` | `id`, `name`, `join_code`, `timezone`, `challenge_start`, `challenge_nights` (default 14) | One row for now |
| `group_members` | `group_id`, `profile_id`, `joined_at` | |
| `usage_events` | `profile_id`, `kind` (open/close), `occurred_at`, `source` | Raw events from both platforms |
| `nights` | `profile_id`, `night_date`, `bucket`, `est_seconds`, `crossed_at`, `computed_at` | Computed by the server from `usage_events` |
| `reactions` | `night_profile_id`, `night_date`, `from_profile_id`, `emoji`, `created_at` | Unique per (night, from_profile) |
| `push_subscriptions` | `profile_id`, `kind` (web push / FCM), `subscription` | |
| `group_summaries` | `group_id`, `night_date`, `sent_at` | Prevents sending a second notification |

### Identity without accounts
- No passwords. You type your **name** and the **group code** once.
- iPhone: the Shortcut sends a personal token (shown during onboarding) with each event. The web app remembers you in the browser.
- Android: the app stores the token.
- Downside: switching phones or clearing the browser means re-entering the token. For the trial, the admin can look it up.

### Joining and leaving
- You can only join **before** the challenge starts.
- Leaving is not a separate feature: if someone stops, their nights stay unreported.

## 9. Privacy and research ethics

- iPhone sends only "an app was opened/closed at time X", without the app's name. Android sends the same.
- Group members see names and buckets; that's the point and is explained in onboarding.
- Participants give explicit consent for research use; an ethics review is needed before the evaluation.
- On request, the admin deletes a participant's data in the Supabase dashboard.

## 10. Evaluation support

- **Optional morning question:** "How rested do you feel?" on a 1–5 scale, one tap in the morning recap.
- **Outcomes available:** successful nights per person, bucket distribution, `crossed_at`, reactions given and received, missing nights.
- Questionnaires on attitude, perceived behavioral control and subjective norms stay outside the app (for example Qualtrics), linked by a participant code.

## 11. Installing on the trial phones

- **iPhone:** nothing to install. Set up the two Shortcuts automations (guide in `ios-shortcuts/`), then open the web app in Safari and choose "Add to Home Screen".
- **Android:** Android Studio on the Mac builds an installable file (APK). Either connect the phone by cable and install from Android Studio, or send the APK and open it on the phone after allowing "install unknown apps". No Play Store account is needed. Push needs a free Firebase project.

## 12. Project layout

```
moonlight/
  CONCEPT.md          this document
  supabase/           database migrations
  ios-shortcuts/      setup guide for the iPhone automations
  android/            Kotlin measuring app
  analysis/           scripts that turn raw events into nights
  web/                the web app (prototype with made-up data so far)
  docs/               test plans and notes
```

## 13. Build order

1. **Measurement test (now):** Shortcuts on iPhone, the measuring app on Android, raw events in Supabase, an analysis script. Run for 2–3 real nights and compare with the phones' own Screen Time / Digital Wellbeing numbers. See `docs/measurement-test.md`.
2. **Backend:** final tables, row level security, participant tokens, server function that computes nights.
3. **Web app:** onboarding, morning recap, group board, history, reactions. English and Dutch. *A clickable prototype with made-up data exists in `web/`; next is connecting it to Supabase.*
4. **Morning notification:** web push and Firebase Cloud Messaging, scheduled server function.
5. **Trial with 4 people** for 2 weeks.

## 14. Backlog

- Custom night-themed reaction icons instead of system emoji.
- Baseline week before the challenge.
- Large-group mode (percentages instead of names).
- Several groups, invite links.
- Native iPhone app with Screen Time, if a paid or university Apple developer account becomes available.
- Evaluation export.
- Exclusion list for apps that shouldn't count.

## 15. Open questions

1. Final app name (Moonlight for now).
2. The rule for sessions without a "closed" event (decided after the test).
