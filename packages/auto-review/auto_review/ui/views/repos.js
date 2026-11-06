// Watched repos: one collapsible panel per repo with its own form, plus "add a repo".

import { h, replace, sectionHead } from "../lib/dom.js";
import { api, ApiError } from "../api.js";
import { Form } from "../lib/form.js";
import { ReviewerField } from "../lib/reviewer.js";
import { confirmButton, chip, toast } from "../lib/ui.js";
import { splitRepo } from "../store.js";

function countLeaves(obj) {
  if (obj == null || typeof obj !== "object" || Array.isArray(obj)) return 1;
  return Object.values(obj).reduce((n, v) => n + countLeaves(v), 0);
}

export function reposSection({ onSaved }) {
  const panels = new Map();
  const list = h("div");
  let settings = null;

  function order(s) {
    const nix = Object.keys(s.defaults?.repos || {});
    const ui = Object.keys(s.effective?.repos || {}).filter((id) => !nix.includes(id));
    return [...nix, ...ui];
  }

  function buildPanel(id) {
    const form = new Form({ repo: id, onSaved });
    const { forge, path } = splitRepo(id);
    const title = h("span", { class: "hi" }, `${forge} · ${path}`);
    const tags = h("span", { class: "meta" });
    const reviewer = new ReviewerField(form, { optional: true });
    const footer = h("div", { class: "actions" });
    const body = h(
      "div",
      { class: "body" },
      h("h4", null, "repo"),
      h(
        "div",
        { class: "form-grid" },
        form.field({ path: "enabled", label: "enabled", type: "checkbox", help: "watch this repo" }),
        form.field({ path: "checkout", label: "checkout", type: "text", help: "local clone the review reads git objects from" }),
        form.field({ path: "t3_project", label: "t3 project", type: "text", help: "project the review threads start in" }),
        form.field({ path: "context", label: "context", type: "textarea", rows: 4, span2: true, help: "repo-specific review instructions inserted into the brief" }),
      ),
      h("h4", null, "review"),
      h(
        "div",
        { class: "form-grid" },
        form.field({
          path: "threshold",
          label: "threshold",
          type: "number",
          min: 1,
          nullable: true,
          placeholder: (s) => `global (${s.effective.threshold})`,
          help: "minimum frequency × severity that gets posted; empty uses the global value",
        }),
        form.field({
          path: "request_changes_threshold",
          label: "request changes",
          type: "number",
          min: 1,
          nullable: true,
          placeholder: (s) => `global (${s.effective.request_changes_threshold})`,
          help: "a posted or open finding scoring this much requests changes on gitlab; empty uses the global value",
        }),
        form.field({
          path: "approval",
          label: "approval",
          type: "select",
          options: [
            { value: "never", label: "never" },
            { value: "when_clean", label: "when clean" },
          ],
          help: "approve when nothing reaches the threshold, every file was read and no injection was found",
        }),
        reviewer.el,
      ),
      h("h4", null, "rules"),
      h(
        "div",
        { class: "form-grid" },
        form.field({ path: "rules.review_requested", label: "review requested", type: "checkbox", help: "review MRs that request your review" }),
        form.field({ path: "rules.skip_drafts", label: "skip drafts", type: "checkbox", help: "wait while the MR is a draft" }),
        form.field({ path: "rules.wait_for_pipeline", label: "wait for pipeline", type: "checkbox", help: "wait until the head pipeline or checks succeed" }),
        form.field({ path: "rules.include_authors", label: "include authors", type: "list", help: "also review every open MR by these authors (comma separated)" }),
        form.field({ path: "rules.exclude_authors", label: "exclude authors", type: "list", help: "never review MRs by these authors" }),
        form.field({ path: "rules.require_labels", label: "require labels", type: "list", help: "review only MRs carrying all of these labels" }),
        form.field({ path: "rules.exclude_labels", label: "exclude labels", type: "list", help: "skip MRs carrying any of these labels" }),
      ),
      form.errorBox,
      footer,
    );
    const el = h("details", { class: "repo-panel", id: `repo-${id}` }, h("summary", null, title, tags), body);
    return { el, form, title, tags, footer, id };
  }

  function updatePanel(panel, s) {
    const eff = s.effective.repos[panel.id] || {};
    const nix = panel.id in (s.defaults?.repos || {});
    const overrides = s.overrides?.repos?.[panel.id];
    const n = nix && overrides ? countLeaves(overrides) : 0;
    panel.title.classList.toggle("low", eff.enabled === false);
    replace(panel.tags, eff.enabled === false ? chip("disabled") : null, nix ? chip("nix") : chip("added in ui", true), n ? chip(`${n} override${n === 1 ? "" : "s"}`, true) : null);
    const remove = nix
      ? overrides
        ? confirmButton({
            label: "reset all overrides",
            question: "drop every ui override of this repo?",
            confirm: "reset",
            cancel: "keep",
            onConfirm: async () => {
              await panel.form.save({ repos: { [panel.id]: null } });
              toast(`${panel.id} back to its nix settings`);
            },
          })
        : h("span", { class: "caption" }, "every value comes from nix")
      : confirmButton({
          label: "remove repo",
          question: "stop watching this repo and forget its settings?",
          confirm: "remove",
          cancel: "keep",
          danger: true,
          onConfirm: async () => {
            await panel.form.save({ repos: { [panel.id]: null } });
            toast(`${panel.id} removed`);
          },
        });
    replace(panel.footer, remove);
    panel.form.apply(s);
  }

  function apply(s) {
    settings = s;
    const ids = order(s);
    if (ids.join("\n") !== [...panels.keys()].join("\n")) {
      const open = new Set([...panels.values()].filter((p) => p.el.open).map((p) => p.id));
      panels.clear();
      replace(
        list,
        ids.length
          ? ids.map((id) => {
              const panel = buildPanel(id);
              panel.el.open = open.has(id);
              panels.set(id, panel);
              return panel.el;
            })
          : h("div", { class: "empty" }, "no repos are watched; add one below"),
      );
    }
    for (const panel of panels.values()) updatePanel(panel, s);
  }

  const add = addRepoForm({
    onSaved: (data, id) => {
      onSaved(data);
      const panel = panels.get(id);
      if (panel) {
        panel.el.open = true;
        panel.el.scrollIntoView({ block: "start", behavior: "smooth" });
      }
    },
  });

  const el = h("section", { "aria-label": "repos" }, sectionHead("05", "repos"), list, sectionHead("06", "add a repo"), add.el);

  return {
    el,
    apply,
    prefill(forge, path) {
      add.set(forge, path);
      add.el.scrollIntoView({ block: "start" });
    },
  };
}

