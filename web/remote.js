// Live data from Supabase: anonymous sign-in, joining the group, loading the board, reactions.
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";
import { SUPABASE_URL, SUPABASE_KEY } from "./config.js";
import { isoDate, addDays, lastNightDate } from "./data.js";
import { useIntervals, summarizeNight } from "./estimate.js";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: "moonlight.auth" },
});

async function ensureSession() {
  const { data } = await supabase.auth.getSession();
  if (data.session) return data.session;
  const { data: signed, error } = await supabase.auth.signInAnonymously();
  if (error) throw error;
  return signed.session;
}

export class UnknownCodeError extends Error {}

// While there is only one group, joining needs no code (migration 0003).
export async function join(name, goal, platform) {
  await ensureSession();
  const { error } = await supabase.rpc("join_group", {
    p_code: null, p_name: name, p_goal: goal, p_platform: platform,
  });
  if (error) {
    if (/unknown group code/.test(error.message)) throw new UnknownCodeError(error.message);
    throw error;
  }
}

export async function setReaction(targetId, night, emoji) {
  const { error } = await supabase.rpc("set_reaction", { p_target: targetId, p_night: night, p_emoji: emoji });
  if (error) throw error;
}

export async function updateGoal(goal) {
  const { error } = await supabase.rpc("update_goal", { p_goal: goal });
  if (error) throw error;
}

export async function signOut() {
  await supabase.auth.signOut();
}

/**
 * Loads the caller's group and computes every member's nights from the raw events.
 * Returns null if this browser hasn't joined a group yet.
 */
export async function loadGroup(now = new Date()) {
  const { data: session } = await supabase.auth.getSession();
  if (!session.session) return null;
  const { data, error } = await supabase.rpc("group_data");
  if (error) throw error;
  if (!data) return null;

  const [y, m, d] = data.group.challenge_start.split("-").map(Number);
  const start = new Date(y, m - 1, d);
  const end = addDays(start, data.group.challenge_nights - 1);
  let last = lastNightDate(now);
  if (last > end) last = end;
  if (last < start) last = null; // the first night hasn't finished yet

  const eventsBy = new Map();
  for (const [participant, kind, at] of data.events) {
    if (!eventsBy.has(participant)) eventsBy.set(participant, []);
    eventsBy.get(participant).push({ kind, at: new Date(at) });
  }
  const androidNights = new Set(data.android_nights.map((n) => `${n.participant}|${n.night}`));

  const members = data.members.map((p) => {
    const evs = eventsBy.get(p.name) || [];
    const intervals = useIntervals(evs);
    const nights = {};
    if (last) {
      for (let day = new Date(start); day <= last; day = addDays(day, 1)) {
        const key = isoDate(day);
        // Android reports each night explicitly; no report means "missing". iPhone can't tell.
        if (p.platform === "android" && !androidNights.has(`${p.name}|${key}`)) {
          nights[key] = { date: key, bucket: "missing", min: null, sessions: [] };
        } else {
          nights[key] = { date: key, ...summarizeNight(intervals, day, p.goal) };
        }
      }
    }
    return { id: p.id, name: p.name, goal: p.goal, platform: p.platform, me: p.id === data.me, nights };
  });

  return {
    live: true,
    name: data.group.name,
    start,
    last,
    nightsTotal: data.group.challenge_nights,
    members,
    reactions: data.reactions,
    meId: data.me,
  };
}
