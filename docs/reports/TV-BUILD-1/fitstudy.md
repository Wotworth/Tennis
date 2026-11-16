# Fit study: the flight fit against truth it was not built from

SYNTHETIC. 366 shots in 79 rallies (90-minute singles session, 4K cameras, 0.5 px detector noise). Truth flights: ode45, spin decay (5 s), C_L following the spin parameter with 15% per-shot scatter, per-shot C_D (sd 0.024), wind gusts (about 1 m/s). The fitter assumes none of these. Run time 111 min.

| Measure | Shots | Median | 90th percentile | Target |
|---|---|---|---|---|
| Shots found (hit within 30 ms) | 361 of 366 | | | 95% (AC-06) |
| Hit time error, ms | 361 | 1.1 | 2.4 |  |
| Speed at contact error, mph | 361 | 1.56 | 3.09 | 2 mph for 90% (AC-07) |
| Bounce position error, cm | 331 | 1.6 | 2.6 | median 5 cm (AC-08) |
| Spin effect error, cm | 331 | 15.3 | 36.3 | 10 cm (AC-10) |
| Net clearance error, cm | 361 | 0.7 | 1.2 | 3-5 cm (spec estimate) |
| rpm error, % | 167 | 18 | 47 | (rpm +/-25% shown, TV-SPN-03) |
| rpm error with the true lift known, % | 167 | 13 | 28 | 10% (AC-11) |
| In / out / net calls right | 335 of 338 | | | all |
| Bounce error after a short flight (< 0.25 s to the next hit), cm | 13 | 0.9 | 3.6 |  |
| Bounce error, all other shots, cm | 318 | 1.6 | 2.6 |  |

Clock drift found 39.9 ppm (truth 40). Session timing error at mid-session: -1.43 ms. Readout time error: camera 1 -0.14 ms, camera 2 -0.71 ms. Wind found [1.9 -1] m/s (mean truth [1.5 -0.8], gusts not modelled by the fit). Session C_D 0.509.
