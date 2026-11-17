import { t, setLang, getLang, guessLang } from "./i18n.js";
import {
  REACTIONS, CHALLENGE_NIGHTS, DEMO_GROUP_CODE, WINDOW_END,
  loadState, saveState, buildGroup, isoDate, addDays, pad,
  inNightWindow, minutesUntilWindow, windowLength, toMinutes,
  personalStreak, groupStreak, bestStreak,
} from "./data.js";
import { moonSvg } from "./moon.js";

const app = document.getElementById("app");
const state = loadState();
state.reactions ??= {};
state.demo ??= true;
setLang(state.lang || guessLang());

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const save = () => saveState(state);

function toast(msg) {
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 1800);
}

function dayLabel(d) {
  return d.toLocaleDateString(getLang() === "nl" ? "nl-NL" : "en-GB", { weekday: "short" });
}

function longDate(d) {
  return d.toLocaleDateString(getLang() === "nl" ? "nl-NL" : "en-GB", { weekday: "long", day: "numeric", month: "long" });
}

function nightsText(n) {
  return n === 1 ? t("today.night1") : t("today.nights", { n });
}

// ---------------------------------------------------------------- onboarding

let onbStep = 0;
const onbDraft = { name: "", code: "", goal: "21:00", platform: "ios" };

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
      </div>`;
    bindLangButtons(renderOnboarding);
    app.querySelector("#go").onclick = () => { onbStep = 1; renderOnboarding(); };
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

        <label for="code">${t("onb.code")}</label>
        <input id="code" autocapitalize="characters" value="${esc(onbDraft.code)}">
        <div class="hint">${t("onb.code.hint")}</div>
        <div class="error" id="e-code"></div>

        <label for="goal">${t("onb.goal")}</label>
        <input id="goal" type="time" value="${onbDraft.goal}">
        <div class="hint">${t("onb.goal.hint")}</div>

        <label>${t("onb.platform")}</label>
        <div class="seg">
          <button type="button" data-p="ios" aria-pressed="${onbDraft.platform === "ios"}">iPhone</button>
          <button type="button" data-p="android" aria-pressed="${onbDraft.platform === "android"}">Android</button>
        </div>
        <button class="btn-primary btn-block" type="submit">${t("onb.continue")}</button>
      </form>`;
    const f = app.querySelector("#f");
    f.querySelectorAll("[data-p]").forEach((b) => (b.onclick = () => {
      onbDraft.platform = b.dataset.p;
      f.querySelectorAll("[data-p]").forEach((x) => x.setAttribute("aria-pressed", x === b));
    }));
    const name = f.querySelector("#name");
    const code = f.querySelector("#code");
    name.oninput = () => (f.querySelector("#e-name").textContent = "");
    code.oninput = () => (f.querySelector("#e-code").textContent = "");
    f.onsubmit = (ev) => {
      ev.preventDefault();
      onbDraft.name = name.value.trim();
      onbDraft.code = code.value.trim();
      onbDraft.goal = f.querySelector("#goal").value || "21:00";
      let ok = true;
      if (!onbDraft.name) { f.querySelector("#e-name").textContent = t("onb.err.name"); ok = false; }
      if (onbDraft.code.toUpperCase() !== DEMO_GROUP_CODE) { f.querySelector("#e-code").textContent = t("onb.err.code"); ok = false; }
      if (ok) { onbStep = 2; renderOnboarding(); }
    };
    return;
  }
  app.innerHTML = `
    <h1>${t("onb.setup.title")}</h1>
    <div class="card"><p>${t(onbDraft.platform === "ios" ? "onb.setup.ios" : "onb.setup.android")}</p>
    <p class="muted" style="margin:0">${t("onb.setup.home")}</p></div>
    <button class="btn-primary btn-block" id="done">${t("onb.done")}</button>`;
  app.querySelector("#done").onclick = () => {
    state.profile = { name: onbDraft.name, goal: onbDraft.goal, platform: onbDraft.platform };
    save();
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
  const greet = h >= 5 && h < 12 ? "today.greeting.morning" : h < 18 && h >= 12 ? "today.greeting.day" : "today.greeting.evening";
  const active = inNightWindow(me.goal, now);
  const until = minutesUntilWindow(me.goal, now);
  const lastKey = isoDate(group.last);
  const night = me.nights[lastKey];
  const nightNo = Math.round((group.last - group.start) / 864e5) + 1;
  const tips = t("tips");
  const tip = tips[Math.floor(now / 864e5) % tips.length];

  app.innerHTML = `
    <h1>${t(greet, { name: esc(me.name) })}</h1>
    <p class="muted">${longDate(now)} · ${t("today.challenge", { n: nightNo, total: CHALLENGE_NIGHTS })}</p>

    <div class="card">
      ${active
        ? `<h2>${t("today.window.active")}</h2><p class="muted" style="margin:0">${t("today.window.active.body")}</p>`
        : `<h2 style="margin-bottom:4px">${t("today.window.upcoming", { time: me.goal })}</h2>
           <p class="muted" style="margin:0">${t("today.window.in", { h: Math.floor(until / 60), m: until % 60 })}</p>`}
    </div>

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
    </div>

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
  const me = group.members.find((m) => m.me);
  const night = me.nights[isoDate(group.last)];
  const len = windowLength(me.goal);
  const used = night.min ?? 0;
  const share = Math.max(0, 1 - used / len);

  // When the 2-minute margin was crossed, from the session list.
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
  else msg = t("recap.used", { min: Math.round(used), time: crossed });

  const midLabel = clock(me.goal, len / 2);
  app.innerHTML = `
    <p class="muted" style="margin:0">${longDate(group.last)}</p>
    <h1>${t("recap.title")}</h1>
    <div class="ring">${ringSvg(night.bucket === "missing" ? 0 : share)}</div>
    <div class="muted small">${t("recap.window", { start: me.goal })}</div>
    <div class="timeline" aria-hidden="true">
      ${night.sessions.map((s) => `<span style="left:${(s.offset / len) * 100}%;width:${Math.max(0.6, (s.min / len) * 100)}%"></span>`).join("")}
    </div>
    <div class="timeline-labels"><span>${me.goal}</span><span>${midLabel}</span><span>${WINDOW_END}</span></div>
    <div class="card">${msg}</div>
    <a class="btn btn-primary btn-block" href="#/group">${t("recap.toGroup")}</a>`;
}

// ---------------------------------------------------------------- group

function reactionKey(memberId, date) {
  return `${memberId}|${date}`;
}

/** Made-up reactions from the other members, stable per night. */
function fakeReactions(group, member, date) {
  const others = group.members.filter((m) => !m.me && m.id !== member.id);
  const night = member.nights[date];
  if (!night || night.bucket === "missing") return [];
  const pool = night.bucket === "free" ? ["🌙", "👏", "🔥", "😴"] : ["🦉", "🥱", "❤️", "🦥"];
  return others
    .filter((o) => (o.id.charCodeAt(0) + date.charCodeAt(9)) % 3 !== 0)
    .map((o) => pool[(o.id.length + date.charCodeAt(8)) % pool.length]);
}

function reactionsFor(group, member, date) {
  const counts = new Map();
  for (const e of fakeReactions(group, member, date)) counts.set(e, (counts.get(e) || 0) + 1);
  const mine = member.me ? null : state.reactions[reactionKey(member.id, date)];
  if (mine) counts.set(mine, (counts.get(mine) || 0) + 1);
  return { counts, mine };
}

function renderGroup(group) {
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
          <div class="avatar">${esc(m.name[0] || "?").toUpperCase()}</div>
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

function bindReactions(group, date) {
  app.querySelectorAll(".moon-btn").forEach((btn) => {
    let timer = null;
    let longPressed = false;
    const key = reactionKey(btn.dataset.member, date);

    btn.addEventListener("pointerdown", () => {
      longPressed = false;
      timer = setTimeout(() => { longPressed = true; openTray(btn, key, group); }, 450);
    });
    const cancel = () => clearTimeout(timer);
    btn.addEventListener("pointerup", cancel);
    btn.addEventListener("pointerleave", cancel);
    btn.addEventListener("contextmenu", (e) => e.preventDefault());
    btn.addEventListener("click", (ev) => {
      // The click that ends a long press must not reach the document, which closes the tray.
      if (longPressed) { ev.stopPropagation(); return; }
      // Quick tap: toggle the default 🌙 reaction.
      if (state.reactions[key] === "🌙") delete state.reactions[key];
      else state.reactions[key] = "🌙";
      save();
      renderGroup(group);
    });
  });
}

function openTray(anchor, key, group) {
  closeTray();
  const tray = document.createElement("div");
  tray.className = "tray";
  tray.setAttribute("role", "menu");
  tray.innerHTML = REACTIONS.map((e) =>
    `<button role="menuitem" data-e="${e}" aria-pressed="${state.reactions[key] === e}">${e}</button>`).join("");
  document.body.appendChild(tray);

  const r = anchor.getBoundingClientRect();
  const w = tray.offsetWidth;
  const left = Math.max(16, Math.min(window.innerWidth - w - 16, r.right - w));
  tray.style.left = `${left + window.scrollX}px`;
  tray.style.top = `${r.top + window.scrollY - tray.offsetHeight - 8}px`;

  tray.querySelectorAll("button").forEach((b) => (b.onclick = (ev) => {
    ev.stopPropagation();
    if (state.reactions[key] === b.dataset.e) delete state.reactions[key];
    else state.reactions[key] = b.dataset.e;
    save();
    closeTray();
    renderGroup(group);
  }));
  setTimeout(() => document.addEventListener("click", closeTray, { once: true }), 0);
}

function closeTray() {
  document.querySelectorAll(".tray").forEach((x) => x.remove());
}

// ---------------------------------------------------------------- history

function renderHistory(group) {
  const me = group.members.find((m) => m.me);
  const nights = [...Array(CHALLENGE_NIGHTS)].map((_, i) => addDays(group.start, i));
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

function renderSettings() {
  const p = state.profile;
  app.innerHTML = `
    <h1>${t("settings.title")}</h1>
    <form id="f" novalidate>
      <label for="name">${t("settings.name")}</label>
      <input id="name" value="${esc(p.name)}" maxlength="40">
      <div class="error" id="e-name"></div>
      <label for="goal">${t("settings.goal")}</label>
      <input id="goal" type="time" value="${p.goal}">
      <div class="hint">${t("settings.goal.note")}</div>
      <label>${t("settings.language")}</label>
      <div class="seg">${langButtons()}</div>
      <label class="toggle"><input type="checkbox" id="demo" ${state.demo ? "checked" : ""}> ${t("settings.demo")}</label>
      <button class="btn-primary btn-block" type="submit">${t("settings.save")}</button>
    </form>
    <button class="btn-block" id="reset">${t("settings.reset")}</button>
    <p class="muted small" style="margin-top:16px">${t("settings.prototype")}</p>`;
  bindLangButtons(() => { render(); });
  const f = app.querySelector("#f");
  f.querySelector("#name").oninput = () => (f.querySelector("#e-name").textContent = "");
  f.onsubmit = (ev) => {
    ev.preventDefault();
    const name = f.querySelector("#name").value.trim();
    if (!name) { f.querySelector("#e-name").textContent = t("onb.err.name"); return; }
    p.name = name;
    p.goal = f.querySelector("#goal").value || p.goal;
    state.demo = f.querySelector("#demo").checked;
    save();
    toast(t("settings.saved"));
    render();
  };
  app.querySelector("#reset").onclick = () => {
    delete state.profile;
    state.reactions = {};
    save();
    onbStep = 0;
    render();
  };
}

// ---------------------------------------------------------------- router

const ROUTES = { today: renderToday, recap: renderRecap, group: renderGroup, history: renderHistory, settings: renderSettings };
const TAB_FOR = { today: "today", recap: "today", group: "group", history: "history", settings: "settings" };

function render() {
  closeTray();
  if (!state.profile) return renderOnboarding();
  const nav = document.querySelector("nav.tabs");
  nav.hidden = false;
  const route = (location.hash.replace(/^#\//, "") || "today").split("?")[0];
  const name = ROUTES[route] ? route : "today";
  nav.querySelectorAll("a").forEach((a) => {
    a.querySelector(".lbl").textContent = t("tab." + a.dataset.tab);
    if (a.dataset.tab === TAB_FOR[name]) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
  ROUTES[name](buildGroup(state.profile));
  window.scrollTo(0, 0);
}

window.addEventListener("hashchange", render);
render();
