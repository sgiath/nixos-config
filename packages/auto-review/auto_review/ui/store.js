// Shared client state: the last status/settings/catalog payloads and the set of
// accepted-but-not-yet-visible (202) actions, so rows can show "queued…" until the
// next refresh reflects the change.

export const store = {
  status: null,
  settings: null,
  catalog: [],
  pending: new Map(),
};

// snapshot: the value whose change means the action took effect (e.g. the review's status).
export function setPending(key, { snapshot, ttl = 20000 } = {}) {
  store.pending.set(key, { snapshot, until: Date.now() + ttl });
}

export function isPending(key, current) {
  const entry = store.pending.get(key);
  if (!entry) return false;
  if (Date.now() > entry.until || (entry.snapshot !== undefined && entry.snapshot !== current)) {
    store.pending.delete(key);
    return false;
  }
  return true;
}

export function prunePending() {
  const t = Date.now();
  for (const [key, entry] of store.pending) if (t > entry.until) store.pending.delete(key);
}

export function pendingKeys() {
  return [...store.pending.keys()].sort();
}

export function providerLabel(provider) {
  return store.catalog.find((p) => p.provider === provider)?.label ?? provider ?? "–";
}

export function reviewerLabel(reviewer) {
  if (!reviewer) return "global reviewer";
  return `${providerLabel(reviewer.provider)} · ${reviewer.model} · ${reviewer.effort}`;
}

// "gitlab:remote-com/neo-payroll/neo" → { forge: "gitlab", path: "remote-com/neo-payroll/neo" }
export function splitRepo(repoId) {
  const i = repoId.indexOf(":");
  return i < 0 ? { forge: "", path: repoId } : { forge: repoId.slice(0, i), path: repoId.slice(i + 1) };
}

export function mrRef(forge, number) {
  return `${forge === "github" ? "#" : "!"}${number}`;
}

export function repoThreshold(repoId) {
  const eff = store.settings?.effective;
  if (!eff) return null;
  return eff.repos?.[repoId]?.threshold ?? eff.threshold ?? null;
}
