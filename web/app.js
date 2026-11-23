import { t, setLang, getLang, guessLang } from "./i18n.js";
import {
  REACTIONS, WINDOW_END,
  loadState, saveState, buildGroup, isoDate, addDays, pad,
  inNightWindow, minutesUntilWindow, windowLength, toMinutes,
  personalStreak, groupStreak, bestStreak,
} from "./data.js";
import { moonSvg } from "./moon.js";

// Two modes: "live" (Supabase, real group) and "demo" (made-up group, nothing sent anywhere).
// The Supabase code is loaded only in live mode, so the demo works without it.
const app = document.getElementById("app");
const state = loadState();
state.reactions ??= {};
state.demo ??= false;
setLang(state.lang || guessLang());

let remote = null;
async function getRemote() {
  remote ??= await import("./remote.js");
  return remote;
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const save = () => saveState(state);

function toast(msg) {
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2200);
}

const locale = () => (getLang() === "nl" ? "nl-NL" : "en-GB");
const dayLabel = (d) => d.toLocaleDateString(locale(), { weekday: "short" });
const longDate = (d) => d.toLocaleDateString(locale(), { weekday: "long", day: "numeric", month: "long" });
const nightsText = (n) => (n === 1 ? t("today.night1") : t("today.nights", { n }));

function emptyState() {
  return `
    <div class="card" style="text-align:center;padding:32px 16px">
      ${moonSvg("future", 64, { bg: "var(--surface)" })}
      <h2 style="margin-top:16px">${t("empty.title")}</h2>
      <p class="muted" style="margin:0">${t("empty.body")}</p>
    </div>`;
}

// ---------------------------------------------------------------- onboarding

let onbStep = 0;
const onbDraft = { name: state.profile?.name || "", goal: state.profile?.goal || "21:00", platform: state.profile?.platform || "ios", demo: false };

function renderOnboarding() {
  document.querySelector("nav.tabs").hidden = true;
  if (onbStep === 0) {
    app.innerHTML = `
      <div style="text-align:center;margin-top:12vh">
        ${moonSvg("free", 96)}
        <h1 style="margin-top:24px">${t("onb.welcome.title")}</h1>
        <p class="muted">${t("onb.welcome.body")}</p>
        <div class="seg" style="margin:24px 0 8px">${langButtons()}</div>
        <button class="btn-primary btn-block" id="go">${t("onb.start")}</button>
        <button class="btn-block link" id="demo" style="margin-top:20px">${t("onb.demo")}</button>
      </div>`;
    bindLangButtons(renderOnboarding);
    app.querySelector("#go").onclick = () => { onbDraft.demo = false; onbStep = 1; renderOnboarding(); };
    app.querySelector("#demo").onclick = () => { onbDraft.demo = true; onbStep = 1; renderOnboarding(); };
    return;
  }
  if (onbStep === 1) {
    app.innerHTML = `
      <h1>Moonlight</h1>
      <form id="f" novalidate>
        <label for="name">${t("onb.name")}</label>
        <input id="name" autocomplete="given-name" value="${esc(onbDraft.name)}" maxlength="40">
        <div class="hint">${t("onb.name.hint")}</div>
        <div class="error" id="e-name"></div>

        <label for="goal">${t("onb.goal")}</label>
        <input id="goal" type="time" value="${onbDraft.goal}">
        <div class="hint">${t("onb.goal.hint")}</div>

        <label>${t("onb.platform")}</label>
        <div class="seg">
          <button type="button" data-p="ios" aria-pressed="${onbDraft.platform === "ios"}">iPhone</button>
          <button type="button" data-p="android" aria-pressed="${onbDraft.platform === "android"}">Android</button>
        </div>
        <div class="error" id="e-form"></div>
        <button class="btn-primary btn-block" type="submit" id="submit">${t("onb.continue")}</button>
      </form>`;
    const f = app.querySelector("#f");
    f.querySelectorAll("[data-p]").forEach((b) => (b.onclick = () => {
      onbDraft.platform = b.dataset.p;
      f.querySelectorAll("[data-p]").forEach((x) => x.setAttribute("aria-pressed", x === b));
    }));
    const name = f.querySelector("#name");
    name.oninput = () => (f.querySelector("#e-name").textContent = "");
    f.onsubmit = async (ev) => {
      ev.preventDefault();
      onbDraft.name = name.value.trim();
      onbDraft.goal = f.querySelector("#goal").value || "21:00";
      let ok = true;
      if (!onbDraft.name) { f.querySelector("#e-name").textContent = t("onb.err.name"); ok = false; }
      if (!ok) return;
      if (!onbDraft.demo) {
        const btn = f.querySelector("#submit");
        btn.disabled = true;
        btn.textContent = t("loading");
        try {
          const r = await getRemote();
          await r.join(onbDraft.name, onbDraft.goal, onbDraft.platform);
        } catch (e) {
          btn.disabled = false;
          btn.textContent = t("onb.continue");
          f.querySelector("#e-form").textContent = t("onb.err.network");
          console.error(e);
          return;
        }
      }
      onbStep = 2;
      renderOnboarding();
    };
    return;
  }
  app.innerHTML = `
    <h1>${t("onb.setup.title")}</h1>
    <div class="card"><p>${t(onbDraft.platform === "ios" ? "onb.setup.ios" : "onb.setup.android")}</p>
    <p class="muted" style="margin:0">${t("onb.setup.home")}</p></div>
    <button class="btn-primary btn-block" id="done">${t("onb.done")}</button>`;
  app.querySelector("#done").onclick = () => {
    state.mode = onbDraft.demo ? "demo" : "live";
    state.profile = { name: onbDraft.name, goal: onbDraft.goal, platform: onbDraft.platform };
    save();
    onbStep = 0;
    location.hash = "#/today";
    render();
  };
}

