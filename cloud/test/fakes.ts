// Stand-ins for Cloudflare's D1 (SQLite, through Node's built-in node:sqlite) and R2 (a Map),
// with the parts of their APIs the Worker uses. The schema is the real migration file.
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";

class Stmt {
  constructor(private db: DatabaseSync, private sql: string, private args: unknown[] = []) {}
  bind(...args: unknown[]) {
    return new Stmt(this.db, this.sql, args);
  }
  run() {
    this.db.prepare(this.sql).run(...(this.args as any[]));
    return Promise.resolve({ success: true });
  }
  all() {
    return Promise.resolve({ results: this.db.prepare(this.sql).all(...(this.args as any[])) });
  }
  first() {
    return Promise.resolve(this.db.prepare(this.sql).get(...(this.args as any[])) ?? null);
  }
  runSync() {
    this.db.prepare(this.sql).run(...(this.args as any[]));
  }
}

export class FakeD1 {
  db = new DatabaseSync(":memory:");
  constructor() {
    for (const m of ["0001_init.sql", "0002_conditions.sql"]) {
      this.db.exec(readFileSync(new URL(`../migrations/${m}`, import.meta.url), "utf8"));
    }
  }
  prepare(sql: string) {
    return new Stmt(this.db, sql);
  }
  async batch(stmts: Stmt[]) {
    // D1 runs a batch as one transaction
    this.db.exec("BEGIN");
    try {
      for (const s of stmts) s.runSync();
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return stmts.map(() => ({ success: true }));
  }
}

type Obj = { data: Uint8Array; customMetadata: Record<string, string> };

export class FakeR2 {
  objects = new Map<string, Obj>();
  uploads = new Map<string, { key: string; meta: Record<string, string>; parts: Map<number, Uint8Array> }>();
  async put(key: string, data: ArrayBuffer, opts?: { customMetadata?: Record<string, string> }) {
    this.objects.set(key, { data: new Uint8Array(data), customMetadata: opts?.customMetadata ?? {} });
    return { key };
  }
  async head(key: string) {
    const o = this.objects.get(key);
    return o ? { key, size: o.data.length, customMetadata: o.customMetadata } : null;
  }
  async get(key: string, opts?: { range?: { offset: number; length?: number } }) {
    const o = this.objects.get(key);
    if (!o) return null;
    let d = o.data;
    if (opts?.range) d = d.slice(opts.range.offset, opts.range.length ? opts.range.offset + opts.range.length : undefined);
    return { key, size: o.data.length, body: d, customMetadata: o.customMetadata };
  }
  async list(opts: { prefix: string }) {
    const objects = [...this.objects.entries()]
      .filter(([k]) => k.startsWith(opts.prefix))
      .map(([k, o]) => ({ key: k, size: o.data.length }));
    return { objects };
  }
  async createMultipartUpload(key: string, opts?: { customMetadata?: Record<string, string> }) {
    const uploadId = `up-${this.uploads.size + 1}`;
    this.uploads.set(uploadId, { key, meta: opts?.customMetadata ?? {}, parts: new Map() });
    return { uploadId, key };
  }
  resumeMultipartUpload(key: string, uploadId: string) {
    const up = this.uploads.get(uploadId)!;
    return {
      uploadPart: async (n: number, data: ArrayBuffer) => {
        up.parts.set(n, new Uint8Array(data));
        return { partNumber: n, etag: `etag-${n}` };
      },
      complete: async (parts: { partNumber: number }[]) => {
        const chunks = parts.map((p) => up.parts.get(p.partNumber)!);
        const all = new Uint8Array(chunks.reduce((a, c) => a + c.length, 0));
        let o = 0;
        for (const c of chunks) {
          all.set(c, o);
          o += c.length;
        }
        this.objects.set(key, { data: all, customMetadata: up.meta });
        return { key };
      },
    };
  }
}

export function env() {
  return {
    DB: new FakeD1() as any,
    BUCKET: new FakeR2() as any,
    WRITE_TOKEN: "write-token-for-tests",
    READ_TOKEN: "read-token-for-tests",
    LINK_KEY: "link-key-for-tests",
  };
}
