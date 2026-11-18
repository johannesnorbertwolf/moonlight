# Android setup (participants)

Two parts: a small **measuring app** that notices phone use at night, and the **Moonlight website** for the group board. About 5 minutes. Requires Android 10 or newer.

You need from the organizer:
- the file **Moonlight test.apk** (sent by message, email or a cloud link),
- **your participant name**, exactly as agreed (for example `Sam`).

## Part 1: the measuring app

1. **Install:** open the APK file on your phone. Android warns that the app is from an unknown source:
   - allow installing apps from the app you opened the file in (WhatsApp, Gmail, Files…),
   - if Google Play Protect asks, tap **More details → Install anyway**.
2. Open **Moonlight test**. Enter your **participant name** and your **goal time** (e.g. 21:00), then tap **Save**.
3. Tap **Open usage access settings**, find **Moonlight test**, and turn it on.
   - If the switch is greyed out with "Restricted setting": go to **Settings → Apps → Moonlight test → ⋮ (top right) → Allow restricted settings**, then try again.
4. Tap **Open battery optimization settings** and set Moonlight test to **Not optimized** / **Unrestricted**.
   - Samsung: also check **Settings → Battery → Background usage limits**, and make sure Moonlight test isn't in "Sleeping apps".
5. Back in the app, tap **Measure last night now and upload**. The status line should say "Uploaded …". An error here means something's wrong; send a screenshot to the organizer.

From now on the app works by itself: every morning around 07:05 it uploads last night. You don't need to open it.

## Part 2: the website

1. Open **https://johannesnorbertwolf.github.io/moonlight/** in Chrome.
2. Tap **Get started** and enter:
   - the **same name** as in the measuring app (otherwise your nights can't be found),
   - the same goal time,
   - phone: **Android**.
3. Chrome menu **⋮ → Add to Home screen** (or **Install app**). Moonlight now opens like an app.

## Good to know

- If your goal time changes, change it in **both** the measuring app and the website.
- A night without an upload shows as "Not reported" (grey moon). Opening the measuring app and tapping "Measure last night now" fixes it.
- To stop: uninstall Moonlight test and remove the website from your home screen.