function langButtons() {
  return ["en", "nl"].map((l) =>
    `<button type="button" data-lang="${l}" aria-pressed="${getLang() === l}">${l === "en" ? "English" : "Nederlands"}</button>`).join("");
}

function bindLangButtons(rerender) {
  app.querySelectorAll("[data-lang]").forEach((b) => (b.onclick = () => {
    state.lang = b.dataset.lang;
    setLang(state.lang);
    save();
    rerender();
  }));
}

// ---------------------------------------------------------------- today

function renderToday(group) {
  const me = group.members.find((m) => m.me);
  const now = new Date();
  const h = now.getHours();
  const greet = h >= 5 && h < 12 ? "today.greeting.morning" : h >= 12 && h < 18 ? "today.greeting.day" : "today.greeting.evening";
  const active = inNightWindow(me.goal, now);
  const until = minutesUntilWindow(me.goal, now);
  const tips = t("tips");
  const tip = tips[Math.floor(now / 864e5) % tips.length];
  const night = group.last && me.nights[isoDate(group.last)];
  const nightNo = group.last ? Math.round((group.last - group.start) / 864e5) + 1 : 0;

  app.innerHTML = `
    <h1>${t(greet, { name: esc(me.name) })}</h1>
    <p class="muted">${longDate(now)}${nightNo ? ` · ${t("today.challenge", { n: nightNo, total: group.nightsTotal })}` : ""}</p>

    <div class="card">
      ${active
        ? `<h2>${t("today.window.active")}</h2><p class="muted" style="margin:0">${t("today.window.active.body")}</p>`
        : `<h2 style="margin-bottom:4px">${t("today.window.upcoming", { time: me.goal })}</h2>
           <p class="muted" style="margin:0">${t("today.window.in", { h: Math.floor(until / 60), m: until % 60 })}</p>`}
    </div>

    ${night ? `
    <a class="card row" href="#/recap" style="color:inherit;text-decoration:none;display:flex">
      ${moonSvg(night.bucket, 44, { bg: "var(--surface)", label: t("bucket." + night.bucket) })}
      <div class="grow">
        <div class="muted small">${t("today.lastNight")}</div>
        <div style="font-weight:600">${t("bucket." + night.bucket)}</div>
      </div>
      <span class="link">${t("today.seeRecap")} ›</span>
    </a>

    <div class="stats">
      <div class="card stat" style="margin:0"><div class="muted small">${t("today.streak")}</div><div class="num">${nightsText(personalStreak(me, group.last))}</div></div>
      <div class="card stat" style="margin:0"><div class="muted small">${t("today.groupStreak")}</div><div class="num">${nightsText(groupStreak(group))}</div></div>
    </div>` : emptyState()}

    <div class="card">
      <div class="muted small">${t("today.tip")}</div>
      <p style="margin:4px 0 0">${tip}</p>
    </div>`;
}

