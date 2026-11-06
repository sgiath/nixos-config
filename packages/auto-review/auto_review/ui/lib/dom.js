// Tiny DOM helpers: h() builds elements, replace() swaps children while keeping focus.

export function h(tag, attrs = null, ...children) {
  const el = document.createElement(tag);
  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (value == null || value === false) continue;
      if (key === "class") el.className = value;
      else if (key === "dataset") Object.assign(el.dataset, value);
      else if (key === "style") el.style.cssText = value;
      else if (key.startsWith("on") && typeof value === "function") el.addEventListener(key.slice(2).toLowerCase(), value);
      else if (key === "html") el.innerHTML = value; // only ever fed pre-escaped markdown output
      else if (key === "value") el.value = value;
      else if (typeof value === "boolean") {
        el[key] = value;
        if (value && !(key in el)) el.setAttribute(key, "");
      } else el.setAttribute(key, value);
    }
  }
  append(el, children);
  return el;
}

export function append(el, children) {
  for (const child of children.flat(Infinity)) {
    if (child == null || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return el;
}

// Replace children; if the focused element carried data-focus, focus its successor.
export function replace(el, ...children) {
  const active = document.activeElement;
  const key = el.contains(active) ? active?.dataset?.focus : null;
  el.replaceChildren();
  append(el, children);
  if (key) el.querySelector(`[data-focus="${CSS.escape(key)}"]`)?.focus();
  return el;
}

export function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

export function sectionHead(index, label, { count, tools } = {}) {
  return h(
    "div",
    { class: "section-head" },
    h("span", { class: "index" }, index),
    h("span", { class: "label" }, label),
    count != null ? h("span", { class: "count num" }, String(count)) : null,
    h("span", { class: "rule" }),
    tools ? h("div", { class: "tools" }, tools) : null,
  );
}

export function externalLink(href, label, cls = "quiet") {
  return h("a", { class: cls, href, target: "_blank", rel: "noopener noreferrer" }, label);
}
