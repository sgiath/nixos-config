// Overview: active reviews, failures, the waiting list and discovered repos.

import { h, replace, sectionHead } from "../lib/dom.js";
import { now, tickAll } from "../lib/time.js";
import { api } from "../api.js";
import { pendingKeys } from "../store.js";
import { reviewRow, waitingRow, discoveredRow, stable, syncElapsed } from "./rows.js";

const SECTIONS = [
  { key: "active", index: "01", label: "active", empty: "nothing is being reviewed" },
  { key: "failed", index: "02", label: "failed", empty: "no failed reviews" },
  { key: "waiting", index: "03", label: "waiting", empty: "every candidate is eligible or reviewed" },
  { key: "discovered", index: "04", label: "discovered", empty: "no review requests in unwatched repos" },
];

export const overview = {
  async mount(root) {
    this.sigs = {};
    this.hosts = {};
    replace(root, SECTIONS.map((s) => (this.hosts[s.key] = h("section", { "aria-label": s.label }))));
    await this.refresh();
  },

  async refresh() {
    const settle = (p) => p.catch((err) => ({ error: err.message }));
    const [active, failed, waiting, discovered] = await Promise.all([
      settle(api.reviews({ view: "active" })),
      settle(api.reviews({ view: "failed" })),
      settle(api.waiting()),
      settle(api.discovered()),
    ]);
    const fetchedAt = new Date(now()).toISOString();
    const onAction = () => this.refresh();
    this.renderList(SECTIONS[0], active, (r) => reviewRow(r, { fetchedAt, onAction }), fetchedAt);
    this.renderList(SECTIONS[1], failed, (r) => reviewRow(r, { fetchedAt, onAction }), fetchedAt);
    this.renderList(SECTIONS[2], waiting, waitingRow);
    this.renderList(SECTIONS[3], discovered, discoveredRow);
  },

  // re-render a section only when its data (or a pending action touching it) changed,
  // so an open inline confirm is not reset by the 5 s poll
  renderList(section, data, rowFn, fetchedAt) {
    const host = this.hosts[section.key];
    const sig = JSON.stringify([data.error ? data : stable(data), pendingKeys()]);
    if (this.sigs[section.key] === sig) {
      if (!data.error && fetchedAt) syncElapsed(host, data, fetchedAt);
      return;
    }
    this.sigs[section.key] = sig;
    const rows = data.error
      ? [h("div", { class: "empty accent" }, `! ${data.error}`)]
      : data.length
        ? data.map(rowFn)
        : [h("div", { class: "empty" }, section.empty)];
    replace(host, sectionHead(section.index, section.label, { count: data.error ? null : data.length }), h("div", { class: "rows" }, rows));
    tickAll(host);
  },

  unmount() {},
};