// ---------------------------------------------------------------- recap

function ringSvg(share) {
  const r = 70;
  const c = 2 * Math.PI * r;
  const pct = Math.round(share * 100);
  return `
    <svg width="180" height="180" viewBox="0 0 180 180" role="img" aria-label="${pct}% ${t("recap.phoneFree")}">
      <circle cx="90" cy="90" r="${r}" fill="none" stroke="var(--surface-2)" stroke-width="14"/>
      <circle cx="90" cy="90" r="${r}" fill="none" stroke="var(--accent)" stroke-width="14" stroke-linecap="round"
        stroke-dasharray="${(c * share).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 90 90)"/>
      <text x="90" y="86" text-anchor="middle" fill="var(--text)" font-size="32" font-weight="600">${pct}%</text>
      <text x="90" y="112" text-anchor="middle" fill="var(--text-2)" font-size="14">${t("recap.phoneFree")}</text>
    </svg>`;
}

function clock(goal, offsetMin) {
  const m = (toMinutes(goal) + Math.round(offsetMin)) % (24 * 60);
  return `${pad(Math.floor(m / 60))}:${pad(m % 60)}`;
}

function renderRecap(group) {
  if (!group.last) { app.innerHTML = `<h1>${t("recap.title")}</h1>${emptyState()}`; return; }
  const me = group.members.find((m) => m.me);
  const night = me.nights[isoDate(group.last)];
  const len = windowLength(me.goal);
  const used = night.min ?? 0;
  const share = Math.max(0, 1 - used / len);

  let crossed = null;
  let total = 0;
  for (const s of night.sessions) {
    if (total + s.min >= 2) { crossed = clock(me.goal, s.offset + (2 - total)); break; }
    total += s.min;
  }

  let msg;
  if (night.bucket === "missing") msg = t("bucket.missing");
  else if (used === 0) msg = t("recap.free");
  else if (night.bucket === "free") msg = t("recap.freeSmall", { min: used });
  else if (night.atLeast) {
    // iPhone app (Screen Time): only the threshold passed and when 2 minutes were reached.
    const at = night.crossedAt ? `${pad(night.crossedAt.getHours())}:${pad(night.crossedAt.getMinutes())}` : null;
    msg = at ? t("recap.atLeast", { min: used, time: at }) : t("recap.atLeastNoTime", { min: used });
  }
  else msg = t("recap.used", { min: Math.round(used), time: crossed });

  app.innerHTML = `
    <p class="muted" style="margin:0">${longDate(group.last)}</p>
    <h1>${t("recap.title")}</h1>
    <div class="ring">${ringSvg(night.bucket === "missing" ? 0 : share)}</div>
    <div class="muted small">${t("recap.window", { start: me.goal })}</div>
    <div class="timeline" aria-hidden="true">
      ${night.sessions.map((s) => `<span style="left:${(s.offset / len) * 100}%;width:${Math.max(0.6, (s.min / len) * 100)}%"></span>`).join("")}
    </div>
    <div class="timeline-labels"><span>${me.goal}</span><span>${clock(me.goal, len / 2)}</span><span>${WINDOW_END}</span></div>
    <div class="card">${msg}</div>
    <a class="btn btn-primary btn-block" href="#/group">${t("recap.toGroup")}</a>`;
}

// ---------------------------------------------------------------- group

/** Made-up reactions from the other demo members, stable per night. */
function fakeReactions(group, member, date) {
  const others = group.members.filter((m) => !m.me && m.id !== member.id);
  const night = member.nights[date];
  if (!night || night.bucket === "missing") return [];
  const pool = night.bucket === "free" ? ["🌙", "👏", "🔥", "😴"] : ["🦉", "🥱", "❤️", "🦥"];
  return others
    .filter((o) => (o.id.charCodeAt(0) + date.charCodeAt(9)) % 3 !== 0)
    .map((o) => pool[(o.id.length + date.charCodeAt(8)) % pool.length]);
}

