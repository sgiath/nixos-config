// Small Markdown renderer for note previews, summaries and finding bodies.
// Everything is HTML-escaped first; the output is a string for `html:` attributes.
// Supported: paragraphs (soft breaks become <br>, as GitLab/GitHub comments render them),
// blockquotes including GitHub `> [!NOTE]` alerts, headings, lists, fenced code, rules,
// bold, italic, strikethrough, inline code, links and bare URLs. HTML comments are dropped.

import { esc } from "./dom.js";

const ALERTS = { NOTE: "note", TIP: "tip", IMPORTANT: "important", WARNING: "warning", CAUTION: "caution" };

export function renderMarkdown(source) {
  const text = String(source ?? "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/\r\n?/g, "\n");
  return renderBlocks(text.split("\n"));
}

function renderBlocks(lines) {
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) {
      i += 1;
      continue;
    }
    if (/^```/.test(line)) {
      const code = [];
      i += 1;
      while (i < lines.length && !/^```/.test(lines[i])) code.push(lines[i++]);
      i += 1;
      out.push(`<pre><code>${esc(code.join("\n"))}</code></pre>`);
      continue;
    }
    if (/^\s*>/.test(line)) {
      const inner = [];
      while (i < lines.length && /^\s*>/.test(lines[i])) inner.push(lines[i++].replace(/^\s*>\s?/, ""));
      out.push(renderQuote(inner));
      continue;
    }
    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      const level = Math.min(5, heading[1].length + 2);
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      i += 1;
      continue;
    }
    if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
      out.push("<hr>");
      i += 1;
      continue;
    }
    if (/^\s*[-*+]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*[-*+]\s+/.test(lines[i])) items.push(lines[i++].replace(/^\s*[-*+]\s+/, ""));
      out.push(`<ul>${items.map((it) => `<li>${inline(it)}</li>`).join("")}</ul>`);
      continue;
    }
    if (/^\s*\d+[.)]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*\d+[.)]\s+/.test(lines[i])) items.push(lines[i++].replace(/^\s*\d+[.)]\s+/, ""));
      out.push(`<ol>${items.map((it) => `<li>${inline(it)}</li>`).join("")}</ol>`);
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^(\s*>|```|#{1,6}\s|\s*[-*+]\s|\s*\d+[.)]\s)/.test(lines[i])) {
      para.push(lines[i++]);
    }
    out.push(`<p>${para.map(inline).join("<br>")}</p>`);
  }
  return out.join("");
}

function renderQuote(lines) {
  const first = lines.find((l) => l.trim()) ?? "";
  const alert = /^\s*\[!([A-Z]+)\]\s*$/.exec(first);
  if (alert && ALERTS[alert[1]]) {
    const rest = lines.slice(lines.indexOf(first) + 1);
    return `<div class="alert alert-${ALERTS[alert[1]]}"><p class="alert-title">${ALERTS[alert[1]]}</p>${renderBlocks(rest)}</div>`;
  }
  return `<blockquote>${renderBlocks(lines)}</blockquote>`;
}

export function inline(raw) {
  const codes = [];
  let s = esc(raw).replace(/`([^`\n]+)`/g, (_, code) => {
    codes.push(`<code>${code}</code>`);
    return `\u0000${codes.length - 1}\u0000`;
  });
  s = s.replace(/\[([^\]\n]+)\]\(([^)\s]+)\)/g, (_, label, href) => link(href, label));
  s = s.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, (_, pre, url) => pre + link(url, url));
  s = s.replace(/\*\*([^*\n]+)\*\*/g, "<strong>$1</strong>").replace(/__([^_\n]+)__/g, "<strong>$1</strong>");
  s = s.replace(/(^|[^\w*])\*([^*\n]+)\*(?=[^\w*]|$)/g, "$1<em>$2</em>");
  s = s.replace(/(^|[^\w_])_([^_\n]+)_(?=[^\w_]|$)/g, "$1<em>$2</em>");
  s = s.replace(/~~([^~\n]+)~~/g, "<del>$1</del>");
  return s.replace(/\u0000(\d+)\u0000/g, (_, n) => codes[Number(n)]);
}

function link(href, label) {
  const safe = /^https?:\/\//i.test(href) ? href : "#";
  return `<a href="${safe}" target="_blank" rel="noopener noreferrer">${label}</a>`;
}
