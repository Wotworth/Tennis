// The Worker against in-memory D1 and R2 stand-ins (TV-API-01 to 04, TV-UP-01, 02).
import { describe, it, expect, beforeEach } from "vitest";
import worker from "../src/index";
import { env as makeEnv } from "./fakes";
import { createHash } from "node:crypto";

let E: ReturnType<typeof makeEnv>;
const W = { Authorization: "Bearer write-token-for-tests" };
const R = { Authorization: "Bearer read-token-for-tests" };
const call = (method: string, path: string, headers: Record<string, string> = {}, body?: unknown) =>
  worker.fetch(new Request(path.startsWith("http") ? path : `https://api.test${path}`, {
    method, headers, body: body === undefined ? undefined : body instanceof Uint8Array ? body : JSON.stringify(body),
  }), E as any);
const sha = (b: Uint8Array) => createHash("sha256").update(b).digest("hex");

const shot = (rally: number, index: number, extra: object = {}) => ({
  rally, index, t: 2 + index, hitter: "Chris", type: "groundstroke", isServe: false, speedContact: 28.1,
  contact: [-11.9, -3.7, 1.1], bounce: [8.8, 3.0], call: "in", spinEffect: -3.8, rpm: 2100, CD: 0.51, ...extra,
});

async function readySession(id = "2026-11-14T150000Z_home", identityPending = false) {
  await call("POST", "/sessions", W, { id, startUtc: "2026-11-14T15:00:00Z", court: "home" });
  await call("PUT", `/sessions/${encodeURIComponent(id)}/data`, W, {
    session: { durationS: 3600, headline: "412 shots, forehand 58 mph", identityPending },
    rallies: [{ index: 1, start: 1, stop: 10, shots: 2, duration: 6.5, ending: "out", fastest: 30 }],
    shots: [shot(1, 1), shot(1, 2, { hitter: "Player A" })],
    stats: [{ shotType: "groundstroke", metric: "speed", median: 27, iqr: 3, n: 2 }],
    complete: true,
  });
  return id;
}

beforeEach(() => {
  E = makeEnv();
});

describe("tokens (TV-API-03)", () => {
  it("refuses a missing or wrong token, and the read token for writing", async () => {
    expect((await call("GET", "/sessions")).status).toBe(401);
    expect((await call("GET", "/sessions", { Authorization: "Bearer nope" })).status).toBe(401);
    expect((await call("POST", "/sessions", R, { id: "x", startUtc: "2026" })).status).toBe(401);
    expect((await call("GET", "/identity/pending", R)).status).toBe(401);
  });
});

