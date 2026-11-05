# Tennis String Log

## About me

- I have no computer. I drive you from the Claude app on a tablet, read reports on GitHub, and install builds on my phone from GitHub release pages. I can't run commands, use adb or open Android Studio.
- I'm an engineer, but MATLAB is the only language I know. Ask me about behavior and looks, never about code. When you need a decision, give me two or three options in plain language, with your recommendation.
- I pay for compute. Keep each session to its task, and don't redo work that already passes.

## Rules

- docs/REQUIREMENTS.md is the source of truth, and its section 0 applies: MUST/SHOULD/COULD, requirement IDs in commits and reports, every tunable value in TennisTokens.kt, decisions logged in DECISIONS.md, and stop and ask me when a requirement conflicts with Android or with another requirement. If this file and the spec disagree, ask me.
- Start each session by reading docs/STATUS.md, then only the spec sections the task needs. Update STATUS.md (phase, done, next, open questions, known issues) each time you push and before you stop to wait for me.
- One phase at a time (section 14). Don't start a phase until I've accepted the previous one on my phone. A phase can span several sessions.
- At the start of each phase, ask me in one message about every section 16 open question the phase depends on, with its default. If I answer "defaults", use them all.
- Work on main: commit and push there (you have my permission; I don't review pull requests). CI on main builds what I install, and each new session starts from main. Push at checkpoints, not after every commit, because each push runs CI. Always push before you stop to wait for me: an idle session's computer can be reclaimed, and anything unpushed is lost.
- Before pushing, compile and run the unit and screenshot tests in the session when the environment allows it. After pushing, check the workflow run with gh api (gh pr and gh issue are blocked in cloud sessions). Never call a build ready until CI has passed and the release exists.
- If GitHub refuses a push that touches .github/workflows/, push everything else, then give me the workflow file in a code block and numbered steps to create it in GitHub's web editor.
- Never claim something works on the phone. Say what CI proved (build, unit tests, screenshots) and give me numbered steps for what only the phone can show.
- The look is the Zune player's Metro style, not Material (VIS-04 to VIS-08): no ripple effects, Material components or icons, rounded cards, shadows or floating buttons; the only colors are the green gradient and the tile green. Icons are Fluent UI System Icons (Filled), never drawn by hand without my approval (VIS-06).
- Never commit the signing key or its passwords. Never write to Health Connect, and never send health data off the phone except when I share the Health Connect report myself. The only network use is the Claude photo retry (PHO-20 to PHO-23), from PH-4 on.
- The Zune player (Wotworth/zune) is the source of the shared look; copy from it with a header naming the file and commit.
- Launcher (Wotworth/wp-launcher), Chris on 6 Nov: work on main only, as additions; don't change how existing tiles or features behave. The full existing test suite must pass before any launcher release; if an existing test would have to change or go, stop and tell Chris why instead of releasing. Publish launcher releases only from main. Record the interface in docs/LAUNCHER-REQUESTS.md.
- Bug reports: I'll paste the crash log from the app's diagnostics settings, or attach screenshots. Reproduce the bug in a test where you can, then fix it.
- Phase reports go in docs/reports/ as section 14 describes, with their images committed there so they show on GitHub. In chat, give me only the release link, numbered test steps and your questions.
