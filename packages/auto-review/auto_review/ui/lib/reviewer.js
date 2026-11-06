// Reviewer picker: provider instance, model and effort from GET /api/catalog, saved as one
// object so the three always agree. Per repo it is optional (null = the global reviewer).

import { h } from "./dom.js";
import { getPath, setPath, fmtValue, flashSource } from "./form.js";
import { store } from "../store.js";

export class ReviewerField {
  constructor(form, { optional = false, label = "reviewer", span2 = true } = {}) {
    this.form = form;
    this.optional = optional;
    this.segs = form.segs("reviewer");
    this.key = this.segs.join(".");
    this.provider = h("select", { "aria-label": "provider instance", onchange: () => this.onProvider() });
    this.model = h("select", { "aria-label": "model", onchange: () => this.onModel() });
    this.effort = h("select", { "aria-label": "effort", onchange: () => this.save(this.current()) });
    this.selects = h("div", { class: "inline-fields" }, this.provider, h("span", { class: "sep" }, "/"), this.model, h("span", { class: "sep" }, "/"), this.effort);
    this.use = optional ? h("input", { type: "checkbox", onchange: () => this.toggle() }) : null;
    this.source = h("span", { class: "source" });
    this.resetBtn = h("button", { class: "btn text small reset", type: "button", hidden: true, onclick: () => this.save(null) }, "reset to nix");
    this.errorEl = h("p", { class: "error" });
    this.el = h(
      "div",
      { class: `field${span2 ? " span2" : ""}`, "data-key": this.key },
      h("div", { class: "field-head" }, h("span", { class: "name" }, label), this.source, this.resetBtn),
      optional ? h("label", { class: "check" }, this.use, h("span", null, "repo-specific reviewer instead of the global one")) : null,
      this.selects,
      h("p", { class: "help" }, "provider instance, model and effort the review thread is launched with"),
      this.errorEl,
    );
    form.register(this);
  }

  current() {
    return { provider: this.provider.value, model: this.model.value, effort: this.effort.value };
  }

  fillOptions(select, options, value) {
    select.replaceChildren(...options.map((o) => h("option", { value: o.value }, o.label)));
    select.value = options.some((o) => o.value === value) ? value : options[0]?.value ?? "";
  }

  fill(reviewer) {
    const catalog = store.catalog;
    const providers = catalog.map((p) => ({ value: p.provider, label: p.label || p.provider }));
    if (reviewer?.provider && !catalog.some((p) => p.provider === reviewer.provider)) {
      providers.push({ value: reviewer.provider, label: `${reviewer.provider} (not in catalog)` });
    }
    this.fillOptions(this.provider, providers, reviewer?.provider);
    const provider = catalog.find((p) => p.provider === this.provider.value);
    const models = (provider?.models || []).map((m) => ({ value: m.id, label: m.label || m.id }));
    if (reviewer?.model && !models.some((m) => m.value === reviewer.model)) models.push({ value: reviewer.model, label: reviewer.model });
    this.fillOptions(this.model, models, reviewer?.model);
    const model = provider?.models?.find((m) => m.id === this.model.value);
    const efforts = (model?.efforts || [reviewer?.effort].filter(Boolean)).map((e) => ({ value: e, label: e }));
    this.fillOptions(this.effort, efforts, reviewer?.effort);
  }

  onProvider() {
    this.fill({ provider: this.provider.value, effort: this.effort.value });
    this.save(this.current());
  }

  onModel() {
    this.fill({ provider: this.provider.value, model: this.model.value, effort: this.effort.value });
    this.save(this.current());
  }

  toggle() {
    if (this.use.checked) this.save({ ...this.form.settings.effective.reviewer });
    else this.save(null);
  }

  async save(reviewer) {
    try {
      await this.form.save(setPath({}, this.segs, reviewer), this);
    } catch {
      /* shown by the form */
    }
    this.apply();
  }

  apply() {
    const s = this.form.settings;
    if (!s) return;
    const effective = getPath(s.effective, this.segs);
    const ui = this.form.uiRepo();
    const overridden = !ui && getPath(s.overrides, this.segs) !== undefined;
    this.el.classList.toggle("overridden", overridden);
    this.sourceText = ui ? "ui" : overridden ? "ui override" : "nix";
    if (!this.source.classList.contains("saved")) this.source.textContent = this.sourceText;
    this.resetBtn.hidden = !overridden;
    this.resetBtn.title = overridden ? `nix: ${fmtValue(getPath(s.defaults, this.segs))}` : "";
    if (this.optional) {
      this.use.checked = !!effective;
      this.selects.hidden = !effective;
    }
    this.fill(effective || s.effective.reviewer);
  }

  setError(msg) {
    this.errorEl.textContent = msg || "";
    this.el.classList.toggle("invalid", !!msg);
  }

  flash() {
    flashSource(this);
  }
}
