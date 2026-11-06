// Note template editor: textarea with explicit save, clickable variables, live preview
// through POST /api/note-preview (debounced), unknown variables flagged.

import { h, sectionHead } from "../lib/dom.js";
import { renderMarkdown } from "../lib/markdown.js";
import { api } from "../api.js";
import { Form, Field } from "../lib/form.js";

export const VARIABLES = [
  ["reviewer", "your username on that forge"],
  ["provider", "provider instance"],
  ["model", "model id"],
  ["effort", "reasoning effort"],
  ["harness", "agent harness"],
  ["repo", "repo path"],
  ["number", "MR / PR number"],
  ["head_sha", "reviewed head, full"],
  ["head_short", "reviewed head, short"],
  ["finding_id", "finding id"],
  ["title", "finding title"],
  ["frequency", "frequency 1–5"],
  ["severity", "severity 1–5"],
  ["score", "frequency × severity"],
  ["threshold", "repo threshold"],
  ["disposition", "posted / post anyway …"],
];

export function templateEditor({ onSaved }) {
  const form = new Form({ onSaved });
  const field = form.register(
    new Field(form, {
      path: "note_template",
      label: "note template",
      type: "textarea",
      code: true,
      rows: 10,
      help: "markdown at the top of every posted comment; a hidden marker is appended after the body",
    }),
  );
  const textarea = field.control;
  const preview = h("div", { class: "preview prose" });
  const warn = h("p", { class: "warnline" });
  let timer = null;
  let lastRequested = null;

  async function renderPreview() {
    const template = textarea.value;
    if (template === lastRequested) return;
    lastRequested = template;
    try {
      const { markdown, unknown } = await api.notePreview(template);
      if (textarea.value !== template) return; // a newer request is on its way
      preview.innerHTML = renderMarkdown(markdown);
      warn.textContent = unknown?.length ? `unknown variables left as typed: ${unknown.map((u) => `{${u}}`).join(", ")}` : "";
    } catch (err) {
      warn.textContent = `preview failed: ${err.message}`;
    }
  }

  function schedulePreview() {
    clearTimeout(timer);
    timer = setTimeout(renderPreview, 300);
  }

  textarea.addEventListener("input", schedulePreview);

  const vars = h(
    "div",
    { class: "vars", role: "group", "aria-label": "template variables" },
    VARIABLES.map(([name, title]) =>
      h(
        "button",
        {
          class: "btn",
          type: "button",
          title,
          onclick: () => {
            const token = `{${name}}`;
            textarea.setRangeText(token, textarea.selectionStart, textarea.selectionEnd, "end");
            textarea.focus();
            textarea.dispatchEvent(new Event("input", { bubbles: true }));
          },
        },
        `{${name}}`,
      ),
    ),
  );

  const el = h(
    "section",
    { "aria-label": "note template" },
    sectionHead("04", "note template"),
    h(
      "div",
      { class: "editor" },
      h("div", { class: "form" }, field.el, h("div", null, h("p", { class: "caption", style: "margin-bottom: 8px" }, "variables · click to insert"), vars), form.errorBox),
      h("div", { class: "form" }, h("div", { class: "field" }, h("div", { class: "field-head" }, h("span", { class: "name" }, "preview"), h("span", { class: "source" }, "sample finding")), preview, warn)),
    ),
  );

  return {
    el,
    apply(settings) {
      const before = textarea.value;
      form.apply(settings);
      if (!field.dirty && (textarea.value !== before || lastRequested === null)) schedulePreview();
    },
  };
}