/** {counts: Map(emoji → n), mine: emoji|undefined} for one member's night. */
function reactionsFor(group, member, date) {
  const counts = new Map();
  const add = (e) => counts.set(e, (counts.get(e) || 0) + 1);
  let mine;
  if (group.live) {
    for (const r of group.reactions) {
      if (r.target !== member.id || r.night !== date) continue;
      add(r.emoji);
      if (r.from === group.meId) mine = r.emoji;
    }
  } else {
    fakeReactions(group, member, date).forEach(add);
    mine = member.me ? undefined : state.reactions[`${member.id}|${date}`];
    if (mine) add(mine);
  }
  return { counts, mine };
}

function renderGroup(group) {
  if (!group.last) { app.innerHTML = `<h1>${esc(group.name)}</h1>${emptyState()}`; return; }
  const date = isoDate(group.last);
  const me = group.members.find((m) => m.me);
  const ok = group.members.filter((m) => m.nights[date].bucket === "free").length;
  const days = [...Array(7)].map((_, i) => addDays(group.last, i - 6));
  const canReact = state.demo || !inNightWindow(me.goal);

  app.innerHTML = `
    <p class="muted" style="margin:0">${t("group.lastNight")} · ${longDate(group.last)}</p>
    <h1>${t("group.title", { ok, n: group.members.length })}</h1>
    <p class="muted">${t("today.groupStreak")}: ${nightsText(groupStreak(group))}</p>

    ${group.members.map((m) => {
      const n = m.nights[date];
      const { counts, mine } = reactionsFor(group, m, date);
      const chips = [...counts].map(([e, c]) => `<span class="chip${e === mine ? " mine" : ""}">${e}${c > 1 ? " " + c : ""}</span>`).join("");
      return `
        <div class="member">
          <div class="avatar">${esc((m.name[0] || "?").toUpperCase())}</div>
          <div class="grow">
            <div style="font-weight:600">${esc(m.name)}${m.me ? ` <span class="muted small">(${t("group.you")})</span>` : ""}</div>
            <div class="muted small">${t("bucket." + n.bucket)} · ${t("group.goal", { time: m.goal })}</div>
            ${chips ? `<div class="chips">${chips}</div>` : ""}
          </div>
          ${m.me
            ? moonSvg(n.bucket, 36, { bg: "var(--surface)", label: t("bucket." + n.bucket) })
            : `<button class="moon-btn" data-member="${m.id}" aria-label="${esc(m.name)}: ${t("bucket." + n.bucket)}">${moonSvg(n.bucket, 36, { bg: "var(--surface)" })}</button>`}
        </div>`;
    }).join("")}
    <p class="muted small" style="text-align:center">${canReact ? t("group.react.hint") : t("group.react.closed")}</p>

    <div class="card">
      <h2>${t("group.week")}</h2>
      <div class="grid7">
        <div></div>${days.map((d) => `<div class="day">${dayLabel(d)}</div>`).join("")}
        ${group.members.map((m) => `
          <div class="name">${esc(m.name)}</div>
          ${days.map((d) => {
            const n = m.nights[isoDate(d)];
            return `<div class="cell">${moonSvg(n ? n.bucket : "future", 20, { bg: "var(--surface)", label: n ? t("bucket." + n.bucket) : "" })}</div>`;
          }).join("")}`).join("")}
      </div>
    </div>`;

  if (canReact) bindReactions(group, date);
}

async function react(group, memberId, date, emoji) {
  const member = group.members.find((m) => m.id === memberId);
  const current = reactionsFor(group, member, date).mine;
  const next = current === emoji ? null : emoji;
  if (group.live) {
    try {
      await (await getRemote()).setReaction(memberId, date, next);
    } catch (e) {
      console.error(e);
      toast(t("react.failed"));
    }
    render();
  } else {
    const key = `${memberId}|${date}`;
    if (next) state.reactions[key] = next;
    else delete state.reactions[key];
    save();
    renderGroup(group);
  }
}

