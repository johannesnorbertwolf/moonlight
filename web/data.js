// Prototype data layer: rules from CONCEPT.md §3, a made-up group, and local storage.
// The real app replaces the fake group with Supabase queries; the rules stay the same.

export const WINDOW_END = "07:00";
export const CHALLENGE_NIGHTS = 14;
export const DEMO_GROUP_CODE = "MOON";
export const REACTIONS = ["🌙", "👏", "🔥", "😴", "❤️", "🛌", "🦉", "🦥", "🥱"];

// Upper bounds in minutes, CONCEPT.md §3.
export const BUCKETS = ["free", "light", "medium", "heavy", "very_heavy"];
export function bucketFor(min) {
  if (min < 2) return "free";
  if (min < 5) return "light";
  if (min < 15) return "medium";
  if (min < 60) return "heavy";
  return "very_heavy";
}

// ---------------------------------------------------------------- dates

export const pad = (n) => String(n).padStart(2, "0");
export const isoDate = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}
export function toMinutes(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

/** Date of the most recent completed night (a night is dated by the evening it starts). */
export function lastNightDate(now = new Date()) {
  const afterEnd = now.getHours() * 60 + now.getMinutes() >= toMinutes(WINDOW_END);
  return addDays(new Date(now.getFullYear(), now.getMonth(), now.getDate()), afterEnd ? -1 : -2);
}

/** True while the given goal start → 07:00 window is running. */
export function inNightWindow(goal, now = new Date()) {
  const m = now.getHours() * 60 + now.getMinutes();
  const start = toMinutes(goal);
  const end = toMinutes(WINDOW_END);
  return start > end ? m >= start || m < end : m >= start && m < end;
}

/** Minutes until the next window start (0 if in the window). */
export function minutesUntilWindow(goal, now = new Date()) {
  if (inNightWindow(goal, now)) return 0;
  const m = now.getHours() * 60 + now.getMinutes();
  let d = toMinutes(goal) - m;
  if (d < 0) d += 24 * 60;
  return d;
}

/** Length of the window in minutes. */
export function windowLength(goal) {
  let d = toMinutes(WINDOW_END) - toMinutes(goal);
  if (d <= 0) d += 24 * 60;
  return d;
}

// ---------------------------------------------------------------- storage

const KEY = "moonlight.proto.v1";

export function loadState() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) || {};
  } catch {
    return {};
  }
}

export function saveState(state) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* private mode etc.: the prototype still works for this visit */
  }
}

// ---------------------------------------------------------------- fake group

// Small deterministic random generator, so the made-up data is stable across reloads.
function rng(seed) {
  let s = 0;
  for (const c of seed) s = (s * 31 + c.charCodeAt(0)) >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

function fakeNight(rand, goal, skill) {
  const r = rand();
  if (r < 0.04) return { bucket: "missing", min: null, sessions: [] };
  let min;
  if (r < skill) min = rand() < 0.5 ? 0 : Math.round(rand() * 15) / 10; // 0 or a tiny check
  else min = Math.round(2 + rand() ** 2 * 70);
  // Spread the minutes over 1–3 sessions inside the window.
  const len = windowLength(goal);
  const sessions = [];
  if (min > 0) {
    const n = min < 3 ? 1 : 1 + Math.floor(rand() * 3);
    for (let i = 0; i < n; i++) {
      const start = Math.floor(rand() * (len - 30));
      sessions.push({ offset: start, min: Math.max(0.5, Math.round((min / n) * 10) / 10) });
    }
    sessions.sort((a, b) => a.offset - b.offset);
  }
  return { bucket: bucketFor(min), min, sessions };
}

/** Builds the group: "you" plus three made-up members, each with nights from challenge start. */
export function buildGroup(profile, now = new Date()) {
  const last = lastNightDate(now);
  // The demo challenge started 8 nights before last night, so we're at night 9 of 14.
  const start = addDays(last, -8);
  const members = [
    { id: "me", name: profile.name, goal: profile.goal, me: true, skill: 0.7 },
    { id: "sam", name: "Sam", goal: "22:00", skill: 0.8 },
    { id: "jo", name: "Jo", goal: "21:30", skill: 0.7 },
    { id: "alex", name: "Alex", goal: "21:00", skill: 0.55 },
  ];
  for (const m of members) {
    const rand = rng(m.id + isoDate(start));
    m.nights = {};
    for (let d = new Date(start); d <= last; d = addDays(d, 1)) {
      m.nights[isoDate(d)] = { date: isoDate(d), ...fakeNight(rand, m.goal, m.skill) };
    }
  }
  return { live: false, name: "Moonlight demo", start, last, nightsTotal: CHALLENGE_NIGHTS, members };
}

/** Consecutive phone-free nights up to `last`; "missing" pauses without breaking. */
export function personalStreak(member, last) {
  let n = 0;
  for (let d = new Date(last); member.nights[isoDate(d)]; d = addDays(d, -1)) {
    const b = member.nights[isoDate(d)].bucket;
    if (b === "missing") continue;
    if (b !== "free") break;
    n++;
  }
  return n;
}

/** Consecutive nights on which every member who reported was phone-free. */
export function groupStreak(group) {
  let n = 0;
  for (let d = new Date(group.last); d >= group.start; d = addDays(d, -1)) {
    const reported = group.members.map((m) => m.nights[isoDate(d)]).filter((x) => x && x.bucket !== "missing");
    if (!reported.length) continue;
    if (!reported.every((x) => x.bucket === "free")) break;
    n++;
  }
  return n;
}

/** Longest run of phone-free nights in the challenge so far. */
export function bestStreak(member) {
  let best = 0;
  let run = 0;
  for (const key of Object.keys(member.nights).sort()) {
    const b = member.nights[key].bucket;
    if (b === "missing") continue;
    run = b === "free" ? run + 1 : 0;
    best = Math.max(best, run);
  }
  return best;
}
