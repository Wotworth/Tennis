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

describe("court corners (Chris, 19 Nov; TV-CAL-21, 22)", () => {
  const line = [[10, 500], [900, 480]];
  const check = (cam: number, extra: object = {}) => ({
    sessionId: "held", cam, picturePath: `calibration/cam${cam}.jpg`, width: 1920, height: 1080, scale: 0.5,
    support: 0.21, reason: "lines", lines: [line], ...extra,
  });
  const taps = [[101, 903], [1805, 911], [1403, 305], [509, 301]];

  it("the PC asks about a held session, the app taps the corners, the PC pulls the answer", async () => {
    // the session is not in the list yet: it is held before processing
    expect((await call("POST", "/calibration", W, { checks: [check(1), check(2)] })).status).toBe(200);
    expect((await call("POST", "/calibration", R, { checks: [check(1)] })).status).toBe(401);   // only the PC asks
    const next: any = await (await call("GET", "/calibration/next", R)).json();
    expect(next).toHaveLength(2);
    expect(next[0]).toMatchObject({ sessionId: "held", cam: 1, width: 1920, height: 1080, support: 0.21, reason: "lines", lines: [line] });
    expect(next[0].url).toContain("calibration/cam1.jpg");
    expect(next[0].url).toContain("sig=");
    expect((await call("POST", `/calibration/${next[0].id}/answer`, R, { answer: "corners", corners: taps })).status).toBe(200);
    // one camera still open: the PC is not handed half an answer
    expect(await (await call("GET", "/calibration/answered", W)).json()).toHaveLength(0);
    expect((await call("POST", `/calibration/${next[1].id}/answer`, R, { answer: "accepted" })).status).toBe(200);
    const got: any = await (await call("GET", "/calibration/answered", W)).json();
    expect(got).toHaveLength(2);
    expect(got[0]).toMatchObject({ sessionId: "held", cam: 1, scale: 0.5, answer: "corners", corners: taps });
    expect(got[1]).toMatchObject({ cam: 2, answer: "accepted", corners: null });
    expect(await (await call("GET", "/calibration/next", R)).json()).toHaveLength(0);
    await call("POST", `/calibration/${got[0].id}/applied`, W);
    await call("POST", `/calibration/${got[1].id}/applied`, W);
    expect(await (await call("GET", "/calibration/answered", W)).json()).toHaveLength(0);
  });

  it("asking again about a camera clears its old answer", async () => {
    await call("POST", "/calibration", W, { checks: [check(1)] });
    const first: any = await (await call("GET", "/calibration/next", R)).json();
    await call("POST", `/calibration/${first[0].id}/answer`, R, { answer: "corners", corners: taps });
    await call("POST", "/calibration", W, { checks: [check(1, { reason: "taps" })] });
    const again: any = await (await call("GET", "/calibration/next", R)).json();
    expect(again).toHaveLength(1);
    expect(again[0].reason).toBe("taps");
    expect(await (await call("GET", "/calibration/answered", W)).json()).toHaveLength(0);
  });

  it("takes four corners inside the picture, or 'accepted', and nothing else", async () => {
    await call("POST", "/calibration", W, { checks: [check(1)] });
    const [c]: any = await (await call("GET", "/calibration/next", R)).json();
    const post = (b: unknown) => call("POST", `/calibration/${c.id}/answer`, R, b);
    expect((await post({ answer: "corners", corners: taps.slice(0, 3) })).status).toBe(400);          // three corners
    expect((await post({ answer: "corners", corners: [[101, 903], [1805, 911], [1403, 305], [2509, 301]] })).status).toBe(400);  // outside
    expect((await post({ answer: "corners", corners: [[101, 903], [1805, 911], [1403, 305], ["a", 1]] })).status).toBe(400);
    expect((await post({ answer: "corners", corners: taps, courtName: "home" })).status).toBe(400);    // nothing rides along
    expect((await post({ answer: "accepted", photo: "x" })).status).toBe(400);
    expect((await post({ answer: "maybe" })).status).toBe(400);
    expect((await call("POST", "/calibration/9999/answer", R, { answer: "accepted" })).status).toBe(404);
    expect((await call("POST", "/calibration", W, { checks: [check(3)] })).status).toBe(400);          // no camera 3
    expect(await (await call("GET", "/calibration/answered", W)).json()).toHaveLength(0);
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

describe("self-test (Chris, 22 Nov)", () => {
  it("with the read token, adds a ready sample session and a court-corners request with its picture", async () => {
    const realFetch = globalThis.fetch;
    const jpg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
    globalThis.fetch = (async (u: string) => u.endsWith("cam1.jpg")
      ? new Response(jpg)
      : new Response(JSON.stringify({ checks: [{ width: 1920, height: 1080, support: 0.33, lines: [[[1, 2], [3, 4]]] }] }))) as any;
    try {
      expect((await call("POST", "/selftest", W)).status).toBe(401);          // the write token is not the app's
      const r = await call("POST", "/selftest", R);
      expect(r.status).toBe(200);
      const list: any[] = await (await call("GET", "/sessions", R)).json();
      expect(list.map((s) => s.id)).toContain("selftest");
      const cal: any[] = await (await call("GET", "/calibration/next", R)).json();
      expect(cal.length).toBe(1);
      expect(cal[0].sessionId).toBe("selftest");
      expect(cal[0].url).toContain("sig=");
      const pic = await call("GET", cal[0].url);
      expect(new Uint8Array(await pic.arrayBuffer())).toEqual(jpg);
      // running it again replaces, it doesn't pile up
      await call("POST", "/selftest", R);
      expect(((await (await call("GET", "/calibration/next", R)).json()) as any[]).length).toBe(1);
    } finally {
      globalThis.fetch = realFetch;
    }
  });
});
