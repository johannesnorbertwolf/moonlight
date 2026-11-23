# Moonlight

An app for a sleep intervention: it checks whether you used your phone during your night window (your goal time → 07:00), and every morning compares how everyone in your group did. Working name.

**Status:** in trial. Read `CONCEPT.md` first.

| Folder | Contents |
|---|---|
| `CONCEPT.md` | The full concept: rules, architecture, screens, data model, build order |
| `docs/measurement-test.md` | Plan for the 2–3 night measurement test and results log |
| `supabase/` | Database migrations |
| `ios/` | Native iPhone app (SwiftUI, Screen Time API) |
| `ios-shortcuts/` | Older iPhone route: Shortcuts automations, no app needed |
| `android/` | Kotlin measuring app for Android |
| `analysis/` | Script that turns raw events into nights |
| `web/` | Web app for the group board (live on GitHub Pages) |
