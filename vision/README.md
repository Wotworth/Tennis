# Tennis Vision (MATLAB)

The vision pipeline for the closet PC. Spec: [docs/VISION-REQUIREMENTS.md](../docs/VISION-REQUIREMENTS.md). Status: [docs/STATUS.md](../docs/STATUS.md).

- `+tv/` the MATLAB package: `tv.court` (court model), `tv.air` (air density, speed of sound), `tv.physics` (flight model, RK4), `tv.lens` (lens models), `tv.placement` (camera placement check). Later phases add ingest, calibration, sync, detection, tracking, reconstruction and upload.
- `config/placement.json`: placement check settings and the published lens angles (provisional).
- `config/tennisvision.example.json`: template for the PC's real config, which is never committed.
- `tests/`: script-based `matlab.unittest` tests; run with `runtests('vision/tests')` with `vision` on the path. GitHub runs them on every push that touches `vision/` (`.github/workflows/vision.yml`).
- `tools/placementCheck.m`: writes the placement lookup table and plots.
- `setup/Setup-ClosetPC.ps1`: one-time Windows setup (TV-ARCH-04).
