// Review detail: header, summary, findings (with "post anyway"), attention items, events.

import { h, replace, sectionHead, externalLink } from "../lib/dom.js";
import { fmtAbs, fmtDur, fmtClock, now, tickAll } from "../lib/time.js";
import { renderMarkdown } from "../lib/markdown.js";
import { api } from "../api.js";
import { store, setPending, isPending, pendingKeys, prunePending, reviewerLabel, splitRepo, mrRef, repoThreshold } from "../store.js";
import { stateMark, confirmButton, pendingChip, chip, threadLink, findingChip, toast } from "../lib/ui.js";
import { ACTIVE, TICKING, reviewAction, headCode, stable } from "./rows.js";
import { eventRow } from "./events.js";

export const review = {
  async mount(root, params, [id]) {
    this.id = id;
    this.root = root;
    this.sig = null;
    replace(root, h("p", { class: "empty" }, "loading…"));
    await this.refresh();
  },

  async refresh() {
    let r;
    try {
      r = await api.review(this.id);
    } catch (err) {
      if (!this.sig) replace(this.root, h("p", { class: "empty accent" }, `! ${err.message}`), h("a", { class: "backlink", href: "#/" }, "← overview"));
      return;
    }
    prunePending();
    const sig = JSON.stringify([stable([r]), pendingKeys()]);
    if (sig === this.sig) {
      const el = this.root.querySelector('[data-tick="elapsed"]');
      if (el) {
        el.dataset.base = String(r.elapsed_seconds ?? 0);
        el.dataset.at = new Date(now()).toISOString();
      }
      return;
    }
    this.sig = sig;
    this.render(r);
  },

  render(r) {
    const { forge, path } = splitRepo(r.repo);
    const ref = mrRef(forge, r.number);
    const fetchedAt = new Date(now()).toISOString();
    const onAction = () => this.refresh();
    const threshold = repoThreshold(r.repo);

    const kv = [];
    const row = (k, v, cls) => kv.push(h("dt", null, k), h("dd", { class: cls }, v));
    row("status", stateMark(r));
    row("author", r.author);
    row("head", [headCode(r.head_sha), " on ", r.target, " · base ", headCode(r.base_sha)]);
    row("reviewer", reviewerLabel(r.reviewer));
    row("thread", r.thread_url ? threadLink(r.thread_url) : "not launched");
    row("attempt", String(r.attempt));
    row("queued", fmtAbs(r.queued_at));
    if (r.started_at) row("started", fmtAbs(r.started_at));
    if (r.finished_at) row("finished", fmtAbs(r.finished_at));
    row(
      "elapsed",
      TICKING.has(r.status) ? h("span", { "data-tick": "elapsed", "data-base": r.elapsed_seconds, "data-at": fetchedAt }) : fmtDur(r.elapsed_seconds),
    );
    if (r.limited_until) row("limited", ["until ", fmtClock(r.limited_until), " (", h("span", { "data-tick": "until", "data-at": r.limited_until }), ")"]);
    row("flags", [r.dry_run ? chip("dry run") : null, r.approved ? chip("approved", true) : null, r.settled ? chip("settled") : null, !r.dry_run && !r.approved && !r.settled ? "–" : null]);

    const actions = [reviewAction(r, onAction)];

    const findings = r.findings || [];
    const table = findings.length
      ? h(
          "div",
          { class: "table-wrap" },
          h(
            "table",
            null,
            h("thead", null, h("tr", null, h("th", null, "id"), h("th", null, "score"), h("th", null, "finding"), h("th", null, "location"), h("th", null, "state"), h("th", null, ""))),
            h("tbody", null, findings.map((f) => this.findingRow(r, f, ref, onAction))),
          ),
        )
      : h("div", { class: "empty" }, ACTIVE.has(r.status) ? "no verdict yet" : "no findings");

    const attention = [];
    if (r.injection_attempts?.length) {
      attention.push(h("h4", { class: "caption accent" }, "prompt injection attempts"), h("ul", { class: "list accent" }, r.injection_attempts.map((x) => h("li", null, fmtItem(x)))));
    }
    if (r.not_reviewed?.length) {
      attention.push(h("h4", { class: "caption" }, "not reviewed"), h("ul", { class: "list" }, r.not_reviewed.map((x) => h("li", null, fmtItem(x)))));
    }

    replace(
      this.root,
      h("p", { style: "margin-top: 28px" }, h("a", { class: "backlink", href: r.status === "done" || r.status === "cancelled" || r.status === "superseded" ? "#/history" : "#/" }, `← ${r.status === "done" || r.status === "cancelled" || r.status === "superseded" ? "history" : "overview"}`)),
      h(
        "div",
        { class: "detail-head" },
        h("span", { class: "caption" }, `${forge} · ${path} · review ${r.id}`),
        h("h1", null, externalLink(r.url, [h("span", { class: "ref" }, ref), " ", r.title])),
      ),
      h(
        "div",
        { class: "cols2", style: "margin-top: 24px" },
        h("dl", { class: "kv" }, kv),
        h("div", { style: "display: grid; gap: 12px" }, h("div", { class: "actions" }, actions), r.error ? h("p", { class: "accent", style: "font-size: 12.5px; overflow-wrap: anywhere" }, r.error) : null),
      ),
      sectionHead("01", "summary"),
      r.summary ? h("div", { class: "prose", html: renderMarkdown(r.summary) }) : h("div", { class: "empty" }, ACTIVE.has(r.status) ? "the agent has not written its verdict yet" : "no summary"),
      sectionHead("02", "findings", { count: findings.length, tools: threshold != null ? h("span", { class: "caption" }, `current threshold ${threshold}`) : null }),
      table,
      attention.length ? [sectionHead("03", "attention"), h("div", { style: "display: grid; gap: 10px" }, attention)] : null,
      sectionHead(attention.length ? "04" : "03", "events", { count: r.events?.length }),
      r.events?.length ? h("div", null, r.events.map((e) => eventRow(e, { showReview: false }))) : h("div", { class: "empty" }, "no events"),
    );
    tickAll(this.root);
  },

  findingRow(r, f, ref, onAction) {
    const hit = f.state === "posted" || f.state === "would_post";
    const faded = f.state === "below" || f.state === "not_posted";
    const actions = [];
    if (f.url) actions.push(externalLink(f.url, "comment ↗", "low"));
    if (f.state === "below" || f.state === "would_post" || f.state === "not_posted") {
      const key = `post:${r.id}:${f.finding_id}`;
      if (isPending(key, f.state)) actions.push(pendingChip("posting…"));
      else {
        actions.push(
          confirmButton({
            label: "post anyway",
            question: `post ${f.finding_id} on ${ref} in your name?`,
            confirm: "post",
            cancel: "keep",
            danger: true,
            focus: key,
            onConfirm: async () => {
              await api.postFinding(r.id, f.finding_id);
              setPending(key, { snapshot: f.state });
              toast(`${f.finding_id} queued for posting`);
              onAction();
            },
          }),
        );
      }
    }
    return h(
      "tr",
      { class: hit ? "hit" : faded ? "faded" : "" },
      h("td", { class: "num" }, f.finding_id),
      h("td", { class: "num" }, h("span", { class: "hi" }, String(f.score)), h("span", { class: "low" }, ` = ${f.frequency}×${f.severity}`)),
      h(
        "td",
        { class: "ftitle" },
        h(
          "details",
          null,
          h("summary", null, f.title),
          h("div", { class: "body prose", html: renderMarkdown(f.body || "_no body_") }),
          f.reasoning ? h("p", { class: "reasoning" }, "reasoning · ", f.reasoning) : null,
        ),
      ),
      h("td", null, h("span", { class: "loc" }, `${f.file}:${f.line}${f.side === "old" ? " (old side)" : ""}`)),
      h("td", null, findingChip(f.state)),
      h("td", null, h("div", { class: "actions" }, actions)),
    );
  },

  unmount() {},
};

function fmtItem(x) {
  if (x == null) return "–";
  if (typeof x === "string") return x;
  return Object.entries(x)
    .map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : v}`)
    .join(" · ");
}