function bindReactions(group, date) {
  app.querySelectorAll(".moon-btn").forEach((btn) => {
    let timer = null;
    let longPressed = false;
    const id = btn.dataset.member;

    btn.addEventListener("pointerdown", () => {
      longPressed = false;
      timer = setTimeout(() => { longPressed = true; openTray(btn, group, id, date); }, 450);
    });
    const cancel = () => clearTimeout(timer);
    btn.addEventListener("pointerup", cancel);
    btn.addEventListener("pointerleave", cancel);
    btn.addEventListener("contextmenu", (e) => e.preventDefault());
    btn.addEventListener("click", (ev) => {
      // The click that ends a long press must not reach the document, which closes the tray.
      if (longPressed) { ev.stopPropagation(); return; }
      react(group, id, date, "🌙");
    });
  });
}

function openTray(anchor, group, memberId, date) {
  closeTray();
  const mine = reactionsFor(group, group.members.find((m) => m.id === memberId), date).mine;
  const tray = document.createElement("div");
  tray.className = "tray";
  tray.setAttribute("role", "menu");
  tray.innerHTML = REACTIONS.map((e) =>
    `<button role="menuitem" data-e="${e}" aria-pressed="${mine === e}">${e}</button>`).join("");
  document.body.appendChild(tray);

  const r = anchor.getBoundingClientRect();
  const w = tray.offsetWidth;
  const left = Math.max(16, Math.min(window.innerWidth - w - 16, r.right - w));
  tray.style.left = `${left + window.scrollX}px`;
  tray.style.top = `${r.top + window.scrollY - tray.offsetHeight - 8}px`;

  tray.querySelectorAll("button").forEach((b) => (b.onclick = (ev) => {
    ev.stopPropagation();
    closeTray();
    react(group, memberId, date, b.dataset.e);
  }));
  setTimeout(() => document.addEventListener("click", closeTray, { once: true }), 0);
}

function closeTray() {
  document.querySelectorAll(".tray").forEach((x) => x.remove());
}

// ---------------------------------------------------------------- history

function renderHistory(group) {
  const me = group.members.find((m) => m.me);
  const nights = [...Array(group.nightsTotal)].map((_, i) => addDays(group.start, i));
  const done = Object.values(me.nights);
  const free = done.filter((n) => n.bucket === "free").length;

  app.innerHTML = `
    <h1>${t("history.title")}</h1>
    <div class="card">
      <div class="cal">
        ${nights.map((d) => {
          const n = me.nights[isoDate(d)];
          return `<div style="text-align:center">${moonSvg(n ? n.bucket : "future", 34, { bg: "var(--surface)", label: n ? t("bucket." + n.bucket) : t("history.future") })}
            <div class="muted" style="font-size:11px">${d.getDate()}</div></div>`;
        }).join("")}
      </div>
    </div>
    <div class="stats">
      <div class="card stat" style="margin:0"><div class="muted small">${t("history.free")}</div><div class="num">${free} / ${done.length}</div></div>
      <div class="card stat" style="margin:0"><div class="muted small">${t("history.best")}</div><div class="num">${nightsText(bestStreak(me))}</div></div>
    </div>
    <div class="card">
      <h2>${t("history.legend")}</h2>
      <div class="legend">
        ${["free", "light", "medium", "heavy", "very_heavy", "missing", "future"].map((b) =>
          `${moonSvg(b, 22, { bg: "var(--surface)" })}<span>${b === "future" ? t("history.future") : t("bucket." + b)}</span>`).join("")}
      </div>
    </div>`;
}

// ---------------------------------------------------------------- settings

