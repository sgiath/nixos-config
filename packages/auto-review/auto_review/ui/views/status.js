// The readout strip under the header: mode, budget, quiet hours, provider limits, poll.

import { h, replace } from "../lib/dom.js";
import { fmtClock, tickAll, parse, now } from "../lib/time.js";
import { api } from "../api.js";
import { store, setPending, isPending, providerLabel } from "../store.js";
import { toast } from "../lib/ui.js";

function readout(label, value, sub, controls, cls = "") {
  return h(
    "div",
    { class: "readout" },
    h("span", { class: "caption" }, label),
    h("span", { class: `value ${cls}` }, value),
    sub ? h("span", { class: "sub" }, sub) : null,
    controls ? h("div", { class: "controls" }, controls) : null,
  );
}

export function renderStatus(container, status, { onChange }) {
  const settings = store.settings?.effective;
  const { quiet: q, budget: b, poll: p } = status;
  const pollPending = !p.running && isPending("poll", p.last_at);
  const overdue = !p.running && p.next_at && parse(p.next_at) <= now();
  // `now` changes every fetch; relative times tick client-side, so it stays out of the signature
  const sig = JSON.stringify([{ ...status, now: undefined }, settings?.quiet_hours, settings?.timezone, pollPending, overdue]);
  if (container.dataset.sig === sig) return;
  container.dataset.sig = sig;

  const toggle = (label, pressed, key) =>
    h(
      "button",
      {
        class: "toggle",
        type: "button",
        "aria-pressed": String(pressed),
        "data-focus": `toggle:${key}`,
        onclick: async (e) => {
          const btn = e.currentTarget;
          btn.disabled = true;
          try {
            store.settings = await api.patchSettings({ [key]: !pressed });
            await onChange();
          } catch (err) {
            toast(err.message, "error");
            btn.disabled = false;
          }
        },
      },
      label,
    );

  const mode = status.paused ? (status.dry_run ? "paused · dry run" : "paused") : status.dry_run ? "dry run" : "live";
  const modeSub = status.paused ? "no launches, no posts" : status.dry_run ? "reviews run, nothing is written" : "launching and posting";

  const quietValue = !q.enabled ? "off" : settings ? `${settings.quiet_hours.start}–${settings.quiet_hours.end}` : "on";
  const quietSub = q.active
    ? `active · until ${fmtClock(q.until)}`
    : settings
      ? `${settings.timezone}${q.enabled ? " · inactive" : ""}`
      : null;

  const limits = status.limits || [];
  const limitValue = limits.length ? limits.map((l) => h("div", null, `${providerLabel(l.provider)} until ${fmtClock(l.until)}`)) : "none";
  const limitSub = limits.map((l) => l.reason).filter(Boolean).join(" · ") || null;

  const pollValue = p.running ? "polling…" : p.last_at ? ["last ", h("span", { "data-tick": "rel", "data-at": p.last_at })] : "never";
  const pollSub = p.running ? null : overdue ? "next poll is due" : p.next_at ? ["next ", h("span", { "data-tick": "rel", "data-at": p.next_at })] : null;
  const pollBtn = h(
    "button",
    {
      class: "toggle",
      type: "button",
      "data-focus": "poll-now",
      disabled: pollPending || p.running,
      onclick: async (e) => {
        e.currentTarget.disabled = true;
        try {
          await api.pollNow();
          setPending("poll", { snapshot: p.last_at });
          toast("poll queued");
        } catch (err) {
          toast(err.message, "error");
        }
        await onChange();
      },
    },
    pollPending ? "queued…" : "poll now",
  );

  replace(
    container,
    readout("mode", mode, modeSub, [toggle("paused", status.paused, "paused"), toggle("dry run", status.dry_run, "dry_run")], status.paused ? "accent" : ""),
    readout("budget", `${b.running} / ${b.max_concurrent} running`, `launched today ${b.launched_today} / ${b.max_launches_per_day ?? "∞"}`),
    readout("quiet hours", quietValue, quietSub, null, q.active ? "accent" : ""),
    readout("limits", limitValue, limitSub),
    readout("poll", pollValue, pollSub, [pollBtn]),
    p.last_error ? h("div", { class: "poll-error" }, `! last poll failed · ${p.last_error}`) : null,
  );
  tickAll(container);
}

export function renderStatusError(container, err) {
  const sig = `error:${err.message}`;
  if (container.dataset.sig === sig) return;
  container.dataset.sig = sig;
  replace(container, readout("service", "unreachable", `${err.message} · retrying every 5 s`, null, "accent"));
}
