// Row builders shared by the overview and history lists.

import { h, externalLink } from "../lib/dom.js";
import { fmtClock, fmtAbs } from "../lib/time.js";
import { api } from "../api.js";
import { setPending, isPending, reviewerLabel, splitRepo, mrRef } from "../store.js";
import { stateMark, plainState, confirmButton, pendingChip, chip, threadLink, toast } from "../lib/ui.js";

export const ACTIVE = new Set(["queued", "launching", "running", "limited", "deciding", "posting"]);
// What the service accepts: deciding and posting reviews are past their thread and finish or fail on their own;
// superseded ones are replaced by a newer review.
const CANCELLABLE = new Set(["queued", "launching", "running", "limited"]);
const RETRYABLE = new Set(["failed", "cancelled", "done"]);

export function reviewAction(r, onAction) {
  if (CANCELLABLE.has(r.status)) return cancelAction(r, onAction);
  if (RETRYABLE.has(r.status)) return retryAction(r, onAction);
  return null;
}

export const TICKING = new Set(["launching", "running", "deciding", "posting"]);

export function countsText(counts) {
  const parts = [];
  if (counts.posted) parts.push(`posted ${counts.posted}`);
  if (counts.would_post) parts.push(`would post ${counts.would_post}`);
  if (counts.below) parts.push(`below ${counts.below}`);
  if (counts.already_open) parts.push(`already open ${counts.already_open}`);
  if (counts.already_resolved) parts.push(`already resolved ${counts.already_resolved}`);
  if (counts.settled) parts.push(`settled ${counts.settled}`);
  if (counts.unanchored) parts.push(`unanchored ${counts.unanchored}`);
  if (counts.not_posted) parts.push(`not posted ${counts.not_posted}`);
  return parts.length ? parts.join(" · ") : "no findings";
}

export function headCode(sha) {
  return h("code", { title: sha }, sha ? sha.slice(0, 7) : "–");
}

// elapsed_seconds grows on every poll; it is ticked client-side, so it is left out of the
// change signature and its base is refreshed in place (syncElapsed) instead of re-rendering
export function stable(items) {
  return items.map((r) => (r && typeof r === "object" && "elapsed_seconds" in r ? { ...r, elapsed_seconds: undefined } : r));
}

export function syncElapsed(host, items, fetchedAt) {
  for (const r of items) {
    const el = host.querySelector(`[data-id="${CSS.escape(String(r.id))}"] [data-tick="elapsed"]`);
    if (!el) continue;
    el.dataset.base = String(r.elapsed_seconds ?? 0);
    el.dataset.at = fetchedAt;
  }
}

// every item becomes its own flex item, so the gap separates plain strings too
export function metaLine(items) {
  return h(
    "div",
    { class: "meta" },
    items.flat().map((item) => (item == null || item === false ? null : item instanceof Node ? item : h("span", null, item))),
  );
}

export function cancelAction(r, onAction) {
  const { forge } = splitRepo(r.repo);
  if (isPending(`cancel:${r.id}`, r.status)) return pendingChip("cancelling…");
  return confirmButton({
    label: "cancel",
    question: `stop review ${r.id} and its thread?`,
    confirm: "stop",
    cancel: "keep",
    danger: true,
    focus: `cancel:${r.id}`,
    onConfirm: async () => {
      await api.cancel(r.id);
      setPending(`cancel:${r.id}`, { snapshot: r.status });
      toast(`cancel of ${mrRef(forge, r.number)} queued`);
      onAction?.();
    },
  });
}

export function retryAction(r, onAction) {
  const { forge } = splitRepo(r.repo);
  if (isPending(`retry:${r.id}`)) return pendingChip("queued…");
  return h(
    "button",
    {
      class: "btn small",
      type: "button",
      "data-focus": `retry:${r.id}`,
      onclick: async (e) => {
        e.currentTarget.disabled = true;
        try {
          await api.retry(r.id);
          setPending(`retry:${r.id}`, { ttl: 12000 });
          toast(`new attempt of ${mrRef(forge, r.number)} queued`);
        } catch (err) {
          toast(err.message, "error");
        }
        onAction?.();
      },
    },
    r.status === "failed" ? "retry" : "review again",
  );
}

