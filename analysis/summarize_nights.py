#!/usr/bin/env python3
"""Turn raw open/close events from the measurement test into one line per participant per night.

Data source (pick one):
  * Supabase API: set SUPABASE_URL and SUPABASE_SECRET_KEY (the service_role / secret key, never
    the public one) in the environment or in analysis/.env.
  * CSV export: --events test_events.csv [--android-nights test_android_nights.csv], exported from
    the Supabase Table Editor.

Examples:
  python3 analysis/summarize_nights.py --goal Sam=21:00 --goal Jo=22:30
  python3 analysis/summarize_nights.py --events test_events.csv --default-goal 21:00
  python3 analysis/summarize_nights.py --selftest

Estimation rule (the same for iPhone and Android, CONCEPT.md §3):
  * Every "open" raises an in-use counter, every "close" lowers it (never below 0). Time with the
    counter above 0 counts as use. A counter is needed because on iPhone, switching apps can log
    "open B" before "close A".
  * If no event arrives for longer than --cap-minutes while in use, only the cap is counted and the
    counter resets (the phone was probably locked without a "close").
  * A "close" with nothing open counts --orphan-seconds of use (the "open" was missed).
  * "screen_off" events (Android only) are ignored unless --use-screen-off, to stay comparable with
    iPhone, which has no such event.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import urllib.request
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

WINDOW_END = time(7, 0)
MARGIN_SECONDS = 120
BUCKETS = [  # (upper bound in seconds, name)
    (MARGIN_SECONDS, "free"),
    (5 * 60, "light"),
    (15 * 60, "medium"),
    (60 * 60, "heavy"),
    (float("inf"), "very_heavy"),
]


@dataclass
class Event:
    participant: str
    platform: str
    kind: str
    at: datetime


@dataclass
class NightSummary:
    participant: str
    platform: str
    night: date
    window_start: datetime
    window_end: datetime
    opens: int = 0
    est_seconds: float = 0.0
    crossed_at: datetime | None = None
    capped_gaps: int = 0
    orphan_closes: int = 0
    no_data_nearby: bool = False
    precise_seconds: int | None = None
    notes: list[str] = field(default_factory=list)

    @property
    def bucket(self) -> str:
        for bound, name in BUCKETS:
            if self.est_seconds < bound:
                return name
        return BUCKETS[-1][1]


# ----------------------------------------------------------------------------- windows


def night_window(night: date, goal: time, tz: ZoneInfo) -> tuple[datetime, datetime]:
    """Night belongs to the date it starts on; goals before noon fall on the next morning."""
    start_date = night + timedelta(days=1) if goal < time(12, 0) else night
    start = datetime.combine(start_date, goal, tz)
    end = datetime.combine(night + timedelta(days=1), WINDOW_END, tz)
    return start, end


# ----------------------------------------------------------------------------- estimation


def use_intervals(
    events: list[Event], cap: timedelta, orphan: timedelta, use_screen_off: bool
) -> tuple[list[tuple[datetime, datetime]], int, int]:
    """Convert one participant's sorted events into intervals of estimated use."""
    intervals: list[tuple[datetime, datetime]] = []
    depth = 0
    in_use_since: datetime | None = None
    capped = 0
    orphans = 0

    def stop(at: datetime) -> None:
        nonlocal in_use_since
        if in_use_since is not None and at > in_use_since:
            intervals.append((in_use_since, at))
        in_use_since = None

    prev: datetime | None = None
    for e in events:
        # Long silence while in use: count only the cap, then assume the phone was put away.
        if depth > 0 and in_use_since is not None and prev is not None and e.at - prev > cap:
            stop(prev + cap)
            depth = 0
            capped += 1

        if e.kind == "open":
            if depth == 0:
                in_use_since = e.at
            depth += 1
        elif e.kind == "close":
            if depth == 0:
                orphans += 1
                intervals.append((e.at - orphan, e.at))
            else:
                depth -= 1
                if depth == 0:
                    stop(e.at)
        elif e.kind == "screen_off" and use_screen_off:
            depth = 0
            stop(e.at)
        prev = e.at

    if depth > 0 and in_use_since is not None and prev is not None:
        stop(prev + cap)
        capped += 1
    return intervals, capped, orphans


