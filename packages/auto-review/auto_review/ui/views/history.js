// History: done, cancelled and superseded reviews, newest first, filtered by repo, paged.

import { h, replace, sectionHead } from "../lib/dom.js";
import { now, tickAll } from "../lib/time.js";
import { api } from "../api.js";
import { store, pendingKeys, splitRepo } from "../store.js";
import { reviewRow, stable, syncElapsed } from "./rows.js";

const PAGE = 50;

export const history = {
  async mount(root) {
    this.sig = null;
    this.repo = "";
    this.limit = PAGE;
    this.host = h("div");
    this.select = h("select", {
      "aria-label": "filter by repo",
      style: "width: auto; max-width: 100%",
      onchange: () => {
        this.repo = this.select.value;
        this.limit = PAGE;
        this.sig = null;
        this.refresh();
      },
    });
    this.fillSelect();
    replace(root, sectionHead("01", "history", { tools: this.select }), this.host);
    await this.refresh();
  },

  fillSelect() {
    const ids = Object.keys(store.settings?.effective?.repos || {});
    replace(this.select, h("option", { value: "" }, "all repos"), ids.map((id) => h("option", { value: id }, splitRepo(id).path)));
    this.select.value = this.repo;
  },

  async refresh() {
    const params = { view: "history", limit: this.limit };
    if (this.repo) params.repo = this.repo;
    let items;
    try {
      items = await api.reviews(params);
    } catch (err) {
      replace(this.host, h("div", { class: "empty accent" }, `! ${err.message}`));
      this.sig = null;
      return;
    }
    const fetchedAt = new Date(now()).toISOString();
    const sig = JSON.stringify([stable(items), pendingKeys(), this.limit]);
    if (sig === this.sig) {
      syncElapsed(this.host, items, fetchedAt);
      return;
    }
    this.sig = sig;
    const onAction = () => this.refresh();
    const rows = items.length ? items.map((r) => reviewRow(r, { fetchedAt, onAction })) : [h("div", { class: "empty" }, "no finished reviews yet")];
    const more =
      items.length >= this.limit
        ? h(
            "div",
            { class: "more" },
            h(
              "button",
              {
                class: "btn small",
                type: "button",
                "data-focus": "history-more",
                onclick: () => {
                  this.limit += PAGE;
                  this.refresh();
                },
              },
              "load more",
            ),
            `showing ${items.length}`,
          )
        : items.length
          ? h("div", { class: "more" }, `${items.length} reviews`)
          : null;
    replace(this.host, h("div", { class: "rows" }, rows), more);
    tickAll(this.host);
  },

  unmount() {},
};
