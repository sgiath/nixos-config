// Settings form binding. A Field maps one settings path to a control, shows where its
// value comes from (nix default or ui override), offers "reset to nix" (PATCH null), saves
// on change/blur/Enter, and never overwrites a control the user is editing.

import { h } from "./dom.js";
import { api, ApiError } from "../api.js";
import { toast } from "./ui.js";

export function getPath(obj, segs) {
  let cur = obj;
  for (const s of segs) {
    if (cur == null || typeof cur !== "object") return undefined;
    cur = cur[s];
  }
  return cur;
}

export function setPath(obj, segs, value) {
  let cur = obj;
  for (const s of segs.slice(0, -1)) {
    if (cur[s] == null || typeof cur[s] !== "object") cur[s] = {};
    cur = cur[s];
  }
  cur[segs[segs.length - 1]] = value;
  return obj;
}

export function fmtValue(v) {
  if (v == null) return "unset";
  if (Array.isArray(v)) return v.join(", ") || "empty";
  if (typeof v === "object") return Object.values(v).join(" / ");
  return String(v);
}

let seq = 0;

export class Form {
  // repo: bind fields under repos.<id>; onSaved(settings) runs after every successful PATCH
  constructor({ repo = null, onSaved = null } = {}) {
    this.repo = repo;
    this.onSaved = onSaved;
    this.fields = [];
    this.settings = null;
    this.errorBox = h("p", { class: "form-error" });
  }

  segs(path) {
    return this.repo ? ["repos", this.repo, ...path.split(".")] : path.split(".");
  }

  // a repo added in the UI has no nix defaults: every value is "ui", nothing resets
  uiRepo() {
    return !!this.repo && !!this.settings && !(this.repo in (this.settings.defaults?.repos || {}));
  }

  field(spec) {
    return this.register(new Field(this, spec)).el;
  }

  register(field) {
    this.fields.push(field);
    if (this.settings) field.apply();
    return field;
  }

  apply(settings) {
    this.settings = settings;
    for (const f of this.fields) f.apply();
  }

  async save(patch, field) {
    try {
      const data = await api.patchSettings(patch);
      this.clearErrors();
      field?.flash();
      this.onSaved?.(data);
      return data;
    } catch (err) {
      if (err instanceof ApiError && err.status === 400) this.showError(err.field, err.message, field);
      else toast(err.message, "error");
      throw err;
    }
  }

  // 400 {"error", "field"}: attach to the exact field, else to its parent, else to the form
  showError(key, message, fallback) {
    const target =
      (key && (this.fields.find((f) => f.key === key) || this.fields.find((f) => key.startsWith(`${f.key}.`)))) || fallback;
    if (target) target.setError(key && key !== target.key ? `${key.slice(key.lastIndexOf(".") + 1)}: ${message}` : message);
    else this.errorBox.textContent = key ? `${key}: ${message}` : message;
  }

  clearErrors() {
    this.errorBox.textContent = "";
    for (const f of this.fields) f.setError("");
  }
}

// spec: { path, label, type: text|number|time|checkbox|select|textarea|list, help, options,
//         placeholder (string or settings => string), min, max, rows, code, nullable, span2, list }
export class Field {
  constructor(form, spec) {
    this.form = form;
    this.spec = spec;
    this.segs = form.segs(spec.path);
    this.key = this.segs.join(".");
    this.id = `f${++seq}`;
    this.dirty = false;
    this.saving = false;
    this.server = undefined;
    this.control = this.buildControl();
    this.source = h("span", { class: "source" });
    this.resetBtn = h("button", { class: "btn text small reset", type: "button", hidden: true, onclick: () => this.reset() }, "reset to nix");
    this.errorEl = h("p", { class: "error" });
    const check = spec.type === "checkbox";
    this.el = h(
      "div",
      { class: `field${spec.span2 ? " span2" : ""}`, "data-key": this.key },
      h(
        "div",
        { class: "field-head" },
        check ? h("span", { class: "name" }, spec.label) : h("label", { for: this.id }, spec.label),
        this.source,
        this.resetBtn,
      ),
      check ? h("label", { class: "check", for: this.id }, this.control, h("span", null, spec.help || "")) : this.control,
      !check && spec.help ? h("p", { class: "help" }, spec.help) : null,
      this.manualBar(),
      this.errorEl,
    );
  }

