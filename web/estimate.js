// Turns raw open/close events into estimated use per night. Same rule as
// analysis/summarize_nights.py (keep the two in sync):
//  * every "open" raises an in-use counter, every "close" lowers it (never below 0);
//    time with the counter above 0 counts as use;
//  * no event for longer than CAP while in use → count only CAP, then reset (phone locked);
//  * a "close" with nothing open counts ORPHAN of use;
//  * "screen_off" (Android) is ignored, to stay comparable with iPhone.

import { bucketFor, toMinutes, WINDOW_END } from "./data.js";

export const CAP_MS = 10 * 60 * 1000;
export const ORPHAN_MS = 60 * 1000;
const MARGIN_MS = 2 * 60 * 1000;

/** events: [{kind, at: Date}] sorted by time → [[startMs, endMs], ...] */
export function useIntervals(events) {
  const out = [];
  let depth = 0;
  let since = null;
  let prev = null;
  const stop = (t) => {
    if (since !== null && t > since) out.push([since, t]);
    since = null;
  };
  for (const e of events) {
    const t = e.at.getTime();
    if (depth > 0 && since !== null && prev !== null && t - prev > CAP_MS) {
      stop(prev + CAP_MS);
      depth = 0;
    }
    if (e.kind === "open") {
      if (depth === 0) since = t;
      depth++;
    } else if (e.kind === "close") {
      if (depth === 0) out.push([t - ORPHAN_MS, t]);
      else if (--depth === 0) stop(t);
    }
    prev = t;
  }
  if (depth > 0 && since !== null && prev !== null) stop(prev + CAP_MS);
  return out;
}

/** Window of the night that starts on `date` (local time), for a goal like "21:00". */
export function windowFor(date, goal) {
  const [gh, gm] = goal.split(":").map(Number);
  const startDay = toMinutes(goal) < 12 * 60 ? 1 : 0; // goals before noon fall on the next morning
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() + startDay, gh, gm);
  const [eh, em] = WINDOW_END.split(":").map(Number);
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1, eh, em);
  return [start.getTime(), end.getTime()];
}

/** Summarizes one night: {bucket, min, sessions: [{offset, min}], crossedAt: Date|null}. */
export function summarizeNight(intervals, date, goal) {
  const [ws, we] = windowFor(date, goal);
  let total = 0;
  let crossedAt = null;
  const sessions = [];
  for (const [a, b] of [...intervals].sort((x, y) => x[0] - y[0])) {
    const a2 = Math.max(a, ws);
    const b2 = Math.min(b, we);
    if (b2 <= a2) continue;
    if (crossedAt === null && total + (b2 - a2) >= MARGIN_MS) crossedAt = new Date(a2 + (MARGIN_MS - total));
    total += b2 - a2;
    sessions.push({ offset: (a2 - ws) / 60000, min: Math.round(((b2 - a2) / 60000) * 10) / 10 });
  }
  const min = Math.round((total / 60000) * 10) / 10;
  return { bucket: bucketFor(min), min, sessions, crossedAt };
}
