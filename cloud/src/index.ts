// Tennis Vision cloud API (TV-API-01 to TV-API-04) on Cloudflare Workers.
// The closet PC writes with the write token; Chris's phone reads with the read token.
// The Worker only stores and serves: it computes no statistics (TV-ARCH-01, TV-API-04),
// and it never receives health data (Chris, 15 Nov).
export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
  WRITE_TOKEN: string;
  READ_TOKEN: string;
  LINK_KEY: string; // signs upload and video links
}

const MULTIPART_ABOVE = 100 * 1024 * 1024; // TV-UP-01: multipart above 100 MB
const LINK_SECONDS = 3600;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    try {
      return await route(req, env);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      return json({ error: "internal error" }, 500);
    }
  },
};

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function route(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const p = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
  const m = req.method;

  // signed links (upload from the PC, video for the app's player) carry their own signature
  if (p[0] === "sessions" && p[2] === "files" && url.searchParams.has("sig")) {
    const path = p.slice(3).join("/");
    await checkLink(env, m === "GET" ? "get" : "put", p[1], path, url);
    if (m === "GET") return getFile(env, req, p[1], path);
    return putFile(env, req, p[1], path, url);
  }

  if (m === "POST" && p[0] === "sessions" && p.length === 1) {
    need(req, env, "write");
    return createSession(env, await body(req));
  }
  if (m === "POST" && p[0] === "sessions" && p[2] === "upload-url" && p.length === 3) {
    need(req, env, "write");
    return uploadUrl(env, url, p[1], await body(req));
  }
  if (m === "PUT" && p[0] === "sessions" && p[2] === "data" && p.length === 3) {
    need(req, env, "write");
    return putData(env, p[1], await body(req));
  }
  if (m === "GET" && p[0] === "sessions" && p.length === 1) {
    need(req, env, "read");
    return listSessions(env);
  }
  if (m === "GET" && p[0] === "sessions" && p.length === 2) {
    need(req, env, "read");
    return getSession(env, url, p[1]);
  }
  if (m === "GET" && p[0] === "sessions" && p[2] === "shots" && p.length === 3) {
    need(req, env, "read");
    return getShots(env, p[1]);
  }
  if (m === "GET" && p[0] === "sessions" && p[2] === "files" && p.length > 3) {
    need(req, env, "read");
    return getFile(env, req, p[1], p.slice(3).join("/"));
  }
  if (m === "GET" && p[0] === "trends" && p.length === 1) {
    need(req, env, "read");
    return trends(env, url);
  }
  if (m === "POST" && p[0] === "sessions" && p[2] === "identity" && p.length === 3) {
    need(req, env, "read"); // the app has only the read token; this is its one write
    return postIdentity(env, p[1], await body(req));
  }
  if (m === "POST" && p[0] === "sessions" && p[2] === "conditions" && p.length === 3) {
    need(req, env, "read"); // the app's second write: the indoor flag only
    return postConditions(env, p[1], await body(req));
  }
  if (m === "GET" && p[0] === "conditions" && p[1] === "pending" && p.length === 2) {
    need(req, env, "write");
    const r = await env.DB.prepare(
      "SELECT id, session_id AS sessionId, indoor, answered_utc AS answeredUtc FROM session_conditions WHERE applied = 0 ORDER BY id",
    ).all();
    return json(r.results.map((x: any) => ({ ...x, indoor: !!x.indoor })));
  }
  if (m === "POST" && p[0] === "conditions" && p[2] === "applied" && p.length === 3) {
    need(req, env, "write");
    await env.DB.prepare("UPDATE session_conditions SET applied = 1 WHERE id = ?").bind(Number(p[1])).run();
    return json({ ok: true });
  }
  // ---- detector feedback (Chris, 15 Nov) ----
  if (m === "POST" && p[0] === "checks" && p.length === 1) {
    need(req, env, "write");
    return postChecks(env, await body(req));
  }
  if (m === "GET" && p[0] === "checks" && p[1] === "next" && p.length === 2) {
    need(req, env, "read");
    return nextChecks(env, url);
  }
  if (m === "POST" && p[0] === "checks" && p[2] === "answer" && p.length === 3) {
    need(req, env, "read");
    return answerCheck(env, Number(p[1]), await body(req));
  }
  if (m === "GET" && p[0] === "checks" && p[1] === "answered" && p.length === 2) {
    need(req, env, "write");
    const r = await env.DB.prepare(
      `SELECT id, session_id AS sessionId, frame_ref AS frameRef, pred_x AS predX, pred_y AS predY, width, height,
              answer, ans_x AS ansX, ans_y AS ansY, answered_utc AS answeredUtc
         FROM ball_checks WHERE answer IS NOT NULL AND applied = 0 ORDER BY id`).all();
    return json(r.results);
  }
  if (m === "POST" && p[0] === "checks" && p[2] === "applied" && p.length === 3) {
    need(req, env, "write");
    await env.DB.prepare("UPDATE ball_checks SET applied = 1 WHERE id = ?").bind(Number(p[1])).run();
    return json({ ok: true });
  }
  if (m === "GET" && p[0] === "checks" && p[1] === "waiting" && p.length === 2) {
    need(req, env, "read"); // for the tile: the rows, the app counts them
    const r = await env.DB.prepare("SELECT id FROM ball_checks WHERE answer IS NULL").all();
    return json(r.results);
  }
  if (m === "POST" && p[0] === "sessions" && p[2] === "flags" && p.length === 3) {
    need(req, env, "read");
    return postFlag(env, p[1], await body(req));
  }
  if (m === "GET" && p[0] === "flags" && p.length === 1) {
    need(req, env, "write");
    const status = url.searchParams.get("status") ?? "open";
    const r = await env.DB.prepare(
      `SELECT id, session_id AS sessionId, kind, rally, shot, reason, t, created_utc AS createdUtc, status, note
         FROM flags WHERE status = ? ORDER BY id`).bind(status).all();
    return json(r.results);
  }
  if (m === "POST" && p[0] === "flags" && p[2] === "status" && p.length === 3) {
    need(req, env, "write");
    const b = await body(req);
    if (!["open", "applied", "reviewed"].includes(b.status)) throw new HttpError(400, "bad status");
    await env.DB.prepare("UPDATE flags SET status = ?, note = ? WHERE id = ?").bind(b.status, typeof b.note === "string" ? b.note : null, Number(p[1])).run();
    return json({ ok: true });
  }
  // ---- opponents (Chris, 15 Nov): names only here ----
  if (m === "GET" && p[0] === "opponents" && p.length === 1) {
    need(req, env, "read");
    return listOpponents(env);
  }
  if (m === "POST" && p[0] === "opponents" && p.length === 1) {
    need(req, env, "read");
    const b = await body(req);
    const name = cleanName(b.name);
    const r = await env.DB.prepare("INSERT INTO opponents (name, created_utc) VALUES (?, ?) RETURNING id").bind(name, now()).first<any>();
    return json({ id: r.id, name });
  }
  if (m === "PUT" && p[0] === "opponents" && p.length === 2) {
    need(req, env, "read");
    const b = await body(req);
    await env.DB.prepare("UPDATE opponents SET name = ? WHERE id = ?").bind(cleanName(b.name), Number(p[1])).run();
    return json({ ok: true });
  }
  if (m === "POST" && p[0] === "opponents" && p[2] === "merge" && p.length === 3) {
    need(req, env, "read");
    const b = await body(req);
    const from = Number(p[1]), into = Number(b.into);
    if (!Number.isInteger(into) || into === from) throw new HttpError(400, "merge into another opponent");
    await env.DB.batch([
      env.DB.prepare("UPDATE session_opponents SET opponent_id = ? WHERE opponent_id = ?").bind(into, from),
      env.DB.prepare("DELETE FROM opponents WHERE id = ?").bind(from),
    ]);
    return json({ ok: true });
  }
  if (m === "DELETE" && p[0] === "opponents" && p.length === 2) {
    need(req, env, "read");
    const id = Number(p[1]);
    await env.DB.batch([
      env.DB.prepare("UPDATE session_opponents SET opponent_id = NULL WHERE opponent_id = ?").bind(id),
      env.DB.prepare("DELETE FROM opponents WHERE id = ?").bind(id),
    ]);
    return json({ ok: true });
  }
  if (m === "POST" && p[0] === "sessions" && p[2] === "opponent" && p.length === 3) {
    need(req, env, "read");
    const b = await body(req);
    const opp = b.opponentId === null ? null : Number(b.opponentId);
    if (opp !== null && !Number.isInteger(opp)) throw new HttpError(400, "opponentId: a number or null (skip)");
    await env.DB.prepare(
      `INSERT INTO session_opponents (session_id, opponent_id, answered_utc) VALUES (?, ?, ?)
       ON CONFLICT(session_id) DO UPDATE SET opponent_id = excluded.opponent_id, answered_utc = excluded.answered_utc`,
    ).bind(p[1], opp, now()).run();
    return json({ ok: true });
  }
  if (m === "GET" && p[0] === "opponents" && p.length === 2) {
    need(req, env, "read");
    const id = Number(p[1]);
    const o: any = await env.DB.prepare("SELECT id, name FROM opponents WHERE id = ?").bind(id).first();
    if (!o) throw new HttpError(404, "no such opponent");
    const s = await env.DB.prepare(
      `SELECT s.id, s.start_utc AS startUtc, s.headline, s.shot_count AS shots
         FROM session_opponents so JOIN sessions s ON s.id = so.session_id
        WHERE so.opponent_id = ? AND s.status = 'ready' ORDER BY s.start_utc DESC`).bind(id).all();
    const st = await env.DB.prepare(
      `SELECT t.session_id AS sessionId, t.player, t.shot_type AS shotType, t.metric, t.median, t.iqr, t.n
         FROM session_stats t JOIN session_opponents so ON so.session_id = t.session_id
        WHERE so.opponent_id = ? ORDER BY t.session_id`).bind(id).all();
    return json({ id: o.id, name: o.name, sessions: s.results, stats: st.results });
  }
  if (m === "GET" && p[0] === "identity" && p[1] === "pending" && p.length === 2) {
    need(req, env, "write");
    return pendingIdentity(env);
  }
  if (m === "POST" && p[0] === "identity" && p[2] === "applied" && p.length === 3) {
    need(req, env, "write");
    await env.DB.prepare("UPDATE identity_answers SET applied = 1 WHERE id = ?").bind(Number(p[1])).run();
    return json({ ok: true });
  }
  throw new HttpError(404, "not found");
}

