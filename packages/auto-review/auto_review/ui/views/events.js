// Service event log, newest first.

import { h, replace, sectionHead } from "../lib/dom.js";
import { fmtAbs } from "../lib/time.js";
import { api } from "../api.js";

export function eventRow(e, { showReview = true } = {}) {
  return h(
    "div",
    { class: `event ${e.level || "info"}` },
    h("span", { class: "at", title: e.at }, fmtAbs(e.at)),
    h("span", { class: "level" }, e.level || "info"),
    h("span", { class: "msg" }, showReview && e.review_id != null ? h("a", { class: "low", href: `#/review/${e.review_id}` }, `#${e.review_id}`) : null, e.message),
  );
}

export const events = {
  async mount(root) {
    this.sig = null;
    this.host = h("div");
    replace(root, sectionHead("01", "events"), this.host);
    await this.refresh();
  },

  async refresh() {
    let items;
    try {
      items = await api.events(100);
    } catch (err) {
      replace(this.host, h("div", { class: "empty accent" }, `! ${err.message}`));
      this.sig = null;
      return;
    }
    const sig = JSON.stringify(items);
    if (sig === this.sig) return;
    this.sig = sig;
    replace(this.host, items.length ? items.map((e) => eventRow(e)) : h("div", { class: "empty" }, "no events yet"));
  },

  unmount() {},
};