def summarize_night(
    s: NightSummary, intervals: list[tuple[datetime, datetime]], events: list[Event]
) -> None:
    total = 0.0
    for a, b in sorted(intervals):
        a2, b2 = max(a, s.window_start), min(b, s.window_end)
        if b2 <= a2:
            continue
        before = total
        total += (b2 - a2).total_seconds()
        if s.crossed_at is None and total >= MARGIN_SECONDS:
            s.crossed_at = a2 + timedelta(seconds=MARGIN_SECONDS - before)
    s.est_seconds = total
    s.opens = sum(1 for e in events if e.kind == "open" and s.window_start <= e.at < s.window_end)
    margin = timedelta(hours=12)
    s.no_data_nearby = not any(
        s.window_start - margin <= e.at <= s.window_end + margin for e in events
    )


def summarize(
    events: list[Event],
    goals: dict[str, time],
    default_goal: time,
    tz: ZoneInfo,
    cap: timedelta,
    orphan: timedelta,
    use_screen_off: bool,
    now: datetime,
    android_precise: dict[tuple[str, date], int],
) -> list[NightSummary]:
    by_person: dict[str, list[Event]] = {}
    for e in events:
        by_person.setdefault(e.participant, []).append(e)

    out: list[NightSummary] = []
    for person, evs in sorted(by_person.items()):
        evs.sort(key=lambda e: (e.at, {"open": 0, "close": 1, "screen_off": 2}.get(e.kind, 3)))
        platform = evs[0].platform
        goal = goals.get(person, default_goal)
        intervals, _, _ = use_intervals(evs, cap, orphan, use_screen_off)

        first = evs[0].at.astimezone(tz).date() - timedelta(days=1)
        last = evs[-1].at.astimezone(tz).date()
        night = first
        while night <= last:
            ws, we = night_window(night, goal, tz)
            if we <= now:
                s = NightSummary(person, platform, night, ws, we)
                # Per-night counts of caps and orphans, from events near this window.
                near = [e for e in evs if ws - timedelta(hours=3) <= e.at <= we]
                _, s.capped_gaps, s.orphan_closes = use_intervals(near, cap, orphan, use_screen_off)
                summarize_night(s, intervals, evs)
                s.precise_seconds = android_precise.get((person, night))
                out.append(s)
            night += timedelta(days=1)
    return out


# ----------------------------------------------------------------------------- loading


def parse_ts(value: str) -> datetime:
    v = value.strip().replace("Z", "+00:00")
    dt = datetime.fromisoformat(v)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"'))


