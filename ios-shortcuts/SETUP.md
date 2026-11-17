# iPhone setup: Shortcuts automations (measurement test)

The iPhone has no Moonlight app. Instead, the built-in **Shortcuts** app (Dutch: **Opdrachten**) sends a tiny message to our database every time an app is opened or closed. Setup takes about 5 minutes.

Menu names are given in English, with the Dutch label in brackets.

## For the organizer: make the shortcut files

Each participant gets two ready-made shortcuts with their name built in:

```bash
python3 ios-shortcuts/build_shortcuts.py --participant Sam \
    --url https://YOUR-PROJECT.supabase.co --key sb_publishable_...
```

This writes `ios-shortcuts/out/Sam/Moonlight open.shortcut` and `Moonlight close.shortcut`, signed so they can be shared. Send both files to the participant (AirDrop, or by message/email). The `out/` folder is gitignored.

---

## Step 1: Add the two shortcuts

1. Open each file on the iPhone (tap it in AirDrop, Messages or Mail).
2. Shortcuts opens and shows the actions. Tap **Add Shortcut** (**Voeg opdracht toe**).
3. Do this for both: **Moonlight open** and **Moonlight close**.

If you added them on a Mac signed in to the same Apple ID, they appear on the iPhone by themselves through iCloud.

## Step 2: Automation for "app opened"

1. Shortcuts → tab **Automation** (**Automatisering**) → **+**.
2. Choose **App**.
3. Tap **Choose** (**Kies**) and tick **all apps** you use. Apps that aren't ticked won't be measured.
4. Tick only **Is Opened** (**Is geopend**).
5. Select **Run Immediately** (**Voer direct uit**). Turn **Notify When Run** (**Meld bij uitvoeren**) off.
6. Add the shortcut as the action. This depends on the iOS version:
   - **With a Next button** (**Volgende**): tap it, then choose **Moonlight open** under **My Shortcuts** (**Mijn opdrachten**).
   - **Without a Next button** (newer iOS, trigger and actions on one screen): tap the search field at the bottom (**Zoek naar apps en acties**), add **Run Shortcut** (**Voer opdracht uit**), tap the blue word **Shortcut** (**Opdracht**) in it and choose **Moonlight open**. Save with **Done** (**Gereed**) or **✓**.

   The list of apps has to be ticked one by one. Selecting only the apps you actually use (Settings → Screen Time → See All Activity → Week → Most Used) is enough.

## Step 3: Automation for "app closed"

Repeat step 2, but tick only **Is Closed** (**Is gesloten**) and choose **Moonlight close**.

---

## Step 4: Check that it works

1. Open any app (for example Weather) and close it again.
2. Tell the organizer. They check that two new rows (`open` and `close`) with your name appear in the database.

If nothing arrives, open the shortcut **Moonlight open** and run it by hand. An error mentioning 401 or 404 points to a wrong URL or key; ask the organizer for new files.

---

## During the test

- Keep the automations on and keep using your phone as usual.
- **Each morning**, write down your Screen Time for last night (see `docs/measurement-test.md`). This is how we check whether the automations measure correctly.
- If the phone is in Airplane mode, events are lost. That's fine for the test, but tell the organizer.

## Afterwards

To stop: Shortcuts → Automation → swipe left on both Moonlight automations → Delete. Then delete the shortcuts **Moonlight open** and **Moonlight close**.
