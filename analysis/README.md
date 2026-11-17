# Analysis

`summarize_nights.py` turns the raw `open`/`close` events into one line per participant per night: opens in the window, estimated minutes, Android's precise minutes (if available), when the 2-minute margin was crossed, and the bucket. The estimation rule is described at the top of the script. Python 3.10+, standard library only.

```bash
# from Supabase (needs analysis/.env with SUPABASE_URL and SUPABASE_SECRET_KEY)
python3 analysis/summarize_nights.py --goal Sam=21:00 --goal Jo=22:30

# from CSV exports of the two tables (Table Editor → Export → CSV)
python3 analysis/summarize_nights.py --events test_events.csv --android-nights test_android_nights.csv

# check the estimation logic
python3 analysis/summarize_nights.py --selftest
```

Useful options: `--default-goal 21:00`, `--cap-minutes 10`, `--orphan-seconds 60`, `--use-screen-off` (Android only, more precise but not comparable with iPhone), `--timezone Europe/Amsterdam`.

The `flags` column marks nights with capped sessions (probably locked without a "close"), orphan closes (an "open" was missed), and nights with no data within 12 hours, which usually means the automation or app isn't working.
