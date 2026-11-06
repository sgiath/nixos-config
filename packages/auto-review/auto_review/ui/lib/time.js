// Time formatting. The clock is aligned to the server's `now` so relative times and
// the live elapsed counters do not drift with the browser clock.

let offset = 0;

export function syncClock(isoNow) {
  const t = Date.parse(isoNow);
  if (!Number.isNaN(t)) offset = t - Date.now();
}

export function now() {
  return Date.now() + offset;
}

export function parse(iso) {
  return iso ? Date.parse(iso) : NaN;
}

const pad = (n) => String(n).padStart(2, "0");

export function fmtAbs(iso) {
  const t = parse(iso);
  if (Number.isNaN(t)) return "–";
  const d = new Date(t);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// "21:14" today, "nov 04 21:14" otherwise
export function fmtClock(iso) {
  const t = parse(iso);
  if (Number.isNaN(t)) return "–";
  const d = new Date(t);
  const ref = new Date(now());
  const hm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  if (d.toDateString() === ref.toDateString()) return hm;
  const month = d.toLocaleString("en", { month: "short" }).toLowerCase();
  return `${month} ${pad(d.getDate())} ${hm}`;
}

export function fmtDur(seconds) {
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${pad(s % 60)}s`;
  const hours = Math.floor(m / 60);
  if (hours < 48) return `${hours}h ${pad(m % 60)}m`;
  return `${Math.floor(hours / 24)}d ${pad(hours % 24)}h`;
}

// "12s ago" / "in 3h 12m"; coarse past spans so a list does not flicker
export function fmtRel(iso, ref = now()) {
  const t = parse(iso);
  if (Number.isNaN(t)) return "–";
  const diff = Math.round((t - ref) / 1000);
  const abs = Math.abs(diff);
  let span;
  if (abs < 60) span = `${abs}s`;
  else if (abs < 3600) span = `${Math.floor(abs / 60)}m`;
  else if (abs < 86400) span = `${Math.floor(abs / 3600)}h ${pad(Math.floor((abs % 3600) / 60))}m`;
  else span = `${Math.floor(abs / 86400)}d ${Math.floor((abs % 86400) / 3600)}h`;
  return diff < 0 ? `${span} ago` : `in ${span}`;
}

// Elements marked data-tick are re-rendered every second by app.js:
//   data-tick="elapsed" data-base="<seconds at fetch>" data-at="<server now at fetch>"
//   data-tick="rel"     data-at="<iso>"            → "3m ago" / "in 48s"
//   data-tick="until"   data-at="<iso>"            → "in 3h 12m" / "now"
export function tickAll(root = document) {
  const ref = now();
  for (const el of root.querySelectorAll("[data-tick]")) {
    const { tick, at, base } = el.dataset;
    let text;
    if (tick === "elapsed") text = fmtDur(Number(base || 0) + (ref - parse(at)) / 1000);
    else if (tick === "rel") text = fmtRel(at, ref);
    else if (tick === "until") text = parse(at) <= ref ? "now" : fmtRel(at, ref);
    else continue;
    if (el.textContent !== text) el.textContent = text;
  }
}
