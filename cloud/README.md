# Tennis Vision cloud API

A Cloudflare Worker (`src/index.ts`) with a D1 database (`migrations/`) and an R2 bucket, as the spec's TV-API-01 to 04 describe. The closet PC writes with the write token; the tennis app reads with the read token. Heart-rate data never comes here (Chris, 15 Nov).

Routes beyond those: indoor flags (TV-API-05), ball checks, flags and opponents (Chris, 15 Nov), and court corners (TV-API-07: `/calibration`, for a session held because a camera's court-line fit is doubtful).

Tests run on every push that touches `cloud/` (`.github/workflows/cloud.yml`), against in-memory stand-ins for D1 (SQLite) and R2.

Deploying (TV-PH-4, with Chris's Cloudflare account) needs:
1. A D1 database `tennis` and an R2 bucket `tennis-sessions`; the database id goes into `wrangler.toml`.
2. Three secrets set with `wrangler secret put`: `WRITE_TOKEN`, `READ_TOKEN`, `LINK_KEY` (long random values). Never in Git.
3. `wrangler d1 migrations apply tennis --remote`, then `wrangler deploy`.
