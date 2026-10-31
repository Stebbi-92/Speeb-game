// The internet list of Brelm fellowships: a tiny Cloudflare Worker.
// Hosts announce themselves about once a minute; players fetch the list. Nothing is written to disk:
// the list lives in one Durable Object's memory, and a host that stops announcing drops off after two minutes.
//
//   POST /announce  {name, port, players, max, level, proto, version}   (the host's address is taken from the request)
//   POST /remove    {port}
//   GET  /list      -> {servers: [{name, ip, port, players, max, level, proto, version}]}

const TTL_MS = 120_000;
const MAX_SERVERS = 500;
const MAX_PER_IP = 4;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  });
}

function clean(s, n) {
  return String(s ?? "").replace(/[\u0000-\u001f]/g, "").slice(0, n);
}

export class Lobby {
  constructor(state, env) {
    this.servers = new Map();
  }

  async fetch(request) {
    const url = new URL(request.url);
    const ip = request.headers.get("x-brelm-ip") || "";
    const now = Date.now();
    for (const [k, s] of this.servers) if (s.expires < now) this.servers.delete(k);

    if (url.pathname === "/list" && request.method === "GET") {
      const servers = [...this.servers.values()].map(({ expires, ...s }) => s);
      return json({ servers });
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
        expires: now + TTL_MS,
      });
      return json({ ok: true, ip });
    }
    return json({ error: "not found" }, 404);
  }
}

export default {
  async fetch(request, env) {
    const ip = request.headers.get("cf-connecting-ip") || "";
    const headers = new Headers(request.headers);
    headers.set("x-brelm-ip", ip);
    const stub = env.LOBBY.get(env.LOBBY.idFromName("lobby"));
    return stub.fetch(new Request(request.url, {
      method: request.method,
      headers,
      body: request.method === "POST" ? await request.text() : undefined,
    }));
  },
};
