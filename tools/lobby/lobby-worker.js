// The internet list of Brelm fellowships: a tiny Cloudflare Worker.
// Hosts announce themselves about once a minute; players fetch the list. Nothing is written to disk:
// the list lives in one Durable Object's memory, and a host that stops announcing drops off after two minutes.
//
//   POST /announce  {name, port, players, max, level, proto, version, code, private, locked, detail, ip4, lan}   (the host's address is taken from the request)
//   POST /remove    {port}
//   GET  /list      -> {servers: [{name, ip, ip4, port, players, max, level, proto, version, locked, same, lan?}]}   (private ones are left out)
//   (ip4 is the host's public IPv4 as its router told it; same/lan say whether the asker shares the host's network)
//   GET  /code/XXXXXX -> {name, ip, port, players, max, level, proto, version, locked}   (a fellowship by its join code)
//   GET  /latest    -> {version, tag, name, notes, published, page, assets: {name: url}, news}
//   POST /report    {version, platform, kind, text}   (an error report the player chose to send)
//   GET  /reports   -> {reports: [{version, platform, kind, text, count, first, last}]}   (newest first)
//
// Reports keep only what the game sends: the error text and the game version. No address is stored;
// the sender's IP is used only in memory to stop one machine from flooding the list.
//
// /latest reads the newest release of the game's GitHub repository (GITHUB_REPO in wrangler.toml) and
// keeps it for ten minutes, so thousands of players asking for updates cost GitHub one request.
// "news" is the text of NEWS.txt on the repository's main branch, if there is one.

const TTL_MS = 120_000;
const MAX_SERVERS = 500;
const MAX_PER_IP = 4;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  });
}

const V4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
function ipv4(s) {
  const m = V4.exec(String(s ?? ""));
  return m && m.slice(1).every((x) => Number(x) <= 255) ? m[0] : "";
}
// A host's addresses on its own network, so that a pilgrim behind the same router can reach it there
// (many routers will not loop a connection to their own public address back inside)
function lanList(a) {
  if (!Array.isArray(a)) return [];
  return a.map(ipv4).filter((x) => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(x)).slice(0, 4);
}
// Same network: the same public IPv4, or the same IPv6 /64
function sameNet(a, b) {
  if (!a || !b) return false;
  if (a === b) return true;
  if (a.includes(":") && b.includes(":")) {
    const p = (x) => x.toLowerCase().split(":").slice(0, 4).join(":");
    return p(a) === p(b);
  }
  return false;
}

function clean(s, n) {
  return String(s ?? "").replace(/[\u0000-\u001f]/g, "").slice(0, n);
}

export class Lobby {
  constructor(state, env) {
    this.state = state;
    this.servers = new Map();
    // The list is kept in storage too, so it survives the object being put to sleep between visits
    state.blockConcurrencyWhile(async () => {
      const saved = await state.storage.get("servers");
      if (Array.isArray(saved)) for (const [k, v] of saved) this.servers.set(k, v);
    });
  }

  save() {
    return this.state.storage.put("servers", [...this.servers.entries()]);
  }

  // What a pilgrim is told of a fellowship: its local addresses only if they share its network
  view(s, ip) {
    const { expires, private: _p, lan, ...out } = s;
    out.same = sameNet(ip, s.ip) || sameNet(ip, s.ip4);
    if (out.same) out.lan = lan || [];
    return out;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const ip = request.headers.get("x-brelm-ip") || "";
    const now = Date.now();
    let dropped = false;
    for (const [k, s] of this.servers) if (s.expires < now) { this.servers.delete(k); dropped = true; }
    if (dropped) await this.save();

    if (url.pathname === "/list" && request.method === "GET") {
      const servers = [...this.servers.values()].filter((s) => !s.private).map((s) => this.view(s, ip));
      return json({ servers });
    }
    if (url.pathname.startsWith("/code/") && request.method === "GET") {
      const code = clean(url.pathname.slice(6), 12).toUpperCase();
      for (const s of this.servers.values()) {
        if (code.length >= 4 && s.code === code) return json(this.view(s, ip));
      }
      return json({ error: "no fellowship has that code" }, 404);
    }
    if (request.method !== "POST" || !ip) return json({ error: "not found" }, 404);

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "bad body" }, 400);
    }
    const port = Number(body.port);
    if (!Number.isInteger(port) || port < 1 || port > 65535) return json({ error: "bad port" }, 400);
    const key = `${ip}|${port}`;

    if (url.pathname === "/remove") {
      this.servers.delete(key);
      await this.save();
      return json({ ok: true });
    }
    if (url.pathname === "/announce") {
      if (!this.servers.has(key)) {
        let mine = 0;
        for (const s of this.servers.values()) if (s.ip === ip) mine++;
        if (mine >= MAX_PER_IP || this.servers.size >= MAX_SERVERS) return json({ error: "full" }, 429);
      }
      this.servers.set(key, {
        name: clean(body.name, 40) || "A fellowship of Brelm",
        ip,
        port,
        players: Math.max(0, Math.min(8, Number(body.players) | 0)),
        max: Math.max(1, Math.min(8, Number(body.max) | 0)),
        level: Number(body.level) | 0,
        proto: clean(body.proto, 40),
        version: clean(body.version, 16),
        code: clean(body.code, 12).toUpperCase().replace(/[^A-Z0-9]/g, ""),
        private: !!body.private,
        locked: !!body.locked,
        detail: clean(body.detail, 60),
        ip4: ipv4(body.ip4),
        lan: lanList(body.lan),
        expires: now + TTL_MS,
      });
      await this.save();
      return json({ ok: true, ip });
    }
    return json({ error: "not found" }, 404);
  }
}

