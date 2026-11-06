// HTTP client for the auto-review API. Mutations always send Content-Type: application/json;
// non-2xx answers become ApiError with the server's message and, for 400s, the named field.

export class ApiError extends Error {
  constructor(status, body) {
    super(body?.error || `HTTP ${status}`);
    this.status = status;
    this.field = body?.field ?? null;
  }
}

async function request(method, path, body) {
  const init = { method, cache: "no-store", headers: {} };
  if (body !== undefined) {
    init.headers["Content-Type"] = "application/json";
    init.body = JSON.stringify(body);
  }
  let res;
  try {
    res = await fetch(path, init);
  } catch (err) {
    throw new ApiError(0, { error: `service unreachable (${err.message})` });
  }
  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { error: text.slice(0, 200) };
    }
  }
  if (!res.ok) throw new ApiError(res.status, data || { error: res.statusText });
  return { status: res.status, data };
}

const get = (path) => request("GET", path).then((r) => r.data);

export const api = {
  status: () => get("/api/status"),
  settings: () => get("/api/settings"),
  catalog: () => get("/api/catalog"),
  reviews: (params) => get(`/api/reviews?${new URLSearchParams(params)}`),
  review: (id) => get(`/api/reviews/${encodeURIComponent(id)}`),
  waiting: () => get("/api/waiting"),
  discovered: () => get("/api/discovered"),
  events: (limit = 100) => get(`/api/events?limit=${limit}`),

  patchSettings: (partial) => request("PATCH", "/api/settings", partial).then((r) => r.data),
  notePreview: (template) => request("POST", "/api/note-preview", { template }).then((r) => r.data),
  pollNow: () => request("POST", "/api/poll", {}),
  cancel: (id) => request("POST", `/api/reviews/${encodeURIComponent(id)}/cancel`, {}),
  retry: (id) => request("POST", `/api/reviews/${encodeURIComponent(id)}/retry`, {}),
  postFinding: (id, findingId) =>
    request("POST", `/api/reviews/${encodeURIComponent(id)}/findings/${encodeURIComponent(findingId)}/post`, {}),
};