describe("uploads (TV-UP-01, TV-UP-02)", () => {
  it("gives an upload link, stores the file, and skips the same file next time", async () => {
    await call("POST", "/sessions", W, { id: "s1", startUtc: "2026-11-14T15:00:00Z" });
    const data = new TextEncoder().encode("reel bytes");
    const a: any = await (await call("POST", "/sessions/s1/upload-url", W, { path: "reel_1080p.mp4", sha256: sha(data), size: data.length })).json();
    expect(a.exists).toBe(false);
    expect(a.multipart).toBe(false);
    const put = await call("PUT", `${a.url}&sha256=${sha(data)}`, {}, data);
    expect(put.status).toBe(200);
    const b: any = await (await call("POST", "/sessions/s1/upload-url", W, { path: "reel_1080p.mp4", sha256: sha(data), size: data.length })).json();
    expect(b.exists).toBe(true);
  });

  it("refuses an upload whose bytes do not match the hash, and a tampered link", async () => {
    await call("POST", "/sessions", W, { id: "s1", startUtc: "2026-11-14T15:00:00Z" });
    const a: any = await (await call("POST", "/sessions/s1/upload-url", W, { path: "a.json", sha256: "00", size: 3 })).json();
    expect((await call("PUT", `${a.url}&sha256=${"0".repeat(64)}`, {}, new Uint8Array([1, 2, 3]))).status).toBe(400);
    expect((await call("PUT", a.url.replace("a.json", "b.json"), {}, new Uint8Array([1]))).status).toBe(403);
  });

  it("uses multipart above 100 MB and joins the parts", async () => {
    await call("POST", "/sessions", W, { id: "s1", startUtc: "2026-11-14T15:00:00Z" });
    const a: any = await (await call("POST", "/sessions/s1/upload-url", W, { path: "trajectories.json.gz", sha256: "ab", size: 150e6 })).json();
    expect(a.multipart).toBe(true);
    const c: any = await (await call("PUT", `${a.url}&action=mpu-create&sha256=ab`, {}, new Uint8Array())).json();
    await call("PUT", `${a.url}&action=mpu-part&uploadId=${c.uploadId}&part=1`, {}, new Uint8Array([1, 2]));
    await call("PUT", `${a.url}&action=mpu-part&uploadId=${c.uploadId}&part=2`, {}, new Uint8Array([3]));
    await call("PUT", `${a.url}&action=mpu-complete&uploadId=${c.uploadId}`, {}, { parts: [{ partNumber: 1, etag: "e1" }, { partNumber: 2, etag: "e2" }] });
    const obj = await (E.BUCKET as any).get("sessions/s1/trajectories.json.gz");
    expect([...obj.body]).toEqual([1, 2, 3]);
  });

  it("refuses paths that climb out of the session", async () => {
    await call("POST", "/sessions", W, { id: "s1", startUtc: "2026-11-14T15:00:00Z" });
    expect((await call("POST", "/sessions/s1/upload-url", W, { path: "../other/x", sha256: "a", size: 1 })).status).toBe(400);
  });
});

describe("sessions for the app (TV-API-01, TV-APP-01)", () => {
  it("shows a session only once its upload is complete", async () => {
    await call("POST", "/sessions", W, { id: "s1", startUtc: "2026-11-14T15:00:00Z" });
    await call("PUT", "/sessions/s1/data", W, { session: {}, rallies: [], shots: [], complete: false });
    expect(await (await call("GET", "/sessions", R)).json()).toEqual([]);
    const id = await readySession();
    const list: any = await (await call("GET", "/sessions", R)).json();
    expect(list.map((s: any) => s.id)).toEqual([id]);
    expect(list[0].headline).toBe("412 shots, forehand 58 mph");
    expect(list[0].shots).toBe(2);
  });

  it("re-uploading replaces the rows instead of adding to them", async () => {
    const id = await readySession();
    await readySession(id);
    const shots: any = await (await call("GET", `/sessions/${encodeURIComponent(id)}/shots`, R)).json();
    expect(shots.length).toBe(2);
    expect(shots[0].speed_contact).toBeCloseTo(28.1);
    expect(shots[1].hitter).toBe("Player A");
  });

  it("lists a session's files with links that play, including byte ranges for seeking", async () => {
    const id = await readySession();
    const data = new TextEncoder().encode("0123456789");
    const a: any = await (await call("POST", `/sessions/${encodeURIComponent(id)}/upload-url`, W, { path: "clips/rally_01.mp4", sha256: sha(data), size: 10 })).json();
    await call("PUT", a.url, {}, data);
    const s: any = await (await call("GET", `/sessions/${encodeURIComponent(id)}`, R)).json();
    expect(s.files[0].path).toBe("clips/rally_01.mp4");
    const part = await call("GET", s.files[0].url, { Range: "bytes=2-5" });
    expect(part.status).toBe(206);
    expect(await part.text()).toBe("2345");
    expect(part.headers.get("Content-Range")).toBe("bytes 2-5/10");
  });
});

describe("trends (TV-API-01, TV-APP-06)", () => {
  it("reads the PC's per-session figures and leaves out sessions waiting for an identity answer", async () => {
    await readySession("a");
    await readySession("b", true);
    const t: any = await (await call("GET", "/trends?metric=speed&shotType=groundstroke", R)).json();
    expect(t.map((r: any) => r.sessionId)).toEqual(["a"]);
    expect(t[0].median).toBe(27);
  });
});