// Error reports: one Durable Object holding the last few hundred distinct errors, counted
const MAX_REPORTS = 200;
const REPORTS_PER_IP_HOUR = 10;

// Take user names out of file paths, in case a log line carries one
function scrub(s) {
  return String(s ?? "")
    .replace(/[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s]+/gi, "~")
    .replace(/\/(home|Users)\/[^/\s]+/g, "~")
    .replace(/[\u0000-\u0008\u000b-\u001f]/g, "");
}

async function hash(s) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export class Reports {
  constructor(state, env) {
    this.state = state;
    this.recent = new Map(); // ip -> [times], memory only
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/reports" && request.method === "GET") {
      const all = await this.state.storage.list({ prefix: "r:" });
      const out = [...all.values()].sort((a, b) => b.last - a.last);
      return json({ reports: out });
    }
    if (url.pathname === "/report" && request.method === "POST") {
      const ip = request.headers.get("x-brelm-ip") || "";
      const now = Date.now();
      const times = (this.recent.get(ip) || []).filter((t) => now - t < 3_600_000);
      if (times.length >= REPORTS_PER_IP_HOUR) return json({ ok: false, error: "too many" }, 429);
      times.push(now);
      this.recent.set(ip, times);
      if (this.recent.size > 5000) this.recent.clear();

      let body;
      try { body = JSON.parse(await request.text()); } catch { return json({ ok: false, error: "bad json" }, 400); }
      const r = {
        version: clean(body.version, 40),
        platform: clean(body.platform, 40),
        kind: clean(body.kind, 20) === "crash" ? "crash" : "error",
        text: scrub(body.text).slice(0, 4000),
      };
      if (!r.text.trim()) return json({ ok: false, error: "empty" }, 400);
      const key = "r:" + (await hash(r.version + "|" + r.kind + "|" + r.text));
      const old = await this.state.storage.get(key);
      if (old) {
        old.count += 1;
        old.last = now;
        await this.state.storage.put(key, old);
      } else {
        await this.state.storage.put(key, { ...r, count: 1, first: now, last: now });
        const all = await this.state.storage.list({ prefix: "r:" });
        if (all.size > MAX_REPORTS) {
          const drop = [...all.entries()].sort((a, b) => a[1].last - b[1].last).slice(0, all.size - MAX_REPORTS);
          await this.state.storage.delete(drop.map((e) => e[0]));
        }
      }
      return json({ ok: true });
    }
    return json({ error: "not found" }, 404);
  }
}

const LATEST_TTL_S = 600;

async function latest(request, env, ctx) {
  const cache = caches.default;
  const key = new Request(new URL("/latest", request.url).toString());
  const hit = await cache.match(key);
  if (hit) return hit;

  const repo = env.GITHUB_REPO || "Stebbi-92/Speeb-game";
  const headers = { "user-agent": "brelm-lobby", accept: "application/vnd.github+json" };
  if (env.GITHUB_TOKEN) headers.authorization = `Bearer ${env.GITHUB_TOKEN}`;

  // /releases/latest skips pre-releases, and every alpha is one, so take the newest non-draft release
  const r = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=10`, { headers });
  if (!r.ok) return json({ error: `github ${r.status}` }, 502);
  const list = await r.json();
  const rel = (Array.isArray(list) ? list : []).find((x) => !x.draft);
  const out = { version: "", tag: "", name: "", notes: "", published: "", page: "", assets: {}, news: "" };
  if (rel) {
    out.tag = clean(rel.tag_name, 40);
    out.version = out.tag.replace(/^v/, "");
    out.name = clean(rel.name, 80);
    out.notes = String(rel.body ?? "").slice(0, 4000);
    out.published = clean(rel.published_at, 40);
    out.page = clean(rel.html_url, 200);
    for (const a of rel.assets ?? []) out.assets[clean(a.name, 80)] = { url: a.browser_download_url, size: a.size, digest: typeof a.digest === "string" ? a.digest : "" };
  }
  try {
    const n = await fetch(`https://raw.githubusercontent.com/${repo}/main/NEWS.txt`, { headers: { "user-agent": "brelm-lobby" } });
    if (n.ok) out.news = (await n.text()).slice(0, 2000);
  } catch {}

  const res = json(out);
  res.headers.set("cache-control", `public, max-age=${LATEST_TTL_S}`);
  ctx.waitUntil(cache.put(key, res.clone()));
  return res;
}

export default {
  async fetch(request, env, ctx) {
    if (new URL(request.url).pathname === "/latest" && request.method === "GET") return latest(request, env, ctx);
    const ip = request.headers.get("cf-connecting-ip") || "";
    const headers = new Headers(request.headers);
    headers.set("x-brelm-ip", ip);
    const path = new URL(request.url).pathname;
    const ns = path === "/report" || path === "/reports" ? env.REPORTS : env.LOBBY;
    const stub = ns.get(ns.idFromName(ns === env.REPORTS ? "reports" : "lobby"));
    return stub.fetch(new Request(request.url, {
      method: request.method,
      headers,
      body: request.method === "POST" ? await request.text() : undefined,
    }));
  },
};
