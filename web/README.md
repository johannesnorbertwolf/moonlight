# Moonlight web app (prototype)

The screens from `CONCEPT.md` §7 as a clickable prototype with **made-up group data**. Nothing is sent anywhere; your name, settings and reactions stay in the browser (localStorage). The demo group code is `MOON`.

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
| `data.js` | Rules from the concept (buckets, night dates, windows, streaks), local storage, and the made-up group |
| `moon.js` | Moon icons per bucket, as inline SVG |
| `i18n.js` | English and Dutch strings |
| `styles.css` | Night theme, mobile-first |
| `manifest.webmanifest`, `icon.svg` | Home-screen app name and icon |

## What's fake

- The group (you plus Sam, Jo and Alex) and all nights, generated from a fixed seed so they stay the same across reloads.
- Other members' reactions.
- Settings → "Demo: allow reactions during the night" bypasses the rule that reactions are only possible outside night windows.

## Next steps

Connect to Supabase (participant tokens, real nights from `usage_events`, reactions table), web push for the morning notification, and hosting over HTTPS so it can be added to iPhone home screens.