describe("Which one is you? (TV-API-04, TV-PLY-07)", () => {
  it("stores the app's answer; the PC fetches it and marks it applied", async () => {
    await readySession("b", true);
    expect((await call("POST", "/sessions/b/identity", R, { answers: [{ stretch: 0, label: "Player B" }] })).status).toBe(200);
    const pending: any = await (await call("GET", "/identity/pending", W)).json();
    expect(pending).toHaveLength(1);
    expect(pending[0].label).toBe("Player B");
    await call("POST", `/identity/${pending[0].id}/applied`, W);
    expect(await (await call("GET", "/identity/pending", W)).json()).toEqual([]);
    const t: any = await (await call("GET", "/trends?metric=speed", R)).json();
    expect(t.map((r: any) => r.sessionId)).toEqual(["b"]);
  });
});

describe("no health data (Chris, 15 Nov)", () => {
  it("has no health endpoint", async () => {
    await readySession("a");
    expect((await call("POST", "/sessions/a/health", W, { avgHr: 140 })).status).toBe(404);
  });
});

describe("indoor flag (Chris, 15 Nov)", () => {
  it("takes only an indoor flag from the app; the PC fetches it and marks it applied", async () => {
    await readySession("a");
    expect((await call("POST", "/sessions/a/conditions", R, { indoor: true })).status).toBe(200);
    const pending: any = await (await call("GET", "/conditions/pending", W)).json();
    expect(pending).toHaveLength(1);
    expect(pending[0]).toMatchObject({ sessionId: "a", indoor: true });
    await call("POST", `/conditions/${pending[0].id}/applied`, W);
    expect(await (await call("GET", "/conditions/pending", W)).json()).toEqual([]);
  });

  it("refuses a court name, a photo or anything else alongside the flag", async () => {
    await readySession("a");
    expect((await call("POST", "/sessions/a/conditions", R, { indoor: true, name: "Reynolds Field Court 1" })).status).toBe(400);
    expect((await call("POST", "/sessions/a/conditions", R, { indoor: "yes" })).status).toBe(400);
    expect((await call("POST", "/sessions/a/conditions", R, { photo: "abc" })).status).toBe(400);
    expect((await call("POST", "/sessions/nope/conditions", R, { indoor: true })).status).toBe(404);
    expect((await call("GET", "/conditions/pending", R)).status).toBe(401);
  });
});

describe("ball checks (Chris, 15 Nov)", () => {
  it("the PC posts crops, the app answers one at a time, the PC pulls the answers", async () => {
    await readySession("a");
    const checks = [1, 2, 3].map((i) => ({ sessionId: "a", frameRef: `c1-f${i}`, cropPath: `checks/c1-f${i}.jpg`, predX: 128, predY: 120, width: 256, height: 256 }));
    expect((await call("POST", "/checks", W, { checks })).status).toBe(200);
    await call("POST", "/checks", W, { checks });                               // re-sent: no duplicates
    const next: any = await (await call("GET", "/checks/next?limit=20", R)).json();
    expect(next).toHaveLength(3);
    expect(next[0].url).toContain("sig=");
    await call("POST", `/checks/${next[0].id}/answer`, R, { answer: "ok" });
    await call("POST", `/checks/${next[1].id}/answer`, R, { answer: "moved", x: 140, y: 101 });
    await call("POST", `/checks/${next[2].id}/answer`, R, { answer: "none" });
    expect((await call("POST", `/checks/${next[2].id}/answer`, R, { answer: "moved" })).status).toBe(400);
    const got: any = await (await call("GET", "/checks/answered", W)).json();
    expect(got.map((c: any) => c.answer)).toEqual(["ok", "moved", "none"]);
    expect(got[1]).toMatchObject({ ansX: 140, ansY: 101 });
    await call("POST", `/checks/${got[0].id}/applied`, W);
    expect(await (await call("GET", "/checks/answered", W)).json()).toHaveLength(2);
    expect(await (await call("GET", "/checks/waiting", R)).json()).toHaveLength(0);
  });
});

