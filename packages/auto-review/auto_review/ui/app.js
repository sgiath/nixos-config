// Entry point: hash router, 5 s refresh while the tab is visible, 1 s clock ticks.

import { h } from "./lib/dom.js";
import { syncClock, tickAll } from "./lib/time.js";
import { api } from "./api.js";
import { store, prunePending } from "./store.js";
import { toast } from "./lib/ui.js";
import { renderStatus, renderStatusError } from "./views/status.js";
import { overview } from "./views/overview.js";
import { history } from "./views/history.js";
import { review } from "./views/review.js";
import { settings } from "./views/settings.js";
import { events } from "./views/events.js";

const ROUTES = [
  { re: /^\/?$/, view: overview, nav: "overview", title: "overview" },
  { re: /^\/history\/?$/, view: history, nav: "history", title: "history" },
  { re: /^\/review\/(\d+)\/?$/, view: review, nav: null, title: "review" },
  { re: /^\/settings\/?$/, view: settings, nav: "settings", title: "settings" },
  { re: /^\/events\/?$/, view: events, nav: "events", title: "events" },
];

const REFRESH_MS = 5000;
const main = document.getElementById("main");
const statusEl = document.getElementById("status");
let current = null;
let timer = null;
let inflight = null;

function parseHash() {
  const raw = location.hash.replace(/^#/, "") || "/";
  const i = raw.indexOf("?");
  return { path: i < 0 ? raw : raw.slice(0, i), params: new URLSearchParams(i < 0 ? "" : raw.slice(i + 1)) };
}

function setNav(name) {
  for (const a of document.querySelectorAll(".nav-item[data-view]")) {
    if (a.dataset.view === name) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  }
}

async function route() {
  const { path, params } = parseHash();
  current?.unmount?.();
  current = null;
  const match = ROUTES.map((r) => ({ r, m: r.re.exec(path) })).find((x) => x.m);
  if (!match) {
    setNav(null);
    document.title = "auto-review";
    main.replaceChildren(h("p", { class: "empty" }, "no such view"), h("p", null, h("a", { class: "backlink", href: "#/" }, "← overview")));
    return;
  }
  setNav(match.r.nav);
  document.title = `auto-review · ${match.r.title}`;
  current = match.r.view;
  window.scrollTo(0, 0); // before mount: a view may scroll to a target of its own (settings?add=)
  try {
    await current.mount(main, params, match.m.slice(1));
  } catch (err) {
    main.replaceChildren(h("p", { class: "empty accent" }, `! ${err.message}`));
  }
}

function renderIdentities(status) {
  const ids = status.identities || {};
  const parts = Object.entries(ids)
    .filter(([, v]) => v)
    .map(([k, v]) => `${k} ${v}`);
  document.getElementById("identities").textContent = parts.join(" · ") || "local review service";
}

async function doRefresh() {
  prunePending();
  try {
    const status = await api.status();
    syncClock(status.now);
    store.status = status;
    document.documentElement.dataset.paused = String(!!status.paused);
    renderIdentities(status);
    renderStatus(statusEl, status, { onChange: refreshAll });
  } catch (err) {
    renderStatusError(statusEl, err);
  }
  try {
    await current?.refresh?.();
  } catch (err) {
    console.error(err);
  }
}

// one refresh at a time; callers that need a fresh pass after an action await this
export async function refreshAll() {
  if (inflight) {
    await inflight;
  }
  inflight = doRefresh().finally(() => {
    inflight = null;
  });
  return inflight;
}

function schedule() {
  clearTimeout(timer);
  if (document.visibilityState !== "visible") return;
  timer = setTimeout(async () => {
    await refreshAll();
    schedule();
  }, REFRESH_MS);
}

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") refreshAll();
  schedule();
});

window.addEventListener("hashchange", async () => {
  await route();
  await refreshAll();
  schedule();
});

setInterval(() => tickAll(), 1000);

(async () => {
  try {
    const [catalog, current] = await Promise.all([api.catalog(), api.settings()]);
    store.catalog = catalog;
    store.settings = current;
  } catch (err) {
    toast(err.message, "error");
  }
  await route();
  await refreshAll();
  schedule();
})();