function renderSettings(group) {
  const live = state.mode === "live";
  const me = group.members.find((m) => m.me);
  app.innerHTML = `
    <h1>${t("settings.title")}</h1>
    <form id="f" novalidate>
      <label for="name">${t("settings.name")}</label>
      <input id="name" value="${esc(me.name)}" maxlength="40" ${live ? "disabled" : ""}>
      ${live ? `<div class="hint">${t("settings.name.locked")}</div>` : ""}
      <div class="error" id="e-name"></div>
      <label for="goal">${t("settings.goal")}</label>
      <input id="goal" type="time" value="${me.goal}">
      <div class="hint">${t("settings.goal.note")}</div>
      <label>${t("settings.language")}</label>
      <div class="seg">${langButtons()}</div>
      <label class="toggle"><input type="checkbox" id="demo" ${state.demo ? "checked" : ""}> ${t("settings.demo")}</label>
      <button class="btn-primary btn-block" type="submit">${t("settings.save")}</button>
    </form>
    <button class="btn-block" id="reset">${t("settings.reset")}</button>
    <p class="muted small" style="margin-top:16px">${live ? t("settings.live", { group: esc(group.name) }) : t("settings.prototype")}</p>`;
  bindLangButtons(() => render());
  const f = app.querySelector("#f");
  f.querySelector("#name").oninput = () => (f.querySelector("#e-name").textContent = "");
  f.onsubmit = async (ev) => {
    ev.preventDefault();
    const goal = f.querySelector("#goal").value || me.goal;
    state.demo = f.querySelector("#demo").checked;
    if (live) {
      try {
        if (goal !== me.goal) await (await getRemote()).updateGoal(goal);
      } catch (e) {
        console.error(e);
        toast(t("onb.err.network"));
        return;
      }
      state.profile.goal = goal;
    } else {
      const name = f.querySelector("#name").value.trim();
      if (!name) { f.querySelector("#e-name").textContent = t("onb.err.name"); return; }
      state.profile.name = name;
      state.profile.goal = goal;
    }
    save();
    toast(t("settings.saved"));
    render();
  };
  app.querySelector("#reset").onclick = async () => {
    if (live) {
      try { await (await getRemote()).signOut(); } catch (e) { console.error(e); }
    }
    delete state.profile;
    delete state.mode;
    state.reactions = {};
    save();
    onbStep = 0;
    render();
  };
}

// ---------------------------------------------------------------- router

const ROUTES = { today: renderToday, recap: renderRecap, group: renderGroup, history: renderHistory, settings: renderSettings };
const TAB_FOR = { today: "today", recap: "today", group: "group", history: "history", settings: "settings" };
let renderSeq = 0;

async function loadCurrentGroup() {
  if (state.mode === "demo") return buildGroup(state.profile);
  const r = await getRemote();
  let group = await r.loadGroup();
  if (!group && state.profile?.name) {
    // This browser joined before but its sign-in is gone (cleared storage, expired session):
    // join again silently with the saved name, which takes over the same participant.
    const p = state.profile;
    await r.join(p.name, p.goal, p.platform);
    group = await r.loadGroup();
  }
  return group;
}

async function render() {
  closeTray();
  if (!state.mode || !state.profile) return renderOnboarding();
  const seq = ++renderSeq;

  const nav = document.querySelector("nav.tabs");
  nav.hidden = false;
  const route = (location.hash.replace(/^#\//, "") || "today").split("?")[0];
  const name = ROUTES[route] ? route : "today";
  nav.querySelectorAll("a").forEach((a) => {
    a.querySelector(".lbl").textContent = t("tab." + a.dataset.tab);
    if (a.dataset.tab === TAB_FOR[name]) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });

  if (!app.children.length) app.innerHTML = `<p class="muted">${t("loading")}</p>`;
  let group;
  try {
    group = await loadCurrentGroup();
  } catch (e) {
    console.error(e);
    if (seq !== renderSeq) return;
    app.innerHTML = `<div class="card"><p>${t("error.load")}</p><button class="btn-primary" id="retry">${t("retry")}</button></div>`;
    app.querySelector("#retry").onclick = () => render();
    return;
  }
  if (seq !== renderSeq) return; // a newer render started meanwhile
  if (!group) {
    // Rejoining didn't work: ask again (same name keeps history).
    delete state.mode;
    save();
    return renderOnboarding();
  }
  ROUTES[name](group);
}

window.addEventListener("hashchange", () => { window.scrollTo(0, 0); render(); });
document.addEventListener("visibilitychange", () => { if (!document.hidden && state.mode === "live") render(); });
render();