describe("flags (Chris, 15 Nov)", () => {
  it("logs 'looks wrong' with a reason and 'missed shot' with a time; the PC lists and closes them", async () => {
    await readySession("a");
    expect((await call("POST", "/sessions/a/flags", R, { kind: "looks wrong", rally: 3, shot: 2, reason: "wrong speed" })).status).toBe(200);
    expect((await call("POST", "/sessions/a/flags", R, { kind: "looks wrong", rally: 3, shot: 2, reason: "bad vibes" })).status).toBe(400);
    expect((await call("POST", "/sessions/a/flags", R, { kind: "missed shot", rally: 4, t: 812.4 })).status).toBe(200);
    const open: any = await (await call("GET", "/flags?status=open", W)).json();
    expect(open.map((f: any) => f.kind)).toEqual(["looks wrong", "missed shot"]);
    await call("POST", `/flags/${open[1].id}/status`, W, { status: "applied", note: "added shot at 812.6 s" });
    expect(await (await call("GET", "/flags?status=open", W)).json()).toHaveLength(1);
  });
});

describe("opponents (Chris, 15 Nov)", () => {
  it("adds, picks for a session, renames, merges and deletes; most recently played first", async () => {
    await readySession("s1");
    const a: any = await (await call("POST", "/opponents", R, { name: "  Test   Opponent One " })).json();
    const b: any = await (await call("POST", "/opponents", R, { name: "Test Opponent Two" })).json();
    expect(a.name).toBe("Test Opponent One");
    await call("POST", "/sessions/s1/opponent", R, { opponentId: a.id });
    let list: any = await (await call("GET", "/opponents", R)).json();
    expect(list[0].id).toBe(a.id);                                            // played most recently
    const sessions: any = await (await call("GET", "/sessions", R)).json();
    expect(sessions[0].opponent).toBe("Test Opponent One");
    await call("PUT", `/opponents/${a.id}`, R, { name: "Test Opponent 1" });
    expect((await (await call("GET", "/sessions", R)).json() as any)[0].opponent).toBe("Test Opponent 1");
    await call("POST", `/opponents/${a.id}/merge`, R, { into: b.id });         // a duplicate of b
    expect((await (await call("GET", "/sessions", R)).json() as any)[0].opponentId).toBe(b.id);
    const page: any = await (await call("GET", `/opponents/${b.id}`, R)).json();
    expect(page.sessions.map((s: any) => s.id)).toEqual(["s1"]);
    await call("DELETE", `/opponents/${b.id}`, R);
    list = await (await call("GET", "/opponents", R)).json();
    expect(list).toEqual([]);
    expect((await (await call("GET", "/sessions", R)).json() as any)[0].opponentId).toBeNull();
  });

  it("'skip / unknown' is an answer too, and a blank name is refused", async () => {
    await readySession("s1");
    await call("POST", "/sessions/s1/opponent", R, { opponentId: null });
    const s: any = await (await call("GET", "/sessions", R)).json();
    expect(s[0].opponentAnswered).toBe(1);
    expect((await call("POST", "/opponents", R, { name: "   " })).status).toBe(400);
  });

  it("opponent figures never enter Chris's trends", async () => {
    await call("POST", "/sessions", W, { id: "x", startUtc: "2026-11-14T15:00:00Z" });
    await call("PUT", "/sessions/x/data", W, { session: {}, rallies: [], shots: [], complete: true,
      stats: [{ shotType: "forehand", metric: "speed", median: 27, iqr: 1, n: 5, player: "chris" },
              { shotType: "forehand", metric: "speed", median: 31, iqr: 1, n: 5, player: "opponent" }] });
    const t: any = await (await call("GET", "/trends?metric=speed&shotType=forehand", R)).json();
    expect(t.map((r: any) => r.median)).toEqual([27]);
  });
});
