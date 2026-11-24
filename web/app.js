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
const onbDraft = {
  name: state.profile?.name || "", goal: state.profile?.goal || "21:00", platform: state.profile?.platform || guessPlatform(),
  demo: false, code: "", info: null, creating: false, groupName: "", takeover: false,
};

function guessPlatform() {
  return /android/i.test(navigator.userAgent) ? "android" : "ios";
}

const isIPhone = () => /iPhone|iPad|iPod/.test(navigator.userAgent);
const normalizeCode = (c) => String(c || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
const spacedCode = (c) => (c && c.length === 6 ? `${c.slice(0, 3)} ${c.slice(3)}` : c || "");
const inviteLink = (code) => `${new URL(".", location.href).href.split("?")[0]}?join=${code}`;
const appLink = (code) => `moonlight://join/${code}`;
// Opens the Android measuring app and hands it the participant id (see android/…/MainActivity.kt).
const androidConnectLink = (p) =>
  `intent://connect?p=${encodeURIComponent(p.participant)}&goal=${encodeURIComponent(p.goal)}&name=${encodeURIComponent(p.name)}` +
  "#Intent;scheme=moonlight;package=nl.moonlight.measure;end";

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
        ${onbDraft.code ? `<p class="muted small">${t("join.linkReady")}</p>` : ""}
        ${onbDraft.code && isIPhone() ? `<a class="btn btn-block" href="${appLink(onbDraft.code)}" style="margin-top:12px">${t("web.openInApp")}</a>` : ""}
        <button class="btn-block link" id="demo" style="margin-top:20px">${t("onb.demo")}</button>
      </div>`;
    bindLangButtons(renderOnboarding);
    app.querySelector("#go").onclick = () => { onbDraft.demo = false; onbStep = 1; renderOnboarding(); };
    app.querySelector("#demo").onclick = () => { onbDraft.demo = true; onbStep = 2; renderOnboarding(); };
    return;
  }
  if (onbStep === 1) return renderGroupStep();
  if (onbStep === 2) return renderProfileStep();

  const p = state.pendingProfile;
  const ios = onbDraft.platform === "ios";
  app.innerHTML = `
    <h1>${t("onb.setup.title")}</h1>
    <div class="card"><p>${t(ios ? "onb.setup.ios" : "onb.setup.android")}</p>
      ${onbDraft.demo ? "" : ios
        ? (p?.code ? `<a class="btn btn-primary btn-block" href="${appLink(p.code)}">${t("web.openInApp")}</a>` : "")
        : `<a class="btn btn-primary btn-block" href="${androidConnectLink(p)}">${t("setup.connect")}</a>
           <p class="muted small" style="margin-bottom:0">${t("setup.connect.hint")}</p>`}
    </div>
    <div class="card"><p class="muted" style="margin:0">${t("onb.setup.home")}</p></div>
    <button class="btn-primary btn-block" id="done">${t("onb.done")}</button>`;
  app.querySelector("#done").onclick = () => {
    state.mode = onbDraft.demo ? "demo" : "live";
    state.profile = onbDraft.demo
      ? { name: onbDraft.name, goal: onbDraft.goal, platform: onbDraft.platform }
      : state.pendingProfile;
    delete state.pendingProfile;
    save();
    onbStep = 0;
    location.hash = "#/today";
    render();
  };
}

function renderGroupStep() {
  const d = onbDraft;
  app.innerHTML = `
    <button class="link" id="back">‹ ${t("back")}</button>
    <h1>${t("join.title")}</h1>
    <p class="muted">${t("join.body")}</p>
    <label for="code">${t("join.code")}</label>
    <input id="code" value="${esc(d.code)}" placeholder="K7QM4P" autocapitalize="characters" autocomplete="off" spellcheck="false"
      style="font-family:ui-monospace,monospace;font-size:22px;letter-spacing:2px" maxlength="9">
    <div class="hint" id="found"></div>
    <button class="btn-primary btn-block" id="join" disabled>${t("join.join")}</button>
    <p class="muted" style="text-align:center;margin:20px 0">${t("join.or")}</p>
    <label for="gname">${t("create.name")}</label>
    <input id="gname" value="${esc(d.groupName)}" placeholder="${esc(t("create.placeholder"))}" maxlength="40">
    <div class="hint">${t("create.hint")}</div>
    <button class="btn-block" id="create" style="margin-top:12px">${t("create.button")}</button>`;
  const codeEl = app.querySelector("#code");
  const found = app.querySelector("#found");
  const joinBtn = app.querySelector("#join");
  let seq = 0;
  const lookUp = async () => {
    const c = normalizeCode(codeEl.value);
    d.code = c;
    d.info = null;
    joinBtn.disabled = true;
    found.textContent = "";
    found.classList.remove("error");
    if (c.length !== 6) return;
    const mySeq = ++seq;
    found.textContent = t("loading");
    let info = null;
    try { info = await (await getRemote()).groupInfo(c); } catch (e) { console.error(e); }
    if (mySeq !== seq) return;
    d.info = info;
    joinBtn.disabled = !info;
    found.textContent = info ? `✓ ${t(info.members === 1 ? "join.found1" : "join.found", { group: info.name, n: info.members })}` : t("join.notFound");
    found.classList.toggle("error", !info);
  };
  codeEl.oninput = lookUp;
  if (d.code) lookUp();
  app.querySelector("#back").onclick = () => { onbStep = 0; renderOnboarding(); };
  joinBtn.onclick = () => { d.creating = false; d.takeover = false; onbStep = 2; renderOnboarding(); };
  app.querySelector("#create").onclick = () => {
    d.groupName = app.querySelector("#gname").value.trim();
    if (!d.groupName) { app.querySelector("#gname").focus(); return; }
    d.creating = true;
    onbStep = 2;
    renderOnboarding();
  };
}

function renderProfileStep() {
  const d = onbDraft;
  const title = d.demo ? "Moonlight" : d.creating ? d.groupName : d.info?.name || "Moonlight";
  app.innerHTML = `
    <button class="link" id="back">‹ ${t("back")}</button>
    <h1>${esc(title)}</h1>
    ${d.demo ? "" : `<p class="muted">${t(d.creating ? "create.you" : "join.you")}</p>`}
    <form id="f" novalidate>
      <label for="name">${t("onb.name")}</label>
      <input id="name" autocomplete="given-name" value="${esc(d.name)}" maxlength="40">
      <div class="hint">${t("onb.name.hint")}</div>
      <div class="error" id="e-name"></div>

      <label for="goal">${t("onb.goal")}</label>
      <input id="goal" type="time" value="${d.goal}">
      <div class="hint">${t("onb.goal.hint")}</div>

      <label>${t("onb.platform")}</label>
      <div class="seg">
        <button type="button" data-p="ios" aria-pressed="${d.platform === "ios"}">iPhone</button>
        <button type="button" data-p="android" aria-pressed="${d.platform === "android"}">Android</button>
      </div>
      <div class="error" id="e-form"></div>
      <button class="btn-primary btn-block" type="submit" id="submit">${t("onb.continue")}</button>
    </form>`;
  app.querySelector("#back").onclick = () => { onbStep = d.demo ? 0 : 1; renderOnboarding(); };
  const f = app.querySelector("#f");
  f.querySelectorAll("[data-p]").forEach((b) => (b.onclick = () => {
    d.platform = b.dataset.p;
    f.querySelectorAll("[data-p]").forEach((x) => x.setAttribute("aria-pressed", x === b));
  }));
  const name = f.querySelector("#name");
  name.oninput = () => { f.querySelector("#e-name").textContent = ""; d.takeover = false; };
  f.onsubmit = async (ev) => {
    ev.preventDefault();
    d.name = name.value.trim();
    d.goal = f.querySelector("#goal").value || "21:00";
    if (!d.name) { f.querySelector("#e-name").textContent = t("onb.err.name"); return; }
    if (!d.demo) {
      const btn = f.querySelector("#submit");
      btn.disabled = true;
      btn.textContent = t("loading");
      try {
        const r = await getRemote();
        const participant = d.creating
          ? await r.createGroup(d.groupName, d.name, d.goal, d.platform)
          : await r.join(d.code, d.name, d.goal, d.platform, d.takeover);
        const g = await r.loadGroup();
        state.pendingProfile = { name: d.name, goal: d.goal, platform: d.platform, participant, code: g?.code || d.code };
        save();
      } catch (e) {
        btn.disabled = false;
        btn.textContent = t("onb.continue");
        if (e instanceof r_NameTaken()) {
          d.takeover = true; // a second tap means "that's me"
          f.querySelector("#e-form").textContent = t("join.nameTaken", { group: esc(d.info?.name || "") });
        } else {
          f.querySelector("#e-form").textContent = t("onb.err.network");
        }
        console.error(e);
        return;
      }
    }
    onbStep = 3;
    renderOnboarding();
  };
}

const r_NameTaken = () => remote?.NameTakenError ?? class {};

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

function inviteCard(group) {
  if (!group.live || !group.code || group.members.length > 1) return "";
  return `<div class="card"><h2>${t("invite.alone.title")}</h2><p class="muted">${t("invite.alone.body")}</p>
    <a class="btn btn-primary btn-block" href="#/invite">${t("invite.title")}</a></div>`;
}

function inviteButton(group) {
  return group.live && group.code ? `<a class="link" href="#/invite" style="float:right;margin-top:4px">＋ ${t("invite.title")}</a>` : "";
}

function renderGroup(group) {
  if (!group.last) {
    app.innerHTML = `
      ${inviteButton(group)}
      <h1>${esc(group.name)}</h1>
      <p class="muted">${t("group.starts", { date: longDate(group.start) })}</p>
      ${inviteCard(group)}
      ${group.members.map((m) => `
        <div class="member">
          <div class="avatar">${esc((m.name[0] || "?").toUpperCase())}</div>
          <div class="grow"><div style="font-weight:600">${esc(m.name)}${m.me ? ` <span class="muted small">(${t("group.you")})</span>` : ""}</div>
          <div class="muted small">${t("group.goal", { time: m.goal })}</div></div>
        </div>`).join("")}
      ${emptyState()}`;
    return;
  }
  const date = isoDate(group.last);
  const me = group.members.find((m) => m.me);
  const ok = group.members.filter((m) => m.nights[date].bucket === "free").length;
  const days = [...Array(7)].map((_, i) => addDays(group.last, i - 6));
  const canReact = state.demo || !inNightWindow(me.goal);

  app.innerHTML = `
    ${inviteButton(group)}
    <p class="muted" style="margin:0">${t("group.lastNight")} · ${longDate(group.last)}</p>
    <h1>${t("group.title", { ok, n: group.members.length })}</h1>
    <p class="muted">${t("today.groupStreak")}: ${nightsText(groupStreak(group))}</p>
    ${inviteCard(group)}

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

// ---------------------------------------------------------------- invite

let qrLib = null;
function loadQr() {
  qrLib ??= new Promise((resolve, reject) => {
    const el = document.createElement("script");
    el.src = "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.js";
    el.onload = () => resolve(window.qrcode);
    el.onerror = reject;
    document.head.appendChild(el);
  });
  return qrLib;
}

function renderInvite(group) {
  if (!group.live || !group.code) { location.hash = "#/group"; return; }
  const link = inviteLink(group.code);
  const message = t("invite.message", { group: group.name, code: group.code });
  app.innerHTML = `
    <a class="link" href="#/group">‹ ${t("back")}</a>
    <h1>${t("invite.title")}</h1>
    <p class="muted">${t("invite.body", { group: esc(group.name) })}</p>
    <div class="qr" id="qr" role="img" aria-label="${t("invite.qr")}"></div>
    <div style="text-align:center;margin:16px 0">
      <div class="muted small">${t("invite.code")}</div>
      <div class="code">${spacedCode(group.code)}</div>
    </div>
    <button class="btn-primary btn-block" id="share">${t("invite.share")}</button>
    <p class="muted small" style="word-break:break-all;text-align:center">${esc(link)}</p>`;
  loadQr().then((qrcode) => {
    const q = qrcode(0, "M");
    q.addData(link);
    q.make();
    const box = app.querySelector("#qr");
    if (box) box.innerHTML = q.createSvgTag({ cellSize: 6, margin: 2, scalable: true });
  }).catch((e) => console.error(e));
  app.querySelector("#share").onclick = async () => {
    if (navigator.share) {
      try { await navigator.share({ title: "Moonlight", text: message, url: link }); } catch (e) { /* cancelled */ }
      return;
    }
    try {
      await navigator.clipboard.writeText(`${message}\n${link}`);
      toast(t("invite.copied"));
    } catch (e) {
      console.error(e);
    }
  };
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
  const android = live && state.profile?.platform === "android" && state.profile?.participant;
  app.innerHTML = `
    <h1>${t("settings.title")}</h1>
    ${live ? `
    <div class="card">
      <h2>${t("settings.group")}</h2>
      <div class="row" style="display:flex;justify-content:space-between"><span>${esc(group.name)}</span>
        <span class="code-small">${spacedCode(group.code)}</span></div>
      ${group.code ? `<a class="btn btn-block" href="#/invite" style="margin-top:12px">${t("invite.title")}</a>` : ""}
      ${group.iAmOwner && group.members.length > 1 ? `
        <h2 style="margin-top:16px">${t("members.title")}</h2>
        ${group.members.filter((m) => !m.me).map((m) => `
          <div class="row" style="display:flex;justify-content:space-between;align-items:center;margin:6px 0">
            <span>${esc(m.name)}</span><button class="link danger" data-remove="${m.id}">${t("remove.confirm")}</button>
          </div>`).join("")}` : ""}
      <button class="btn-block danger" id="leave" style="margin-top:12px">${t("leave.button")}</button>
    </div>` : ""}
    ${android ? `
    <div class="card">
      <h2>${t("setup.connect")}</h2>
      <p class="muted small">${t("setup.connect.hint")}</p>
      <a class="btn btn-block" href="${androidConnectLink({ ...state.profile, goal: me.goal })}">${t("setup.connect")}</a>
    </div>` : ""}
    <form id="f" novalidate>
      <label for="name">${t("settings.name")}</label>
      <input id="name" value="${esc(me.name)}" maxlength="40" ${live ? "disabled" : ""}>
      ${live ? `<div class="hint">${t("settings.name.locked")}</div>` : ""}
      <div class="error" id="e-name"></div>
      <label for="goal">${t("settings.goal")}</label>
      <input id="goal" type="time" value="${me.goal}">
      <div class="hint">${t("settings.goal.note")}${android ? " " + t("settings.goal.android") : ""}</div>
      <label>${t("settings.language")}</label>
      <div class="seg">${langButtons()}</div>
      <label class="toggle"><input type="checkbox" id="demo" ${state.demo ? "checked" : ""}> ${t("settings.demo")}</label>
      <button class="btn-primary btn-block" type="submit">${t("settings.save")}</button>
    </form>
    ${live ? "" : `<button class="btn-block" id="reset">${t("settings.reset")}</button>`}
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
  app.querySelectorAll("[data-remove]").forEach((b) => (b.onclick = async () => {
    const m = group.members.find((x) => x.id === b.dataset.remove);
    if (!confirm(`${t("remove.title", { name: m.name })}\n\n${t("remove.body")}`)) return;
    try {
      await (await getRemote()).removeMember(m.id);
    } catch (e) {
      console.error(e);
      toast(t("onb.err.network"));
    }
    render();
  }));
  const leave = app.querySelector("#leave");
  if (leave) leave.onclick = async () => {
    if (!confirm(`${t("leave.button")}?\n\n${t("leave.body", { group: group.name })}`)) return;
    try {
      await (await getRemote()).leaveGroup();
    } catch (e) {
      console.error(e);
      toast(t("onb.err.network"));
      return;
    }
    startOver();
  };
  const reset = app.querySelector("#reset");
  if (reset) reset.onclick = startOver;
}

/** Back to the first onboarding screen (keeps name and goal as suggestions). */
function startOver() {
  onbDraft.code = "";
  onbDraft.info = null;
  delete state.profile;
  delete state.mode;
  state.reactions = {};
  save();
  onbStep = 0;
  render();
}

// ---------------------------------------------------------------- router

const ROUTES = { today: renderToday, recap: renderRecap, group: renderGroup, invite: renderInvite, history: renderHistory, settings: renderSettings };
const TAB_FOR = { today: "today", recap: "today", group: "group", invite: "group", history: "history", settings: "settings" };
let renderSeq = 0;

async function loadCurrentGroup() {
  if (state.mode === "demo") return buildGroup(state.profile);
  const r = await getRemote();
  const p = state.profile;
  if (!(await r.hasSession()) && p?.name && p?.code) {
    // This browser joined before but its sign-in is gone (cleared storage, expired session):
    // join again silently with the saved name, which takes over the same participant.
    p.participant = await r.join(p.code, p.name, p.goal, p.platform, true);
    save();
  }
  const group = await r.loadGroup();
  if (group?.code && p && p.code !== group.code) { p.code = group.code; save(); }
  return group;
}

/** An invite link (?join=CODE) opened the page. */
async function takeInviteFromUrl() {
  const url = new URL(location.href);
  const code = normalizeCode(url.searchParams.get("join"));
  if (!url.searchParams.has("join")) return;
  url.searchParams.delete("join");
  history.replaceState(null, "", url.pathname + url.search + location.hash);
  if (code.length !== 6) return;
  if (!state.mode || !state.profile || state.mode === "demo") {
    onbDraft.code = code;
    return;
  }
  if (state.profile.code === code) return;
  // Already in another group: offer to switch.
  try {
    const r = await getRemote();
    const info = await r.groupInfo(code);
    if (!info) { toast(t("join.notFound")); return; }
    const current = await r.loadGroup().catch(() => null);
    if (!confirm(`${t("switch.title", { group: info.name })}\n\n${t("switch.body", { current: current?.name || "" })}`)) return;
    const p = state.profile;
    p.participant = await r.join(code, p.name, p.goal, p.platform, false);
    p.code = code;
    save();
    location.hash = "#/group";
  } catch (e) {
    console.error(e);
    toast(e instanceof remote.NameTakenError ? t("join.nameTakenShort") : t("join.err"));
  }
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
    // Signed in but in no group (left, or removed by the owner): start over.
    startOver();
    return;
  }
  ROUTES[name](group);
}

window.addEventListener("hashchange", () => { window.scrollTo(0, 0); render(); });
document.addEventListener("visibilitychange", () => { if (!document.hidden && state.mode === "live") render(); });
takeInviteFromUrl().finally(render);
