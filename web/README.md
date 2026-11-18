# Moonlight web app

The screens from `CONCEPT.md` §7. Two modes:
- **Live:** join with just a name: while there is one group, no code is needed (`supabase/migrations/0003_join_without_code.sql`). The app signs in anonymously, loads the group through the functions in `supabase/migrations/0002_groups_and_reactions.sql`, computes each night from the raw events (`estimate.js`, same rule as `analysis/summarize_nights.py`) and stores reactions in the database. Requires "Allow anonymous sign-ins" in Supabase.
- **Demo:** "Try the demo instead" on the welcome screen; a made-up group, nothing sent anywhere.

Published to GitHub Pages by `.github/workflows/pages.yml` on every push to `main` that changes `web/`.

Plain HTML, CSS and JavaScript modules: no build step, no dependencies.

## Run

```bash
python3 -m http.server 8742 --directory web --bind 0.0.0.0
```

Then open http://localhost:8742 on the Mac, or `http://<your Mac's IP>:8742` on a phone in the same Wi-Fi (find the IP with `ipconfig getifaddr en0`). On iPhone, Share → Add to Home Screen makes it open like an app.

## Files

| File | What it does |
|---|---|
| `index.html` | Page shell, tab bar, links the manifest and icon |
| `app.js` | Router (`#/today`, `#/recap`, `#/group`, `#/history`, `#/settings`) and all screens, including onboarding and the reaction tray (tap = 🌙, hold = all nine) |
| `data.js` | Rules from the concept (buckets, night dates, windows, streaks), local storage, and the made-up demo group |
| `estimate.js` | Turns open/close events into estimated minutes per night |
| `remote.js` | Supabase: anonymous sign-in, join, load group, reactions, goal changes |
| `config.js` | Supabase URL and public (publishable) key |
| `moon.js` | Moon icons per bucket, as inline SVG |
| `i18n.js` | English and Dutch strings |
| `styles.css` | Night theme, mobile-first |
| `manifest.webmanifest`, `icon.svg` | Home-screen app name and icon |

## Known limits

- Nights are computed in the browser's time zone, and with the member's *current* goal time for all past nights.
- Anyone with the link who types an existing member's name takes over that member (meant for switching phones; fine for a trial among friends).
- The browser remembers the name: if its sign-in is lost, it joins again silently. On iPhone, the home-screen app and Safari have separate storage, so you join once in each.
- iPhone nights without any events count as phone-free; a silent night can't be told apart from broken automations yet.
- Settings → "Demo: allow reactions during the night" bypasses the rule that reactions are only possible outside night windows.

## Next steps

Morning notification (web push), and moving the night computation to the server so the notification can use it.
