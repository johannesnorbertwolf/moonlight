# Measurement test

**Goal:** before building the real app, find out whether the two measuring methods work well enough. Run for **2–3 real nights**, ideally with at least one iPhone and one Android phone.

## Questions this test answers

1. **iPhone:** do the Shortcuts automations fire reliably and silently, also at night? Do any requests get lost?
2. **iPhone:** when the phone is locked while an app is open, is a "closed" event sent? (If not, the 10-minute cap rule decides how much is counted.)
3. **Both:** how close is the open/close estimate to the phone's own Screen Time / Digital Wellbeing number for the night?
4. **Android:** does the 07:05 upload arrive, and how late on phones with aggressive battery saving?
5. **Android:** how far is the open/close estimate from the phone's own precise measurement (`precise_min`)?

## Setup (organizer)

### 1. Supabase project (once)
1. Create a free account and project at supabase.com. Region: a European one (for example Frankfurt). Note the database password somewhere safe.
2. **SQL Editor → New query**, paste `supabase/migrations/0001_measurement_test.sql`, **Run**.
3. **Project Settings → API** (or **API Keys**): note
   - the **Project URL**,
   - the **public key** (`anon` / publishable): goes into the iPhone shortcut and Android app,
   - the **secret key** (`service_role` / secret): only for the analysis script, never on a phone or in git.

### 2. Phones
- **iPhone:** send the participant `ios-shortcuts/SETUP.md` plus their name, the project URL and the public key.
- **Android:** build the app (`android/README.md`) and install it; enter name and goal time; allow usage access; exempt from battery optimization.
- Check in the Supabase **Table Editor** (`test_events`) that rows arrive from every phone.

### 3. Analysis
Create `analysis/.env` (gitignored):
```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_SECRET_KEY=the-secret-key
```
Each morning run:
```bash
python3 analysis/summarize_nights.py --goal Sam=21:00 --goal Jo=22:30
```

## Each morning (participants)

Write down last night's numbers from the phone's own screen-time feature, for the hours of your window:
- **iPhone:** Settings → Screen Time → See All App & Website Activity → **Day** → tap yesterday and today, look at the bars for the hours in your window. Note roughly the minutes and the times of use.
- **Android:** Settings → Digital Wellbeing (Samsung: Digital Wellbeing and parental controls) → dashboard. Hourly detail varies by phone; note what you can.

Also note anything special: phone off, Airplane mode, alarm only, a late call.

## Results log

| Night | Participant | Platform | Own screen-time minutes in window | Script `est_min` | Android `precise_min` | Bucket | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
| | | | | | | | |
| | | | | | | | |

## Decide after the test

- Is the Shortcuts route good enough for iPhone, or do iPhone users fall back to a morning self-report?
- The cap rule for sessions without a "closed" event (currently 10 minutes).
- Whether Android should use its precise measurement after all (fairer data, but not the same method as iPhone).
