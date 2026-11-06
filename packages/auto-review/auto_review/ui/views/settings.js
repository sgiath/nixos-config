// Settings: global service values, quiet hours and timezone, notifications, the note
// template and the watched repos. Every field shows whether it is a nix default or a ui
// override; "reset to nix" sends null.

import { h, replace, sectionHead } from "../lib/dom.js";
import { api } from "../api.js";
import { store } from "../store.js";
import { Form } from "../lib/form.js";
import { ReviewerField } from "../lib/reviewer.js";
import { templateEditor } from "./template.js";
import { reposSection } from "./repos.js";

function timezoneList() {
  let zones = [];
  try {
    zones = Intl.supportedValuesOf("timeZone");
  } catch {
    zones = ["Europe/Prague", "UTC"];
  }
  return h("datalist", { id: "tz-list" }, zones.map((z) => h("option", { value: z })));
}

export const settings = {
  async mount(root, params) {
    const [current, catalog] = await Promise.all([api.settings(), store.catalog.length ? store.catalog : api.catalog()]);
    store.catalog = catalog;
    store.settings = current;

    const onSaved = (data) => {
      store.settings = data;
      this.sync(data);
    };
    const form = (this.form = new Form({ onSaved }));
    const reviewer = new ReviewerField(form, { optional: false });
    this.template = templateEditor({ onSaved });
    this.repos = reposSection({ onSaved });

    replace(
      root,
      sectionHead("01", "service"),
      h(
        "div",
        { class: "form" },
        h(
          "div",
          { class: "form-grid" },
          form.field({ path: "paused", label: "paused", type: "checkbox", help: "no launches, no posts; running threads are still monitored" }),
          form.field({ path: "dry_run", label: "dry run", type: "checkbox", help: "review, but write nothing to gitlab or github; post anyway still posts" }),
          form.field({ path: "auto_settle", label: "auto settle", type: "checkbox", help: "settle the t3 thread after posting, or when nothing is posted" }),
          form.field({ path: "threshold", label: "threshold", type: "number", min: 1, help: "minimum frequency × severity that gets posted" }),
          form.field({ path: "poll_interval_seconds", label: "poll interval", type: "number", min: 15, help: "seconds between polls, at least 15" }),
          form.field({ path: "max_concurrent", label: "max concurrent", type: "number", min: 1, help: "reviews running at once" }),
          form.field({
            path: "max_launches_per_day",
            label: "daily launch cap",
            type: "number",
            min: 1,
            nullable: true,
            placeholder: "unlimited",
            help: "launches per local day; empty is unlimited",
          }),
          form.field({ path: "review_timeout_minutes", label: "review timeout", type: "number", min: 1, help: "minutes of active running time before a review fails; limited time does not count" }),
          reviewer.el,
        ),
        form.errorBox,
      ),
      sectionHead("02", "quiet hours"),
      h(
        "div",
        { class: "form" },
        h(
          "div",
          { class: "form-grid" },
          form.field({ path: "quiet_hours.enabled", label: "quiet hours", type: "checkbox", help: "no launches or posts inside the window" }),
          form.field({ path: "quiet_hours.start", label: "start", type: "time", help: "window start, local time" }),
          form.field({ path: "quiet_hours.end", label: "end", type: "time", help: "window end; may cross midnight" }),
          form.field({ path: "timezone", label: "timezone", type: "text", list: "tz-list", placeholder: "Europe/Prague", help: "iana zone for quiet hours and the daily launch cap" }),
        ),
        timezoneList(),
      ),
      sectionHead("03", "notifications"),
      h(
        "div",
        { class: "form" },
        h(
          "div",
          { class: "form-grid" },
          form.field({ path: "notify.desktop", label: "desktop", type: "checkbox", help: "desktop notification for failures and needs-attention reviews" }),
          form.field({ path: "notify.ntfy_url", label: "ntfy", type: "text", nullable: true, placeholder: "off", help: "https:// ntfy topic url; empty turns it off" }),
        ),
      ),
      this.template.el,
      this.repos.el,
    );
    this.sync(current);

    const add = params.get("add");
    if (add) {
      const i = add.indexOf(":");
      this.repos.prefill(i > 0 ? add.slice(0, i) : "", i > 0 ? add.slice(i + 1) : add);
    }
  },

  sync(data) {
    this.form.apply(data);
    this.template.apply(data);
    this.repos.apply(data);
  },

  async refresh() {
    const data = await api.settings();
    store.settings = data;
    this.sync(data);
  },

  unmount() {},
};