// ---------- auth ----------
function need(req: Request, env: Env, kind: "read" | "write"): void {
  const h = req.headers.get("Authorization") ?? "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  const want = kind === "write" ? env.WRITE_TOKEN : env.READ_TOKEN;
  if (!want || !same(token, want)) throw new HttpError(401, "bad token");
}

function same(a: string, b: string): boolean {
  // constant-time comparison
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

async function sign(env: Env, text: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(env.LINK_KEY),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function link(env: Env, base: URL, kind: "get" | "put", id: string, path: string): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + LINK_SECONDS;
  const sig = await sign(env, `${kind}|${id}|${path}|${exp}`);
  const u = new URL(`/sessions/${encodeURIComponent(id)}/files/${path.split("/").map(encodeURIComponent).join("/")}`, base);
  u.searchParams.set("exp", String(exp));
  u.searchParams.set("sig", sig);
  return u.toString();
}

async function checkLink(env: Env, kind: "get" | "put", id: string, path: string, url: URL): Promise<void> {
  const exp = Number(url.searchParams.get("exp"));
  if (!exp || exp < Date.now() / 1000) throw new HttpError(403, "link expired");
  const want = await sign(env, `${kind}|${id}|${path}|${exp}`);
  if (!same(url.searchParams.get("sig") ?? "", want)) throw new HttpError(403, "bad link");
}

// ---------- PC side ----------
async function createSession(env: Env, b: any): Promise<Response> {
  const id = text(b.id, "id");
  await env.DB.prepare(
    `INSERT INTO sessions (id, start_utc, court_id, mode, status, updated_utc) VALUES (?, ?, ?, ?, 'uploading', ?)
     ON CONFLICT(id) DO UPDATE SET start_utc = excluded.start_utc, court_id = excluded.court_id,
       mode = excluded.mode, updated_utc = excluded.updated_utc`,
  ).bind(id, text(b.startUtc, "startUtc"), b.court ?? null, b.mode ?? "full", now()).run();
  return json({ id });
}

async function uploadUrl(env: Env, url: URL, id: string, b: any): Promise<Response> {
  const path = safePath(text(b.path, "path"));
  const sha = text(b.sha256, "sha256").toLowerCase();
  const size = Number(b.size);
  // idempotent (TV-UP-02): the same file already stored needs no upload
  const head = await env.BUCKET.head(key(id, path));
  if (head && head.customMetadata?.sha256 === sha) return json({ exists: true });
  return json({ exists: false, url: await link(env, url, "put", id, path), multipart: size > MULTIPART_ABOVE });
}

async function putFile(env: Env, req: Request, id: string, path: string, url: URL): Promise<Response> {
  const k = key(id, path);
  const action = url.searchParams.get("action");
  const sha = (url.searchParams.get("sha256") ?? "").toLowerCase();
  if (action === "mpu-create") {
    const up = await env.BUCKET.createMultipartUpload(k, { customMetadata: { sha256: sha } });
    return json({ uploadId: up.uploadId });
  }
  if (action === "mpu-part") {
    const up = env.BUCKET.resumeMultipartUpload(k, text(url.searchParams.get("uploadId"), "uploadId"));
    const part = await up.uploadPart(Number(url.searchParams.get("part")), await req.arrayBuffer());
    return json(part);
  }
  if (action === "mpu-complete") {
    const up = env.BUCKET.resumeMultipartUpload(k, text(url.searchParams.get("uploadId"), "uploadId"));
    const b = await body(req);
    await up.complete(b.parts);
    return json({ ok: true });
  }
  const data = await req.arrayBuffer();
  const got = await sha256(data);
  if (sha && got !== sha) throw new HttpError(400, "sha256 does not match the upload");
  await env.BUCKET.put(k, data, { customMetadata: { sha256: got } });
  return json({ ok: true, sha256: got });
}

async function putData(env: Env, id: string, b: any): Promise<Response> {
  const s = b.session ?? {};
  const rallies: any[] = b.rallies ?? [];
  const shots: any[] = b.shots ?? [];
  const stats: any[] = b.stats ?? [];
  const exists = await env.DB.prepare("SELECT id FROM sessions WHERE id = ?").bind(id).first();
  if (!exists) throw new HttpError(404, "create the session first");
  // replace everything for this session at once (idempotent re-upload, TV-UP-02)
  const q: D1PreparedStatement[] = [
    env.DB.prepare("DELETE FROM rallies WHERE session_id = ?").bind(id),
    env.DB.prepare("DELETE FROM shots WHERE session_id = ?").bind(id),
    env.DB.prepare("DELETE FROM session_stats WHERE session_id = ?").bind(id),
  ];
  for (const r of rallies) {
    q.push(env.DB.prepare(
      "INSERT INTO rallies (session_id, idx, start_s, stop_s, shots, duration_s, ending, fastest) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind(id, r.index, num(r.start), num(r.stop), num(r.shots), num(r.duration), r.ending ?? null, num(r.fastest)));
  }
  for (const x of shots) {
    const cols = SHOT_COLUMNS.map(([c]) => c);
    q.push(env.DB.prepare(
      `INSERT INTO shots (session_id, ${cols.join(", ")}) VALUES (?, ${cols.map(() => "?").join(", ")})`,
    ).bind(id, ...SHOT_COLUMNS.map(([, f]) => f(x))));
  }
  for (const st of stats) {
    q.push(env.DB.prepare(
      "INSERT INTO session_stats (session_id, shot_type, metric, median, iqr, n, player) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ).bind(id, st.shotType, st.metric, num(st.median), num(st.iqr), num(st.n), st.player === "opponent" ? "opponent" : "chris"));
  }
  q.push(env.DB.prepare(
    `UPDATE sessions SET duration_s = ?, shot_count = ?, rally_count = ?, headline = ?, identity_pending = ?,
       summary_json = ?, status = ?, updated_utc = ? WHERE id = ?`,
  ).bind(num(s.durationS), shots.length, rallies.length, s.headline ?? null, s.identityPending ? 1 : 0,
    JSON.stringify(s.summary ?? null), b.complete ? "ready" : "uploading", now(), id));
  await env.DB.batch(q);
  return json({ ok: true, shots: shots.length, rallies: rallies.length });
}

async function pendingIdentity(env: Env): Promise<Response> {
  const r = await env.DB.prepare(
    "SELECT id, session_id AS sessionId, stretch, label, answered_utc AS answeredUtc FROM identity_answers WHERE applied = 0 ORDER BY id",
  ).all();
  return json(r.results);
}

// ---------- app side ----------
async function listSessions(env: Env): Promise<Response> {
  const r = await env.DB.prepare(
    `SELECT s.id, s.start_utc AS startUtc, s.court_id AS court, s.duration_s AS durationS, s.shot_count AS shots,
            s.rally_count AS rallies, s.headline, s.mode, s.identity_pending AS identityPending,
            so.opponent_id AS opponentId, o.name AS opponent, so.session_id IS NOT NULL AS opponentAnswered
       FROM sessions s LEFT JOIN session_opponents so ON so.session_id = s.id LEFT JOIN opponents o ON o.id = so.opponent_id
      WHERE s.status = 'ready' ORDER BY s.start_utc DESC`,
  ).all();
  return json(r.results);
}

async function getSession(env: Env, url: URL, id: string): Promise<Response> {
  const s: any = await env.DB.prepare("SELECT * FROM sessions WHERE id = ? AND status = 'ready'").bind(id).first();
  if (!s) throw new HttpError(404, "no such session");
  const rallies = await env.DB.prepare("SELECT * FROM rallies WHERE session_id = ? ORDER BY idx").bind(id).all();
  const listed = await env.BUCKET.list({ prefix: key(id, "") });
  const files = [];
  for (const o of listed.objects) {
    const path = o.key.slice(key(id, "").length);
    files.push({ path, size: o.size, url: await link(env, url, "get", id, path) });
  }
  return json({
    id: s.id, startUtc: s.start_utc, court: s.court_id, durationS: s.duration_s, shots: s.shot_count,
    headline: s.headline, mode: s.mode, identityPending: !!s.identity_pending,
    summary: s.summary_json ? JSON.parse(s.summary_json) : null, rallies: rallies.results, files,
  });
}

async function getShots(env: Env, id: string): Promise<Response> {
  const r = await env.DB.prepare("SELECT * FROM shots WHERE session_id = ? ORDER BY rally, idx").bind(id).all();
  return json(r.results);
}

async function getFile(env: Env, req: Request, id: string, path: string): Promise<Response> {
  const range = parseRange(req.headers.get("Range"));
  const obj = await env.BUCKET.get(key(id, safePath(path)), range ? { range } : undefined);
  if (!obj) throw new HttpError(404, "no such file");
  const h = new Headers({ "Accept-Ranges": "bytes", "Content-Type": contentType(path) });
  if (range && "offset" in range) {
    const end = range.length !== undefined ? range.offset + range.length - 1 : obj.size - 1;
    h.set("Content-Range", `bytes ${range.offset}-${end}/${obj.size}`);
    return new Response(obj.body, { status: 206, headers: h });
  }
  return new Response(obj.body, { headers: h });
}

async function trends(env: Env, url: URL): Promise<Response> {
  const metric = text(url.searchParams.get("metric"), "metric");
  const shotType = url.searchParams.get("shotType") ?? "groundstroke";
  const from = url.searchParams.get("from") ?? "0000";
  const to = url.searchParams.get("to") ?? "9999";
  // sessions waiting for "Which one is you?" stay out of trends (TV-PLY-07)
  const r = await env.DB.prepare(
    `SELECT s.id AS sessionId, s.start_utc AS startUtc, t.median, t.iqr, t.n
       FROM session_stats t JOIN sessions s ON s.id = t.session_id
      WHERE t.metric = ? AND t.shot_type = ? AND t.player = 'chris' AND s.status = 'ready' AND s.identity_pending = 0
        AND s.start_utc >= ? AND s.start_utc <= ?
      ORDER BY s.start_utc`,
  ).bind(metric, shotType, from, to).all();
  return json(r.results);
}

async function postIdentity(env: Env, id: string, b: any): Promise<Response> {
  const answers: any[] = Array.isArray(b.answers) ? b.answers : [];
  if (answers.length === 0) throw new HttpError(400, "no answers");
  const q = answers.map((a) => env.DB.prepare(
    "INSERT INTO identity_answers (session_id, stretch, label, answered_utc) VALUES (?, ?, ?, ?)",
  ).bind(id, Number(a.stretch ?? 0), text(a.label, "label"), now()));
  q.push(env.DB.prepare("UPDATE sessions SET identity_pending = 0 WHERE id = ?").bind(id));
  await env.DB.batch(q);
  return json({ ok: true });
}

// Chris, 15 Nov: for an indoor court the app sends only an indoor flag for the session. The
// body must be exactly {"indoor": true|false}: anything else (a court name, a photo) is refused,
// so it can never be stored here. The PC reruns the physics with indoor settings.
async function postConditions(env: Env, id: string, b: any): Promise<Response> {
  if (typeof b !== "object" || b === null || Object.keys(b).length !== 1 || typeof b.indoor !== "boolean") {
    throw new HttpError(400, "send only {\"indoor\": true or false}");
  }
  const s = await env.DB.prepare("SELECT id FROM sessions WHERE id = ?").bind(id).first();
  if (!s) throw new HttpError(404, "no such session");
  await env.DB.prepare("INSERT INTO session_conditions (session_id, indoor, answered_utc) VALUES (?, ?, ?)")
    .bind(id, b.indoor ? 1 : 0, now()).run();
  return json({ ok: true });
}

// ---------- detector feedback and opponents ----------
async function postChecks(env: Env, b: any): Promise<Response> {
  const items: any[] = Array.isArray(b.checks) ? b.checks : [];
  if (items.length === 0 || items.length > 200) throw new HttpError(400, "send 1 to 200 checks");
  const q = items.map((c) => env.DB.prepare(
    `INSERT INTO ball_checks (session_id, frame_ref, crop_path, pred_x, pred_y, width, height, created_utc)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(session_id, frame_ref) DO NOTHING`,
  ).bind(text(c.sessionId, "sessionId"), text(c.frameRef, "frameRef"), safePath(text(c.cropPath, "cropPath")),
    num(c.predX), num(c.predY), Number(c.width), Number(c.height), now()));
  await env.DB.batch(q);
  return json({ ok: true, count: items.length });
}

async function nextChecks(env: Env, url: URL): Promise<Response> {
  const limit = Math.min(50, Math.max(1, Number(url.searchParams.get("limit") ?? 20)));
  const r = await env.DB.prepare(
    `SELECT id, session_id AS sessionId, crop_path AS cropPath, pred_x AS predX, pred_y AS predY, width, height
       FROM ball_checks WHERE answer IS NULL ORDER BY id LIMIT ?`).bind(limit).all();
  const out = [];
  for (const c of r.results as any[]) out.push({ ...c, url: await link(env, url, "get", c.sessionId, c.cropPath) });
  return json(out);
}

async function answerCheck(env: Env, id: number, b: any): Promise<Response> {
  if (!["ok", "moved", "none"].includes(b.answer)) throw new HttpError(400, "answer: ok, moved or none");
  const x = b.answer === "moved" ? num(b.x) : null, y = b.answer === "moved" ? num(b.y) : null;
  if (b.answer === "moved" && (x === null || y === null)) throw new HttpError(400, "moved needs x and y");
  await env.DB.prepare("UPDATE ball_checks SET answer = ?, ans_x = ?, ans_y = ?, answered_utc = ? WHERE id = ?")
    .bind(b.answer, x, y, now(), id).run();
  return json({ ok: true });
}

const REASONS = ["wrong speed", "wrong call", "not my shot", "not a real shot"];

async function postFlag(env: Env, id: string, b: any): Promise<Response> {
  if (b.kind === "looks wrong") {
    if (!REASONS.includes(b.reason)) throw new HttpError(400, `reason: one of ${REASONS.join(", ")}`);
    if (!Number.isInteger(b.rally) || !Number.isInteger(b.shot)) throw new HttpError(400, "rally and shot");
    await env.DB.prepare("INSERT INTO flags (session_id, kind, rally, shot, reason, created_utc) VALUES (?, 'looks wrong', ?, ?, ?, ?)")
      .bind(id, b.rally, b.shot, b.reason, now()).run();
  } else if (b.kind === "missed shot") {
    if (num(b.t) === null) throw new HttpError(400, "t: seconds into the session");
    await env.DB.prepare("INSERT INTO flags (session_id, kind, rally, t, created_utc) VALUES (?, 'missed shot', ?, ?, ?)")
      .bind(id, Number.isInteger(b.rally) ? b.rally : null, b.t, now()).run();
  } else {
    throw new HttpError(400, "kind: 'looks wrong' or 'missed shot'");
  }
  return json({ ok: true });
}

async function listOpponents(env: Env): Promise<Response> {
  // most recently played first (then newest added); the app suggests, never the Worker
  const r = await env.DB.prepare(
    `SELECT o.id, o.name, MAX(s.start_utc) AS lastPlayed
       FROM opponents o
       LEFT JOIN session_opponents so ON so.opponent_id = o.id
       LEFT JOIN sessions s ON s.id = so.session_id
      GROUP BY o.id ORDER BY lastPlayed IS NULL, lastPlayed DESC, o.id DESC`).all();
  return json(r.results);
}

function cleanName(v: unknown): string {
  const s = typeof v === "string" ? v.trim().replace(/\s+/g, " ") : "";
  if (s.length === 0 || s.length > 60) throw new HttpError(400, "a name of 1 to 60 characters");
  return s;
}

// ---------- helpers ----------
const SHOT_COLUMNS: [string, (x: any) => unknown][] = [
  ["rally", (x) => x.rally], ["idx", (x) => x.index], ["t", (x) => num(x.t)], ["hitter", (x) => x.hitter ?? null],
  ["type", (x) => x.type ?? null], ["is_serve", (x) => (x.isServe ? 1 : 0)],
  ["speed_contact", (x) => num(x.speedContact)], ["speed_bounce", (x) => num(x.speedBounce)],
  ["speed_after", (x) => num(x.speedAfter)], ["launch_deg", (x) => num(x.launchDeg)],
  ["direction_deg", (x) => num(x.directionDeg)], ["contact_x", (x) => num(x.contact?.[0])],
  ["contact_y", (x) => num(x.contact?.[1])], ["contact_z", (x) => num(x.contact?.[2])],
  ["net_clearance", (x) => num(x.netClearance)], ["apex", (x) => num(x.apex)], ["flight_time", (x) => num(x.flightTime)],
  ["bounce_x", (x) => num(x.bounce?.[0])], ["bounce_y", (x) => num(x.bounce?.[1])], ["bounce_sd", (x) => num(x.bounceSd)],
  ["depth", (x) => num(x.depth)], ["call", (x) => x.call ?? null], ["margin", (x) => num(x.margin)],
  ["spin_effect", (x) => num(x.spinEffect)], ["spin_effect_net", (x) => num(x.spinEffectNet)],
  ["spin_top", (x) => num(x.spinTop)], ["spin_side", (x) => num(x.spinSide)], ["rpm", (x) => num(x.rpm)],
  ["rpm_sd", (x) => num(x.rpmSd)], ["spin_label", (x) => x.spinLabel ?? null], ["kick_angle", (x) => num(x.kickAngleDeg)],
  ["speed_ratio", (x) => num(x.speedRatio)], ["cd", (x) => num(x.CD)], ["fit_rms", (x) => num(x.fitRmsPx)],
  ["confidence", (x) => num(x.confidence)],
];

function key(id: string, path: string): string {
  return `sessions/${id}/${path}`;
}

function safePath(p: string): string {
  if (p.split("/").some((s) => s === ".." || s === "") || p.startsWith("/")) throw new HttpError(400, "bad path");
  return p;
}

function num(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function text(v: unknown, name: string): string {
  if (typeof v !== "string" || v.length === 0) throw new HttpError(400, `missing ${name}`);
  return v;
}

async function body(req: Request): Promise<any> {
  try {
    return await req.json();
  } catch {
    throw new HttpError(400, "body is not JSON");
  }
}

async function sha256(data: ArrayBuffer): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function parseRange(h: string | null): { offset: number; length?: number } | undefined {
  const m = h?.match(/^bytes=(\d+)-(\d*)$/);
  if (!m) return undefined;
  const offset = Number(m[1]);
  return m[2] ? { offset, length: Number(m[2]) - offset + 1 } : { offset };
}

function contentType(p: string): string {
  if (p.endsWith(".mp4")) return "video/mp4";
  if (p.endsWith(".json")) return "application/json";
  if (p.endsWith(".gz")) return "application/gzip";
  if (p.endsWith(".png")) return "image/png";
  if (p.endsWith(".jpg")) return "image/jpeg";
  return "application/octet-stream";
}

function now(): string {
  return new Date().toISOString();
}

function json(v: unknown, status = 200): Response {
  return new Response(JSON.stringify(v), { status, headers: { "Content-Type": "application/json" } });
}