def fetch_table(url: str, key: str, table: str, order: str) -> list[dict]:
    rows: list[dict] = []
    page = 1000
    offset = 0
    while True:
        req = urllib.request.Request(
            f"{url.rstrip('/')}/rest/v1/{table}?select=*&order={order}&limit={page}&offset={offset}",
            headers={"apikey": key, "Authorization": f"Bearer {key}"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            batch = json.load(resp)
        rows.extend(batch)
        if len(batch) < page:
            return rows
        offset += page


def rows_to_events(rows: list[dict]) -> list[Event]:
    return [
        Event(r["participant"], r["platform"], r["kind"], parse_ts(r["occurred_at"]))
        for r in rows
    ]


def rows_to_precise(rows: list[dict]) -> dict[tuple[str, date], int]:
    return {
        (r["participant"], date.fromisoformat(str(r["night_date"])[:10])): int(r["precise_seconds"])
        for r in rows
    }


def read_csv(path: str) -> list[dict]:
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


# ----------------------------------------------------------------------------- output


def fmt_minutes(seconds: float | None) -> str:
    return "-" if seconds is None else f"{seconds / 60:.1f}"


def print_table(rows: list[NightSummary], tz: ZoneInfo) -> None:
    header = ["participant", "platform", "night", "window", "opens", "est_min", "precise_min",
              "crossed_at", "bucket", "flags"]
    lines = [header]
    for s in rows:
        flags = []
        if s.capped_gaps:
            flags.append(f"{s.capped_gaps} capped")
        if s.orphan_closes:
            flags.append(f"{s.orphan_closes} orphan close")
        if s.no_data_nearby:
            flags.append("NO DATA ±12h: automation/app working?")
        lines.append([
            s.participant,
            s.platform,
            s.night.isoformat(),
            f"{s.window_start.astimezone(tz):%H:%M}-{s.window_end.astimezone(tz):%H:%M}",
            str(s.opens),
            fmt_minutes(s.est_seconds),
            fmt_minutes(s.precise_seconds),
            s.crossed_at.astimezone(tz).strftime("%H:%M") if s.crossed_at else "-",
            s.bucket,
            ", ".join(flags),
        ])
    widths = [max(len(r[i]) for r in lines) for i in range(len(header))]
    for i, r in enumerate(lines):
        print("  ".join(c.ljust(w) for c, w in zip(r, widths)).rstrip())
        if i == 0:
            print("  ".join("-" * w for w in widths))


# ----------------------------------------------------------------------------- self-test


def selftest() -> None:
    tz = ZoneInfo("Europe/Amsterdam")
    cap, orphan = timedelta(minutes=10), timedelta(seconds=60)

    def ev(kind: str, hh: int, mm: int, day: int = 17, ss: int = 0) -> Event:
        return Event("T", "ios", kind, datetime(2026, 11, day, hh, mm, ss, tzinfo=tz))

    def run(evs: list[Event], goal: time = time(21, 0)) -> NightSummary:
        rows = summarize(evs, {}, goal, tz, cap, orphan, False, datetime(2026, 11, 20, tzinfo=tz), {})
        return next(r for r in rows if r.night == date(2026, 11, 17))

    # 1. Nothing in the window: free.
    s = run([ev("open", 20, 0), ev("close", 20, 30), ev("open", 7, 30, day=18), ev("close", 7, 40, day=18)])
    assert s.bucket == "free" and s.est_seconds == 0, s

    # 2. Scrolling from 20:55 to 21:04 (opened before the window): 4 min counted, light.
    s = run([ev("open", 20, 55), ev("close", 21, 4)])
    assert abs(s.est_seconds - 240) < 1 and s.bucket == "light", s
    assert s.crossed_at == datetime(2026, 11, 17, 21, 2, tzinfo=tz), s.crossed_at

    # 3. App switch logged as open B before close A: still one continuous 3-min stretch.
    s = run([ev("open", 23, 0), ev("open", 23, 1), ev("close", 23, 1, ss=1), ev("close", 23, 3)])
    assert abs(s.est_seconds - 180) < 1 and s.opens == 2, s

    # 4. Locked without close, next event in the morning: only the 10-min cap counts.
    s = run([ev("open", 23, 0), ev("close", 7, 30, day=18)])
    assert abs(s.est_seconds - 600) < 1 and s.capped_gaps == 1, s

    # 5. Orphan close at 01:00: counts 1 min, still within the margin.
    s = run([ev("close", 1, 0, day=18)])
    assert abs(s.est_seconds - 60) < 1 and s.bucket == "free" and s.orphan_closes == 1, s

    # 6. Goal after midnight: window 00:30-07:00, night date stays the evening.
    s = run([ev("open", 23, 0), ev("close", 23, 30)], goal=time(0, 30))
    assert s.est_seconds == 0 and s.window_start.hour == 0, s

    print("selftest ok")


# ----------------------------------------------------------------------------- main


def parse_goal(value: str) -> tuple[str, time]:
    name, _, hhmm = value.partition("=")
    if not name or not hhmm:
        raise argparse.ArgumentTypeError("use NAME=HH:MM")
    return name, time.fromisoformat(hhmm)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--events", help="CSV export of test_events (instead of the API)")
    p.add_argument("--android-nights", help="CSV export of test_android_nights")
    p.add_argument("--goal", action="append", type=parse_goal, default=[], metavar="NAME=HH:MM")
    p.add_argument("--default-goal", type=time.fromisoformat, default=time(21, 0))
    p.add_argument("--timezone", default="Europe/Amsterdam")
    p.add_argument("--cap-minutes", type=float, default=10)
    p.add_argument("--orphan-seconds", type=float, default=60)
    p.add_argument("--use-screen-off", action="store_true")
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()

    if a.selftest:
        selftest()
        return

    tz = ZoneInfo(a.timezone)
    if a.events:
        event_rows = read_csv(a.events)
        precise_rows = read_csv(a.android_nights) if a.android_nights else []
    else:
        load_env_file(Path(__file__).with_name(".env"))
        url, key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SECRET_KEY")
        if not url or not key:
            sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY (or use --events CSV). See analysis/README.md.")
        event_rows = fetch_table(url, key, "test_events", "occurred_at.asc")
        precise_rows = fetch_table(url, key, "test_android_nights", "night_date.asc")

    events = rows_to_events(event_rows)
    if not events:
        sys.exit("No events yet.")
    rows = summarize(
        events,
        dict(a.goal),
        a.default_goal,
        tz,
        timedelta(minutes=a.cap_minutes),
        timedelta(seconds=a.orphan_seconds),
        a.use_screen_off,
        datetime.now(tz),
        rows_to_precise(precise_rows),
    )
    print_table(rows, tz)


if __name__ == "__main__":
    main()
