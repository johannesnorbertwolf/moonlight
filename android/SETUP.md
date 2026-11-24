# Android setup (participants)

Two parts: a small **measuring app** that notices phone use at night, and the **Moonlight website** for the group board. About 5 minutes. Requires Android 10 or newer.

You need from the organizer:
- the file **Moonlight test.apk** (sent by message, email or a cloud link),
- the group's **invite link** (or its 6-character code).

Do everything on the phone itself: the website links the measuring app to you.

## Part 1: install the measuring app

1. **Install:** open the APK file on your phone. Android warns that the app is from an unknown source:
   - allow installing apps from the app you opened the file in (WhatsApp, Gmail, Files…),
   - if Google Play Protect asks, tap **More details → Install anyway**.
2. Open **Moonlight test**.
3. Tap **Open usage access settings**, find **Moonlight test**, and turn it on.
   - If the switch is greyed out with "Restricted setting": go to **Settings → Apps → Moonlight test → ⋮ (top right) → Allow restricted settings**, then try again.
4. Tap **Open battery optimization settings** and set Moonlight test to **Not optimized** / **Unrestricted**.
   - Samsung: also check **Settings → Battery → Background usage limits**, and make sure Moonlight test isn't in "Sleeping apps".

## Part 2: join your group on the website

1. Tap the **invite link** (it opens in Chrome), or open **https://johannesnorbertwolf.github.io/moonlight/** and type the code.
2. Tap **Get started → Join this group**, enter your **name** and **goal time** (e.g. 21:00), phone: **Android**.
3. On the next screen tap **Connect the measuring app**. Moonlight test opens and says "Connected as …".
4. In Moonlight test, tap **Measure last night now and upload**. The status line should say "Uploaded …". An error here means something's wrong; send a screenshot to the organizer.
5. Back in Chrome: menu **⋮ → Add to Home screen** (or **Install app**). Moonlight now opens like an app.

From now on the measuring app works by itself: every morning around 07:05 it uploads last night. You don't need to open it.

## Good to know

- If you change your goal time on the website, tap **Settings → Connect the measuring app** again so the measuring app gets the new time.
- A night without an upload shows as "Not reported" (grey moon). Opening the measuring app and tapping "Measure last night now" fixes it.
- To stop: uninstall Moonlight test and remove the website from your home screen.
