# iPhone setup: Shortcuts automations (measurement test)

The iPhone has no Moonlight app. Instead, the built-in **Shortcuts** app sends a tiny message to our database every time an app is opened or closed. Setup takes about 10 minutes.

You need from the organizer:
- **Your participant name** exactly as agreed, for example `Sam`.
- **The project URL**, like `https://abcdefgh.supabase.co`.
- **The public key** (a long text starting with `eyJ…` or `sb_publishable_…`).

The easiest way: the organizer sends these in a message, and you copy-paste them.

---

## Step 1: Create the shortcut "Moonlight log"

1. Open **Shortcuts** → tab **Shortcuts** → **+** (top right).
2. Tap the name at the top and rename it to **Moonlight log**.
3. Add these actions in this order (search for them in the action list):

   **a) Current Date**

   **b) Format Date**
   - Date: *Current Date*
   - Date Format: **ISO 8601**
   - Include ISO 8601 Time: **on**

   **c) Get Contents of URL**
   - URL: `<project URL>/rest/v1/test_events`
     (for example `https://abcdefgh.supabase.co/rest/v1/test_events`)
   - Tap **Show More**:
   - Method: **POST**
   - Headers (tap **Add new header** four times):

     | Key | Value |
     |---|---|
     | `apikey` | the public key |
     | `Authorization` | `Bearer ` followed by the public key (one space after Bearer) |
     | `Content-Type` | `application/json` |
     | `Prefer` | `return=minimal` |

   - Request Body: **JSON**, with five fields (tap **Add new field** → **Text** each time):

     | Key | Value |
     |---|---|
     | `participant` | your participant name, e.g. `Sam` |
     | `platform` | `ios` |
     | `kind` | select the variable **Shortcut Input** |
     | `occurred_at` | select the variable **Formatted Date** |
     | `source` | `shortcut` |

4. Tap **Done**.

---

## Step 2: Automation for "app opened"

1. Shortcuts → tab **Automation** → **+** (or **New Automation**).
2. Choose **App**.
3. Tap **Choose** and select **all apps** in the list (scroll through and tick every app you use). This is the tedious part, but apps that aren't ticked won't be measured.
4. Tick **Is Opened** only (untick **Is Closed**).
5. Select **Run Immediately**. Turn **Notify When Run** off.
6. Tap **Next** → **New Blank Automation**.
7. Add the action **Text** and type `open`.
8. Add the action **Run Shortcut** → choose **Moonlight log**. Tap the arrow on that action and make sure the input is the **Text** from step 7.
9. Tap **Done**.

## Step 3: Automation for "app closed"

Repeat step 2, but:
- tick **Is Closed** only (untick **Is Opened**),
- type `close` in the Text action.

---

## Step 4: Check that it works

1. Open any app (for example Weather) and close it again.
2. Tell the organizer. They check that two new rows (`open` and `close`) with your name appear in the database.

If nothing arrives:
- Open the shortcut **Moonlight log**, run it once by hand, and see if Shortcuts shows an error.
- Check the URL ends with `/rest/v1/test_events` and that `Bearer ` has a space after it.

---

## During the test

- Keep the automations on and keep using your phone as usual.
- **Each morning**, write down your Screen Time for last night (see `docs/measurement-test.md`). This is how we check whether the automations measure correctly.
- If the phone is in Airplane mode, events are lost. That's fine for the test, but tell the organizer.

## Afterwards

To stop: Shortcuts → Automation → swipe left on both Moonlight automations → Delete. Then delete the shortcut **Moonlight log**.
