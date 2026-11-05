# Fix 1: reading a package photo on the phone

Release: _added once CI publishes it_ (tag `fix-1`).

## The bug

From Chris's screenshot (6 Nov, v0.6.9): **read again** on a package photo said *"Couldn't read it: Attempt to read from field 'dt5 fs5.a' on a null object reference…"*. "Retry with Claude" worked.

## Cause

The release build is shrunk (R8): unused code is removed and the rest renamed to short names. That renamed and merged classes inside ML Kit, Google's text-reading library, which looks up some of its own parts by class while running. One lookup came back empty, hence the crash. Debug builds aren't shrunk, which is why the unit and screenshot tests passed.

## Reproduced, then fixed

- New hand-started CI check, **Text reading check**: builds the release exactly as shrunk but for the x86_64 emulator, starts an emulator, and has the app read a bundled sample package with ML Kit.
- Before the fix it failed with Chris's exact message: `FAIL java.lang.NullPointerException: Attempt to read from field 'dt5 fs5.a' on a null object reference in method 'java.lang.Object r.t(java.lang.Object)'`.
- Fix: ML Kit is kept out of shrinking (four keep rules; the APK grows about 0.6 MB).
- After the fix: CHECK_RESULT
- Every release build now also fails if shrinking renames any ML Kit class.

The sample image and the self-test exist only in the check build, not in the release.

## Test steps for Chris

1. Install this release.
2. Open a racquet → **strings** → the **camera** tile (or a restring's **take photo**), and photograph the D-Toro Spin package again.
3. The fields should fill in from the phone's own reading. If something is wrong, **retry with Claude** still works.
