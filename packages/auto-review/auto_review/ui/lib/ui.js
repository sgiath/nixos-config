// Small shared widgets: toasts, the inline two-step confirm, status marks and chips.

import { h } from "./dom.js";

export function toast(message, kind = "info", ms = 4500) {
  const host = document.getElementById("toasts");
  const el = h("div", { class: `toast ${kind}` }, message);
  host.append(el);
  setTimeout(() => el.remove(), ms);
  return el;
}

// A button that turns into "question [confirm] [cancel]" in place. Escape backs out.
// The idle button stays quiet; only the armed confirm step wears the accent (danger) or not.
// onConfirm may reject; the message is shown as an error toast and the button returns.
export function confirmButton({ label, question, confirm = "confirm", cancel = "keep", danger = true, focus, onConfirm }) {
  const host = h("span", { class: "confirm" });
  const onKey = (e) => {
    if (e.key !== "Escape") return;
    e.stopPropagation();
    idle();
    host.querySelector("button")?.focus();
  };
  const idle = () => {
    host.removeEventListener("keydown", onKey);
    host.replaceChildren(h("button", { class: "btn small", type: "button", "data-focus": focus, onclick: arm }, label));
  };
  const arm = () => {
    const yes = h("button", { class: `btn small${danger ? " danger" : ""}`, type: "button", "data-focus": focus, onclick: run }, confirm);
    const no = h("button", { class: "btn small text", type: "button", onclick: idle }, cancel);
    host.replaceChildren(h("span", { class: "question" }, question), yes, no);
    host.addEventListener("keydown", onKey);
    yes.focus();
  };
  const run = async (e) => {
    const btn = e.currentTarget;
    btn.disabled = true;
    btn.textContent = "…";
    try {
      await onConfirm();
    } catch (err) {
      toast(err.message, "error");
    }
    if (host.isConnected) idle();
  };
  idle();
  return host;
}

// status → [mark classes, label, state classes, glyph]
const STATES = {
  queued: ["mark", "queued", "dim"],
  launching: ["mark pulse", "launching", ""],
  running: ["mark accent pulse", "running", ""],
  limited: ["mark half", "limited", ""],
  deciding: ["mark hi pulse", "deciding", ""],
  posting: ["mark hi pulse", "posting", ""],
  failed: ["glyph", "failed", "accent", "×"],
  cancelled: ["mark dim", "cancelled", "dim"],
  superseded: ["mark dim", "superseded", "dim"],
};

const OUTCOMES = {
  clean: ["mark", "clean", ""],
  findings: ["mark filled", "findings", ""],
  needs_attention: ["glyph", "attention", "accent", "!"],
};

export function stateMark(review) {
  const spec =
    review.status === "done"
      ? OUTCOMES[review.outcome] || ["mark filled", "done", ""]
      : STATES[review.status] || ["mark", review.status, ""];
  const [markCls, label, cls, glyph] = spec;
  return h(
    "span",
    { class: `state ${cls}`, title: review.status === "done" ? `done · ${review.outcome ?? "–"}` : review.status },
    glyph ? h("span", { class: "glyph", "aria-hidden": "true" }, glyph) : h("span", { class: markCls, "aria-hidden": "true" }),
    label,
  );
}

export function plainState(label, cls = "dim") {
  return h("span", { class: `state ${cls}` }, h("span", { class: "mark dim", "aria-hidden": "true" }), label);
}

export function pendingChip(text) {
  return h("span", { class: "chip pending" }, text);
}

export function chip(text, on = false) {
  return h("span", { class: `chip${on ? " on" : ""}` }, text);
}

// t3-thread:// links open in the T3 app through its protocol handler
export function threadLink(url) {
  return h("a", { class: "low", href: url, title: url }, "thread ↗");
}

const FINDING_STATES = {
  posted: ["posted", true],
  would_post: ["would post", true],
  below: ["below threshold", false],
  already_open: ["already open", false],
  unanchored: ["unanchored", false],
  not_posted: ["not posted", false],
};

export function findingChip(state) {
  const [label, on] = FINDING_STATES[state] || [state, false];
  return chip(label, on);
}