  buildControl() {
    const { type = "text", options = [], min, max, placeholder, rows, list } = this.spec;
    const ph = typeof placeholder === "string" ? placeholder : null;
    if (type === "checkbox") return h("input", { type: "checkbox", id: this.id, onchange: () => this.commit(true) });
    if (type === "select") {
      return h(
        "select",
        { id: this.id, onchange: () => this.commit(true) },
        options.map((o) => h("option", { value: o.value }, o.label)),
      );
    }
    if (type === "textarea") {
      return h("textarea", {
        id: this.id,
        class: this.spec.code ? "code" : null,
        rows: rows || 4,
        placeholder: ph,
        spellcheck: "false",
        oninput: () => this.onInput(),
      });
    }
    return h("input", {
      type: type === "list" ? "text" : type,
      id: this.id,
      min,
      max,
      step: type === "number" ? "1" : null,
      placeholder: ph,
      list,
      autocomplete: "off",
      oninput: () => this.onInput(),
      onblur: () => this.commit(),
      onkeydown: (e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          this.commit();
        } else if (e.key === "Escape") this.revert();
      },
    });
  }

  // textareas save explicitly; everything else saves itself
  manualBar() {
    if (this.spec.type !== "textarea") return null;
    this.bar = h(
      "div",
      { class: "actions", hidden: true },
      h("button", { class: "btn small", type: "button", onclick: () => this.commit() }, "save"),
      h("button", { class: "btn small text", type: "button", onclick: () => this.revert() }, "discard"),
    );
    return this.bar;
  }

  read() {
    const { type = "text", nullable } = this.spec;
    const c = this.control;
    if (type === "checkbox") return c.checked;
    if (type === "number") return c.value === "" ? (nullable ? null : this.server) : Number(c.value);
    if (type === "list") return c.value.split(/[,\s]+/).map((s) => s.trim()).filter(Boolean);
    if (type === "select") return c.value;
    return c.value === "" && nullable ? null : c.value;
  }

  write(value) {
    const { type = "text" } = this.spec;
    const c = this.control;
    if (type === "checkbox") c.checked = !!value;
    else if (type === "list") c.value = (value || []).join(", ");
    else c.value = value == null ? "" : String(value);
  }

  same(a, b) {
    return JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
  }

  onInput() {
    this.dirty = !this.same(this.read(), this.server);
    if (this.bar) this.bar.hidden = !this.dirty;
  }

  apply() {
    const s = this.form.settings;
    if (!s) return;
    this.server = getPath(s.effective, this.segs);
    const ui = this.form.uiRepo();
    const overridden = !ui && getPath(s.overrides, this.segs) !== undefined;
    this.el.classList.toggle("overridden", overridden);
    this.sourceText = ui ? "ui" : overridden ? "ui override" : "nix";
    if (!this.source.classList.contains("saved")) this.source.textContent = this.sourceText;
    this.resetBtn.hidden = !overridden;
    this.resetBtn.title = overridden ? `nix: ${fmtValue(getPath(s.defaults, this.segs))}` : "";
    if (typeof this.spec.placeholder === "function") this.control.placeholder = this.spec.placeholder(s) ?? "";
    if (!this.dirty && document.activeElement !== this.control) this.write(this.server);
  }

  async commit(immediate = false) {
    if (immediate) this.onInput();
    if (!this.dirty || this.saving) return;
    this.saving = true;
    const value = this.read();
    try {
      await this.form.save(setPath({}, this.segs, value), this);
      this.dirty = false;
      if (this.bar) this.bar.hidden = true;
      this.apply();
    } catch {
      if (immediate) this.write(this.server);
    } finally {
      this.saving = false;
    }
  }

  revert() {
    this.write(this.server);
    this.dirty = false;
    if (this.bar) this.bar.hidden = true;
    this.setError("");
  }

  async reset() {
    try {
      await this.form.save(setPath({}, this.segs, null), this);
      this.dirty = false;
      if (this.bar) this.bar.hidden = true;
      this.apply();
    } catch {
      /* shown by the form */
    }
  }

  setError(msg) {
    this.errorEl.textContent = msg || "";
    this.el.classList.toggle("invalid", !!msg);
  }

  flash() {
    flashSource(this);
  }
}

// the source caption reads "saved" for a moment, then returns to nix / ui override
export function flashSource(field) {
  field.source.classList.add("saved");
  field.source.textContent = "saved";
  clearTimeout(field.flashTimer);
  field.flashTimer = setTimeout(() => {
    field.source.classList.remove("saved");
    field.source.textContent = field.sourceText ?? "";
  }, 1400);
}