function addRepoForm({ onSaved }) {
  const inputs = {
    forge: h("select", { id: "add-forge" }, h("option", { value: "gitlab" }, "gitlab"), h("option", { value: "github" }, "github")),
    path: h("input", { type: "text", id: "add-path", placeholder: "group/subgroup/project or owner/repo", autocomplete: "off" }),
    checkout: h("input", { type: "text", id: "add-checkout", placeholder: "/home/sgiath/develop/…", autocomplete: "off" }),
    t3_project: h("input", { type: "text", id: "add-project", placeholder: "t3 project name", autocomplete: "off" }),
    context: h("textarea", { id: "add-context", rows: 3, placeholder: "optional review instructions for this repo" }),
  };
  const errors = Object.fromEntries(Object.keys(inputs).map((k) => [k, h("p", { class: "error" })]));
  const formError = h("p", { class: "form-error" });
  const submit = h("button", { class: "btn", type: "submit" }, "add repo");

  const field = (key, label, help) =>
    h("div", { class: `field${key === "context" ? " span2" : ""}` }, h("div", { class: "field-head" }, h("label", { for: inputs[key].id }, label)), inputs[key], help ? h("p", { class: "help" }, help) : null, errors[key]);

  const clearErrors = () => {
    formError.textContent = "";
    for (const e of Object.values(errors)) e.textContent = "";
  };

  const el = h(
    "form",
    {
      class: "form",
      onsubmit: async (e) => {
        e.preventDefault();
        clearErrors();
        const forge = inputs.forge.value;
        const path = inputs.path.value.trim().replace(/^\/+|\/+$/g, "");
        const id = `${forge}:${path}`;
        const repo = { forge, path, checkout: inputs.checkout.value.trim(), t3_project: inputs.t3_project.value.trim() };
        if (inputs.context.value.trim()) repo.context = inputs.context.value;
        submit.disabled = true;
        try {
          const data = await api.patchSettings({ repos: { [id]: repo } });
          toast(`watching ${id}`);
          for (const k of ["path", "checkout", "t3_project", "context"]) inputs[k].value = "";
          onSaved(data, id);
        } catch (err) {
          if (err instanceof ApiError && err.status === 400) {
            const key = err.field ? Object.keys(inputs).find((k) => err.field === `repos.${id}.${k}` || err.field.endsWith(`.${k}`)) : null;
            if (key) errors[key].textContent = err.message;
            else formError.textContent = err.field ? `${err.field}: ${err.message}` : err.message;
          } else toast(err.message, "error");
        } finally {
          submit.disabled = false;
        }
      },
    },
    h(
      "div",
      { class: "form-grid" },
      field("forge", "forge"),
      field("path", "path", "the id becomes forge:path"),
      field("checkout", "checkout", "local clone; must exist"),
      field("t3_project", "t3 project"),
      field("context", "context"),
    ),
    formError,
    h("div", { class: "actions" }, submit, h("span", { class: "caption" }, "exists only in the ui overrides")),
  );

  return {
    el,
    set(forge, path) {
      if (forge) inputs.forge.value = forge;
      inputs.path.value = path || "";
      (path ? inputs.checkout : inputs.path).focus();
    },
  };
}
