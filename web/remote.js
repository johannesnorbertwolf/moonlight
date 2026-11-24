// Live data from Supabase: anonymous sign-in, starting and joining groups, the board, reactions.
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";
import { SUPABASE_URL, SUPABASE_KEY } from "./config.js";
import { isoDate, addDays, lastNightDate, bucketFor } from "./data.js";
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
export class NameTakenError extends Error {}

function rpcError(error) {
  if (/unknown group code/.test(error.message)) return new UnknownCodeError(error.message);
  if (/name taken/.test(error.message)) return new NameTakenError(error.message);
  return error;
}

export async function hasSession() {
  const { data } = await supabase.auth.getSession();
  return !!data.session;
}

/** Joins the group with this code; returns my participant id. `takeover` reuses a participant with this name. */
export async function join(code, name, goal, platform, takeover = false) {
  await ensureSession();
  const { data, error } = await supabase.rpc("join_group", {
    p_code: code, p_name: name, p_goal: goal, p_platform: platform, p_takeover: takeover,
  });
  if (error) throw rpcError(error);
  return data;
}

/** Starts a new group with me as owner; returns my participant id. */
export async function createGroup(groupName, name, goal, platform) {
  await ensureSession();
  const { data, error } = await supabase.rpc("create_group", {
    p_group_name: groupName, p_name: name, p_goal: goal, p_platform: platform,
    p_timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Amsterdam",
  });
  if (error) throw rpcError(error);
  return data;
}

/** {name, code, members} for a code, or null. Works without signing in. */
export async function groupInfo(code) {
  const { data, error } = await supabase.rpc("group_info", { p_code: code });
  if (error) throw error;
  return data;
}

export async function leaveGroup() {
  const { error } = await supabase.rpc("leave_group");
  if (error) throw error;
  await supabase.auth.signOut();
}

export async function removeMember(id) {
  const { error } = await supabase.rpc("remove_member", { p_member: id });
  if (error) throw error;
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
  // Nights from the Moonlight iPhone app (Screen Time): only "at least N minutes" (migration 0004).
  const screenTime = new Map((data.screen_time_nights || []).map((n) => [`${n.participant}|${n.night}`, n]));
  const usesApp = new Set((data.screen_time_nights || []).map((n) => n.participant));

  const members = data.members.map((p) => {
    const evs = eventsBy.get(p.name) || [];
    const intervals = useIntervals(evs);
    const nights = {};
    if (last) {
      for (let day = new Date(start); day <= last; day = addDays(day, 1)) {
        const key = isoDate(day);
        // Android and the iPhone app report each night explicitly; no report means "missing".
        // iPhones with Shortcuts can't tell.
        if (usesApp.has(p.name)) {
          const s = screenTime.get(`${p.name}|${key}`);
          nights[key] = s
            ? { date: key, bucket: bucketFor(s.minutes), min: s.minutes, atLeast: true, sessions: [],
                crossedAt: s.crossed_at ? new Date(s.crossed_at) : null }
            : { date: key, bucket: "missing", min: null, sessions: [] };
        } else if (p.platform === "android" && !androidNights.has(`${p.name}|${key}`)) {
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
    code: data.group.code || null,
    ownerId: data.group.owner || null,
    iAmOwner: !!data.group.owner && data.group.owner === data.me,
    start,
    last,
    nightsTotal: data.group.challenge_nights,
    members,
    reactions: data.reactions,
    meId: data.me,
  };
}