export function reviewRow(r, { fetchedAt, onAction }) {
  const { forge, path } = splitRepo(r.repo);
  const meta = [
    r.author,
    headCode(r.head_sha),
    reviewerLabel(r.reviewer),
    r.thread_url ? threadLink(r.thread_url) : null,
    r.dry_run ? chip("dry run") : null,
    r.attempt > 1 ? chip(`attempt ${r.attempt}`) : null,
  ];
  if (r.status === "done") meta.push(countsText(r.counts), r.approved ? chip("approved", true) : null, r.settled ? "settled" : null);
  if (ACTIVE.has(r.status)) meta.push(h("span", null, "queued ", h("span", { "data-tick": "rel", "data-at": r.queued_at })));

  const side = [];
  if (TICKING.has(r.status)) {
    side.push(h("span", { class: "time" }, "elapsed ", h("span", { "data-tick": "elapsed", "data-base": r.elapsed_seconds, "data-at": fetchedAt })));
  } else if (r.status === "queued") {
    side.push(h("span", { class: "time" }, "waiting for a slot"));
  } else if (r.status === "limited") {
    side.push(
      h("span", { class: "time" }, "resumes ", h("span", { "data-tick": "until", "data-at": r.limited_until }), h("span", { class: "low" }, ` · ${fmtClock(r.limited_until)}`)),
    );
  } else if (r.finished_at) {
    side.push(h("span", { class: "time", title: fmtAbs(r.finished_at) }, fmtClock(r.finished_at)));
  }

  const actions = [reviewAction(r, onAction), h("a", { class: "low", href: `#/review/${r.id}` }, "detail →")];

  return h(
    "div",
    { class: "row", "data-id": r.id },
    stateMark(r),
    h(
      "div",
      { class: "main" },
      h("div", { class: "repo" }, `${forge} · ${path}`),
      h("div", { class: "title" }, externalLink(r.url, [h("span", { class: "ref" }, mrRef(forge, r.number)), " ", r.title])),
      metaLine(meta),
    ),
    h("div", { class: "side" }, side, h("div", { class: "actions" }, actions)),
    r.error ? h("div", { class: "error" }, r.error) : null,
  );
}

export function waitingRow(w) {
  const { forge, path } = splitRepo(w.repo);
  return h(
    "div",
    { class: "row" },
    plainState("waiting"),
    h(
      "div",
      { class: "main" },
      h("div", { class: "repo" }, `${forge} · ${path}`),
      h("div", { class: "title" }, externalLink(w.url, [h("span", { class: "ref" }, mrRef(forge, w.number)), " ", w.title])),
      metaLine([w.author]),
    ),
    h("div", { class: "side" }, h("span", { class: "reason" }, w.reason)),
  );
}

export function discoveredRow(d) {
  const id = `${d.forge}:${d.path}`;
  return h(
    "div",
    { class: "row" },
    plainState("unwatched"),
    h(
      "div",
      { class: "main" },
      h("div", { class: "repo" }, `${d.forge} · ${d.path}`),
      h("div", { class: "title" }, externalLink(d.url, [h("span", { class: "ref" }, mrRef(d.forge, d.number)), " ", d.title])),
      metaLine(["review requested in a repo that is not watched"]),
    ),
    h("div", { class: "side" }, h("div", { class: "actions" }, h("a", { class: "btn small", href: `#/settings?add=${encodeURIComponent(id)}` }, "add repo →"))),
  );
}

// Edited replies by thread marker: a section re-render (another row changed, a pending action elsewhere) rebuilds
// every row, and must not throw away what sgiath typed.
const drafts = new Map();

// A reply the reviewer found inadequate: its reasoning, the reply it proposes (editable), and the three decisions.
export function decideRow(t, onAction) {
  const { forge } = splitRepo(t.repo);
  const key = { repo: t.repo, number: t.number, marker: t.marker };
  const pendingKey = `thread:${t.marker}`;
  const reply = h("textarea", {
    rows: 4,
    spellcheck: "true",
    "aria-label": "reply to send",
    oninput: (e) => drafts.set(t.marker, e.currentTarget.value),
  });
  reply.value = drafts.get(t.marker) ?? t.proposed_reply ?? "";
  const act = (name, label, done, text) =>
    h(
      "button",
      {
        class: "btn small",
        type: "button",
        onclick: async (e) => {
          e.currentTarget.disabled = true;
          try {
            await api.threadAction(name, key, text ? reply.value : undefined);
            drafts.delete(t.marker);
            setPending(pendingKey, { ttl: 15000 });
            toast(`${done} on ${mrRef(forge, t.number)}`);
          } catch (err) {
            toast(err.message, "error");
          }
          onAction?.();
        },
      },
      label,
    );
  const actions = isPending(pendingKey)
    ? [pendingChip("queued…")]
    : [
        act("reply", "send reply", "reply queued", true),
        act("accept", "accept answer", "accept queued", false),
        act("dismiss", "keep open", "kept open", false),
      ];
  return h(
    "div",
    { class: "row", "data-id": t.marker },
    h("div", { class: "state accent" }, "reply disputed"),
    h(
      "div",
      { class: "main" },
      h("div", { class: "repo" }, t.repo),
      h("div", { class: "title" }, h("span", { class: "ref" }, mrRef(forge, t.number)), `${t.finding_id} · ${t.title || ""}`),
      h("p", { class: "reason" }, t.reasoning || ""),
      reply,
      metaLine([
        t.score != null ? `score ${t.score}` : null,
        t.comment_url ? externalLink(t.comment_url, "thread ↗", "low") : null,
        t.review_id != null ? h("a", { class: "low", href: `#/review/${t.review_id}` }, `review #${t.review_id}`) : null,
      ]),
    ),
    h("div", { class: "actions" }, actions),
  );
}
