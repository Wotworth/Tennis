# Tennis Vision: user manual

**The single place for everything Chris does by hand.** It is updated whenever a requirement changes. Where a step depends on a decision not yet made, it says **TBD** and what it waits for.

Version: 16 Nov 2026 (first edition). It replaces `docs/DAY-ONE.md` and `docs/CLOUDFLARE-SETUP.md`, whose steps are now sections 2.1 and 2.3.

Contents:
1. Shopping list
2. One-time setup: 2.1 closet PC · 2.2 Tailscale · 2.3 Cloudflare · 2.4 the app
3. Camera settings
4. Checkerboard lens calibration
5. Camera time sync
6. Camera placement
7. Before every session
8. During the session
9. After every session
10. Labelling
11. Reading the results
12. Troubleshooting
13. Court-day quick reference
14. Preliminary single-camera test (HERO7 Black + ball machine)
15. iPhone match footage: the earliest pipeline test

---

## 1. Shopping list

**Cameras and recording**

| Item | Spec | Status |
|---|---|---|
| 2 × GoPro MISSION 1 PRO | Fixed-lens model (not the ILS); records 4K120 and 4K240 | ordered |
| 3 × 512 GB microSD | From GoPro's tested-card list for the MISSION 1, V30 or faster | to buy |
| 2 × USB-C power banks | 20,000 mAh or more, with USB-C PD output; one per camera for 2+ hours | to buy |
| 2 × USB-C cables | 1 m, right-angle ends if possible | to buy |
| 2 × fence clamps | A clamp mount for chain-link fence, with a GoPro mount on a ball head that locks | to buy |
| 2 × light stands (only if the side fence is more than 7 m from the doubles sideline) | Reaches 3.5 m, with sandbags | only if needed (section 6) |
| 1 × magenta cap | Solid magenta, no logo in yellow or green | to buy |
| 1 × tape measure | 30 m, for checking court and post dimensions once | to buy |

**Calibration**

| Item | Spec |
|---|---|
| Checkerboard | 10 × 7 squares, 40 mm each (board 400 × 280 mm). Printed matte on A3 paper, glued flat on rigid board (5 mm foam board or aluminium composite), flat to within 1 mm. Or buy a ready-made rigid matte target of the same size. See section 4. |
| A tripod or a stable shelf | To hold each camera still while you move the board. |

**Closet PC** (bought: Lenovo Legion Tower 5i Gen 10)

| Item | Spec |
|---|---|
| 12 TB archive drive | 3.5-inch SATA hard drive. Plus a powered USB-C enclosure, if the PC has no 3.5-inch bay (section 2.1, step 3). |
| 2 × microSD readers | USB 3 (5 Gbps), single slot: one USB-A, one USB-C |
| HDMI dummy plug | 4K-capable, for Remote Desktop without a monitor |
| USB status light | blink(1) mk3, plus a 1 m USB-A extension |
| UPS (optional) | 600 VA or more, so a short power cut doesn't stop processing |
| Day-one only | A monitor or TV with HDMI, a USB keyboard and mouse (borrowed is fine), an Ethernet cable, an empty microSD card |
| Windows 11 Pro upgrade | About $99, from the Microsoft Store |

**Software and services**

| Item | Cost |
|---|---|
| MATLAB Home with Image Processing, Computer Vision, Optimization, Statistics and Machine Learning, Signal Processing, Deep Learning, Parallel Computing | $214 a year (Home Suite plus Computer Vision) |
| Cloudflare (Workers, D1, R2) | Free plan to start; Workers Paid $5 a month once real sessions arrive |
| Tailscale | Free personal plan |
| ntfy app on the phone | Free |

**Optional validation gear:** a radar gun, to check measured speeds.

---

## 2. One-time setup

### 2.1 Closet PC
Steps marked **(PC)** need the monitor and keyboard. Everything after step 16 is done from the tablet over Remote Desktop.

1. **(PC) Place the PC** where it will live in the closet, with space behind it. Leave the closet door open while it processes.
2. **(PC) Screen and keyboard.**
   - HDMI into the **graphics card**: its ports run horizontally, low on the back.
   - Keyboard and mouse into two black **USB 2.0** ports on the back.
   - Ethernet, then power.
3. **(PC, unplugged) Check for a 3.5-inch bay.** Remove the side panel (two screws at the back) and look at the bottom front for a drive cage with a tray. Write down whether there is one.
4. **(PC) Fit the archive drive.**
   - **Bay:** screw the drive into the tray, connect the SATA data and power cables, and put the panel back.
   - **No bay:** put the drive in the powered enclosure, on the **back USB-C 20 Gbps port**.
   - Don't format it yet.

   Where everything plugs in:

   | Thing | Port |
   |---|---|
   | Card reader 1 (USB-A) | top, USB-A 5 Gbps |
   | Card reader 2 (USB-C) | top, USB-C 5 Gbps |
   | Archive drive (if USB) | back, USB-C 20 Gbps |
   | Status light | back, USB 2.0, on the 1 m extension |
   | Keyboard, mouse (day one) | back, USB 2.0 |

   If a reader is ever on a USB 2.0 port, your phone gets "Slow card reader". The import still finishes, slower.
5. **(PC) First start.** Follow Windows' setup. Then:
   - Settings > Accounts > Other users > Add account > "I don't have this person's sign-in information" > "Add a user without a Microsoft account";
   - user **tennis**, with a password you note down;
   - make it an Administrator.
6. **(PC) Updates.**
   - Windows Update until nothing is left.
   - Then **Lenovo Legion Space**: install its updates, including the BIOS.
7. **(PC) Windows 11 Pro.** Settings > System > Activation > Upgrade your edition. Buy Pro (about $99). This must come before Remote Desktop: Home cannot be reached by it.
8. **(PC) Lighting off.** Legion Space > Lighting > all off.
9. **(PC) Power on after a power cut.** Restart, press F2 for the BIOS, set "After Power Loss" (or "AC Power Recovery") to **Power On**, then F10 to save.
10. **(PC) Sign in as tennis** from now on.
11. **(PC) NVIDIA driver.** Install the NVIDIA App from nvidia.com. Let it install the current driver for the RTX 5070 Ti, then restart.
12. **(PC) MATLAB.**
    - Install it with the toolboxes in section 1.
    - Start it once to activate, then close it.
13. **(PC) The code.**
    - github.com/Wotworth/Tennis > Code > Download ZIP.
    - Extract it so that `C:\TennisVision\code\vision` exists.
14. **(PC) Format the archive drive.** It must be the new, empty 12 TB drive: formatting erases it.
    - Right-click Start > Disk Management > initialise as GPT.
    - New Simple Volume, full size, letter **D**, NTFS, label `TV Archive`.
15. **(PC) Run the setup script.**
    - Right-click Start > **Terminal (Admin)**, and paste:

      ```
      Set-ExecutionPolicy -Scope Process Bypass -Force; & C:\TennisVision\code\vision\setup\Setup-ClosetPC.ps1 -InstallTools
      ```

    - It sets:
      - power, AutoPlay and update hours;
      - installs FFmpeg, Git, Tailscale and LibreHardwareMonitor;
      - checks Windows is Pro, turns on Remote Desktop and checks D:;
      - sets the 200 W graphics-card limit at every log-on;
      - starts the temperature sensors at log-on;
      - makes the config files.
    - If it warns about something, fix it and run the same line again: it is safe to repeat.
    - Open LibreHardwareMonitor once and tick "Start minimized" and "Minimize to tray".
16. **Remote access.**
    1. **(PC)** Sign in to Tailscale (section 2.2).
    2. **(PC)** Install **Autologon** (Sysinternals) from the Microsoft Store. Enter the tennis user and password.
    3. **(Tablet)** In the Windows App, add the PC by its Tailscale name, user `tennis`. Connect once.
    4. **(PC)** Swap the HDMI cable for the **HDMI dummy plug**, and unplug the keyboard and mouse.
17. **(Tablet) Phone alerts.**
    - On the PC, open `C:\TennisVision\code\vision\config\secrets.local.json` in Notepad and copy the `ntfyTopic` value.
    - In the ntfy app on your phone, subscribe to it.
18. **(Tablet) Your settings.** Open `C:\TennisVision\code\vision\config\tennisvision.json`:
    - your home ZIP code;
    - `pc` > `archiveConnection`: `internal` or `usb`;
    - camera serials stay empty until the cameras arrive.
19. **(Tablet) Status light.**
    - Put `blink1-tool.exe` (from the blink(1) GitHub releases page) in `C:\TennisVision\tools`.
    - Plug the light into a back USB 2.0 port on the extension, beside the readers.
20. **(Tablet) Benchmark, within the return window.**
    - Start MATLAB and type:

      ```
      cd C:\TennisVision\code\vision; addpath(pwd, 'tools'); benchmarkPC
      ```

    - Leave it for 1–2 hours. Your phone gets "Benchmark done", with the hours a 2-hour session would take in each capture mode.
    - **Keep the PC** if 4K120 with the 200 W limit is within 12 hours, and the peak temperatures stay under 90 °C (CPU) and 80 °C (GPU). Otherwise send me `C:\TennisVision\benchmark\benchmark.md`.
21. **(Tablet) Start the watcher.** Restart the PC. It signs in by itself, and your phone gets "Watcher started".
22. **(Tablet) Test card.**
    - Put the empty microSD card in reader 1.
    - In MATLAB, run `makeTestCard('E:')`, using the card's letter.
    - Take the card out and put it back.
23. **Watch the import.**
    - Your phone gets "New camera", then "Import started … 6 files", then "Cards safe to remove".
    - The light goes blue while copying, then green.
24. **Check it.** `D:\TennisVision\raw\<today>\C3509999000001` has six files, and the card's `DCIM\100GOPRO` folder is empty. That is the first verified import.
25. When the cameras arrive, put their serials in `tennisvision.json` (step 18).

### 2.2 Tailscale (all your devices)
Tailscale makes a private network between your own devices. The PC is never on the public internet.

1. Make a Tailscale account at tailscale.com (personal plan), with the same sign-in you'll use everywhere.
2. **PC:** the setup script installs it. Open Tailscale from the Start menu and sign in.
3. **Tablet:** install Tailscale from the Play Store, sign in, turn it on.
4. **Phone:** the same.
5. **Laptop (if any):** the same, from tailscale.com/download.
6. Check: in the Tailscale app on the tablet, the PC shows as connected.
7. In the Tailscale admin page (login.tailscale.com > Machines), turn off key expiry for the PC, so it never drops off.
8. **Never** turn on "Funnel": that would publish the PC.

### 2.3 Cloudflare (when the cloud service is deployed, TV-PH-4)
1. Sign in at dash.cloudflare.com. Workers & Pages > copy the **Account ID**.
2. Profile > My Profile > API Tokens > Create Token > Create Custom Token:
   - name `tennis-vision-deploy`;
   - permissions, each "Account": **Workers Scripts: Edit**, **D1: Edit**, **Workers R2 Storage: Edit**;
   - Account Resources: Include > your account;
   - Zone Resources: empty;
   - IP filtering: empty;
   - TTL: one year.
3. Create it, and **copy the token now**: it is shown once.
4. github.com/Wotworth/Tennis > Settings > Secrets and variables > Actions. Add two secrets:
   - `CLOUDFLARE_API_TOKEN` (the token);
   - `CLOUDFLARE_ACCOUNT_ID`.
5. Tell me. The next session deploys.

### 2.4 The app
- Install the latest release APK from github.com/Wotworth/Tennis/releases on the phone.
- Settings: set your birth year (heart-rate zones), and your racquets and restrings in the library.
- **TBD:** the "Training" tab and the court-session racquet log come with Parts B and F, once approved.

---

## 3. Camera settings (both MISSION 1 PRO cameras identical)

| Setting | Value | Why |
|---|---|---|
| Resolution and frame rate | **4K120, 16:9** to start. TBD: the final mode is chosen at the end of TV-PH-2 from processing time and the error budget; 4K240 passes the speed target in simulation. | More frames per flight, sharper speed and spin |
| Lens (field of view) | **Wide**. Never SuperView (it stretches the picture). | Covers the whole court; its distortion is calibrated |
| Stabilisation | **HyperSmooth off, Horizon Lock off** | Stabilisation moves and warps the picture frame by frame, which would break the calibration |
| Shutter | **1/1920 s** (Protune) | A sharp ball, little smear |
| ISO | Auto, maximum 1600 | |
| White balance | 5500 K | Same colours every session, for the ball detector |
| Colour | Natural, not Log | |
| Bitrate | High | |
| GPS | On | Session time and place |
| Audio | On (not used for measuring; kept for the reel) | |
| Auto power-off | Off | |
| Screens | Dim after 1 minute | Battery and heat |

**How to set them:**
- On each camera, make one custom preset named `TENNIS` with all of the above, and lock it.
- TBD: the exact menu names on the MISSION 1 PRO. GoPro's manual couldn't be reached from my session; I'll add them once you confirm the menus on the camera, or once I can read the manual.
- Every recording must use this preset: a recording in any other mode has no matching lens calibration, and waits (section 12).

---

## 4. Checkerboard lens calibration (once per camera, per settings preset)

**What it is for.** Every lens bends straight lines, a wide GoPro lens a lot. The PC needs each camera's exact bending (focal length, image centre, distortion) to turn pixels into directions. You measure it once, off the court, by filming a checkerboard whose squares are known to be exactly straight and equal.

### 4.1 Equipment
- **The board:**
  - 10 × 7 squares (one side even, one side odd, so the software can tell which way up it is), each 40 mm, so 400 × 280 mm overall;
  - printed on **matte** paper by a laser printer or a print shop, at 100% scale (measure a square afterwards: 40 mm ± 0.5 mm);
  - glued with spray adhesive, without bubbles, onto **rigid flat** board: 5 mm foam board, or aluminium composite (best);
  - **flat to within 1 mm**: lay a straight edge across it in both directions; no light under it;
  - matte, not glossy: shiny paper or lamination reflects light and hides corners;
  - leave a white border of at least one square around the pattern.
- A tripod or a steady shelf for the camera.
- A sticker on each camera: **CAM 1** and **CAM 2**. Write each one's serial number (on the camera, and in the GoPro app) on a card.

### 4.2 Camera settings
- Use **exactly** the `TENNIS` preset you play with: same resolution, frame rate, lens mode and stabilisation (off).
- **Why:** the camera crops and scales the sensor differently in each mode. A calibration from another mode is simply wrong for your footage. If you ever play in another mode (e.g. 4K240), calibrate that mode too.

### 4.3 Video, not stills
- Record **video** in the playing preset. GoPro photos use a different crop and processing, so they would calibrate a different picture.
- **Move the board, not the camera.** The camera sits still on the tripod or shelf, at about chest height.
- **Move slowly:** hold each pose for about a second, then move smoothly to the next. Fast movement blurs the corners. The PC picks the sharp, well-spread frames itself.
- About **90 seconds** of video per camera.

### 4.4 Number of views and coverage
- The PC needs at least **40 good views**. 90 seconds of slow, varied poses gives 60–80.
- **Cover the whole picture, especially the corners and edges**, where the GoPro's distortion is strongest. Think of the picture as a 3 × 3 grid: put the board in each of the 9 squares, both near and far.
  - **Near:** board fills about half the picture, about 0.5 m away.
  - **Far:** board fills about a sixth, about 1.2 m away.
- **Tilts:** for each position, tilt the board up to about 40° left, right, up and down, and turn it a little.
- **The whole board must be in view** in each pose (all 10 × 7 squares). Slide it into the corners until its edge almost touches the picture edge.

### 4.5 Lighting
- Indoors by a big window on an overcast day, or outdoors in open shade.
- **No direct sun on the board:** it causes glare and hard shadows.
- No shadow of you or the camera across the board.
- Bright enough that the camera's fast shutter (1/1920) doesn't make the picture grainy. If it looks dark, move nearer the window.

### 4.6 Each camera on its own
1. Mount CAM 1 on the tripod. Turn it on, and check the `TENNIS` preset is selected.
2. Press record. Hold up the card showing "CAM 1" and its serial for 3 seconds.
3. Do the poses (4.4), about 90 seconds.
4. Stop.
5. Repeat for CAM 2, with its own card.

Each camera's card stays in that camera, so its footage stays its own. The PC also reads the serial from the file.

### 4.7 Submitting it and the result
1. Put each camera's microSD card into a reader on the closet PC, as after a session.
2. The PC recognises a checkerboard clip by itself and calibrates that camera and preset.
3. Within about 15 minutes your phone gets either:
   - **"Camera 1 calibrated for 4K120 Wide: 0.31 px, passed"**; or
   - **"Camera 1 calibration failed"**, with the reason.

**Pass:**
- the reprojection error, how far the fitted lens model puts the corners from where they are in the picture, is **0.5 px or less**;
- at least 40 views;
- all 9 parts of the picture covered.

**If it fails:**
- "too few views" or "corners not covered": record again, spending more time in the named corners;
- "error 0.8 px": the board may not be flat, or the frames blurred. Check flatness, move slower, use more light;
- "no board found": check the board is fully in view, and matte.

### 4.8 Checklist
- [ ] Board flat, matte, 40 mm squares measured
- [ ] `TENNIS` preset on, stabilisation off
- [ ] Camera still, on a tripod
- [ ] Soft even light, no glare
- [ ] Card with CAM number and serial shown at the start
- [ ] 90 s, slow, all 9 areas near and far, tilts, corners
- [ ] Repeat for the other camera
- [ ] Cards into the PC; wait for "passed"

---

## 5. Camera time sync

**What you do:** GoPro's **Timecode Sync**, in the Quik app, before every session. GoPro's manual (quoted; see Part D for what I could and couldn't confirm) describes it like this:
1. Turn on both cameras.
2. In the GoPro Quik app, open the camera control screen and tap **Sync Timecode**. A QR code appears.
3. Point each camera at the QR code, in any mode. The camera confirms the sync.

**Rules:**
- Redo it **every time a camera is switched off and on** (power cycle).
- Do it **just before** pressing record. GoPro warns it drifts after 60–90 minutes switched on.
- Keep both cameras on the same preset (same frame rate).

**What it gives:** the cameras agree to within a few frames. The PC then finds the exact timing itself from the ball's flights (Part D), so a slightly off sync doesn't spoil the session. Forgetting it entirely only makes the PC search longer.

**Start-of-session ball drop:** TBD, proposed in Part D (section 7 of this manual describes it, if approved).

---

## 6. Camera placement

**Layout** (from the placement check, `docs/reports/TV-PH-0a.md`):
- Both cameras on the **same side** of the court, one at each end, mirror images of each other.
- Measure your side fence's distance from the doubles sideline, and use that row:

| Side fence from the doubles sideline | Mount | Where along the fence | Height | Frame | Aim |
|---|---|---|---|---|---|
| 2 m | fence | 1.5 m behind each baseline | 3.0 m | 4:3 Open Gate | 25° toward the net, 15° down |
| 3 m | fence | 1.0 m behind each baseline | 3.5 m | 16:9 | 25° toward the net, 22° down |
| 4 m | fence | level with each baseline | 3.5 m | 16:9 | 22° toward the net, 12° down |
| 5 m | fence | 0.5 m in from each baseline | 3.0 m | 16:9 | 22° toward the net, 4° down |
| 6 m | fence | 2.0 m in from each baseline | 3.5 m | 16:9 | 18° toward the net, level |
| 7 m | fence | 2.5 m in from each baseline | 3.5 m | 16:9 | 18° toward the net, 1° up |
| 8 m or more | light stand 5 m from the sideline | 0.5 m in from each baseline | 3.0 m | 16:9 | 22° toward the net, 4° down |

Back-fence corners (layout 2) also work; see the report.

**What must be in each camera's picture:**
- all court lines, including both baselines and the far sideline;
- the area 3 m behind each baseline;
- **both net posts, base to top** (Part C, if approved).

**Checking the framing before playing:**
1. Open the GoPro Quik app's live view for each camera.
2. Check the far baseline corners are inside the picture with a little margin.
3. Check both net posts are fully visible, with nothing hanging on them. If something is (towel, scorekeeper), move it if you can. The PC rejects an obstructed post and uses the lines only.
4. Lock the clamp's ball head firmly. A camera that moves during play splits the session's calibration.

---

## 7. Before every session (checklist)
1. **Batteries:** both cameras charged; power banks charged and connected.
2. **Cards:** each camera has an empty card, at least 2 hours' free (about 220 GB at 4K120 High). The PC empties cards after a verified import.
3. **Settings:** the `TENNIS` preset selected on both cameras (section 3).
4. **Mount and frame** both cameras (section 6), and check the live view.
5. **Racquet:** in the app, start the court session and pick the racquet you're starting with. TBD: comes with Part F.
6. **Sync:** Timecode Sync in Quik (section 5), right before recording.
7. **Record** on both cameras.
8. **Ball drop:** TBD, if approved (Part D).
   - From about 2 m (arm raised), drop a ball on the centre service line T, in view of both cameras.
   - Step back and let it bounce 2–3 times.
   - Takes 10 seconds.
9. **Magenta cap:** wear it for at least the **first 10 minutes** (the warm-up) (TV-PLY-03). The system learns your clothes and height from it, then keeps track of you. Still the agreed method. If both players are dressed alike, wear it longer.
10. Don't stand in front of the net posts while the cameras start. The PC uses the first quiet minute to see the court.

---

## 8. During the session
- Play. Nothing else is needed.
- **Switching racquets** (TBD: comes with Part F):
  1. At a changeover, tap **Switched racquet** in the app or on the launcher tile.
  2. Tap the racquet you picked up.
  3. Optionally tap a reason: strings felt flat, broke a string, other.

  A rough time is fine: the PC moves the switch to the nearest break between points, so no point is split between racquets. "Broke a string" also goes into that racquet's string history, for how long strings last.
- If a camera falls or is knocked, re-aim it. The PC notices and recalibrates from that moment.

---

## 9. After every session
1. Stop recording on both cameras. Take out the cards.
2. At home, put the cards into the closet PC's two readers (either card in either reader).
3. **What happens by itself:**
   - your phone gets "Import started";
   - the light goes blue while copying;
   - the files are copied, checked by fingerprint (SHA-256) and archived on D:;
   - only then are the cards wiped;
   - phone: **"Cards safe to remove"**, and the light goes green.
4. **Processing** starts when the PC is free. Up to **12 hours** for a 2-hour session, 6 hours being the goal. The day-one benchmark gives the real figure for your PC.
5. **When it's done,** the session appears in the app (Sessions), and your phone gets a message. If it fails, the message says why (section 12), and the light goes red.
6. **Racquet switches:** open the session > racquets > review. You can move a switch to another break, change a racquet or reason, add a switch you forgot, or delete a wrong one. Each rally shows its first frame, so you can see which racquet you held. If a tap fell mid-point and was a close call, the app asks "before or after this rally?" once. TBD: comes with Part F.
7. If the app asks "Which one is you?", tap your picture. If it asks "Who did you play?", pick your opponent.

---

## 10. Labelling (TBD: comes with Part B, once approved)
- **Phone:** the Training tab. Each prompt shows the full picture with the candidate circled, above a zoomed crop.
  - Swipe right = Yes (the ball in play on your court), swipe left = No.
  - Buttons for Ball elsewhere, No ball in frame, Skip, Undo.
  - After a No, an optional reason: ball on ground, neighbouring court, ball machine/basket, other object, motion blur.
- **Tablet or laptop:** open the PC's Training page in the browser (its Tailscale address; works only with Tailscale on).
  - Keys: Y, N, E (elsewhere), 0 (no ball), S (skip), U (undo), ← → step frames, Space loop, 1–5 reason tags.
- **Offline:** on Wi-Fi the phone downloads the next batch. Label anywhere; it sends the labels when it reconnects.
- A batch is 50 by default, a few minutes' work. You can start on the phone and finish on the laptop.

---

## 11. Reading the results
- **Summary:** shots, rallies, your top serve, the longest rally, per-player lines, and the court and camera-angle notes.
- **Court map:** each bounce as a dot, coloured by speed or by spin effect. Tap one for that shot.
- **Shot card:**
  - speed at contact and at the bounce;
  - launch angle, net clearance, highest point;
  - the call and the bounce's distance inside the baseline, with its ± uncertainty;
  - **spin effect**: how much shorter (topspin) or longer (slice) the ball landed than the same shot without spin;
  - spin rate as a range;
  - measurement confidence.
- **Line calls** within the bounce's uncertainty say "too close", not in or out.
- **Rallies, 3D, health and trends:** described on each page.
- **Racquets and strings** (TBD, Part F):
  - the session's racquets row shows which rallies used which racquet;
  - Trends can group by racquet, string setup or hours on the strings, to see whether spin and depth fall as strings go flat;
  - the racquet's page shows string breaks and the hours they lasted.
- **Fatigue** (TBD, Part F), on the health page:
  - serve speed, depth, placement spread and in-percentage per quarter of the session;
  - after long rallies against after short ones;
  - by heart-rate zone.
  - Heart rate never leaves the phone.
- **Warnings** and what they mean:
  - "**weak camera angle** in …": the two cameras see that part of the court from nearly the same direction, so positions there are less certain.
  - "**poorly calibrated** (camera 2: far baseline 3.4 px)": positions and speeds are less certain this session. Usually a camera moved or the view was blocked. TBD: comes with Part C.
  - "**height reference: left post ✗ top obstructed**": that post wasn't used. Calibration is still fine from the lines. TBD: comes with Part C.
  - "**timing uncertain** in …": the two cameras' timing check failed for part of the session, so speeds there are greyed out. TBD: comes with Part D.
  - "**N detections left out**": balls, people and stray objects from other courts and elsewhere, with the reasons (section 12).

---

## 12. Troubleshooting

| What you see | What it means | What to do |
|---|---|---|
| "Waiting for lens calibration: camera 2, 4K240 Wide" | A camera recorded in a preset with no calibration | Check the camera's preset. If you meant to use that mode, calibrate it (section 4); the session then processes by itself. |
| "Poorly calibrated" | The court lines or posts didn't fit well: camera moved, lines worn, view blocked | Check the clamp. Next time, check the framing (section 6). The session's results stay, marked less certain. |
| "Left post: top obstructed" | Something on the post, or someone in front | Nothing needed. Next time, clear the post if you can. |
| "Timing uncertain" | Camera timing check failed | Redo Timecode Sync before recording next time. If it keeps happening, tell me. |
| "Slow card reader" | A reader is on a USB 2.0 port | Move it to a top port. |
| "Import failed: copy did not match" | A file didn't copy cleanly | Leave the card in the reader; the PC retries. The card is never wiped unless every file checked. |
| Session missing frames / "dropped frames at 41:20" | The camera skipped frames | Nothing; timing uses each frame's own time stamp. If it's frequent, check the card is on GoPro's list. |
| Forgot to tap a racquet switch | Shots after the switch show the old racquet | Session > racquets > review > add the switch before the right rally (TBD, Part F). |
| Forgot to pick the starting racquet | The app uses the racquet of your logged session at that time, or asks once | Answer the question, or correct it in review. |
| Broke a string but didn't log the reason | The break isn't in the string history | Review > tap the switch > reason "broke a string". |
| Forgot Timecode Sync | The PC searches wider for timing | Nothing; it still works. Do it next time. |
| Light red, phone says "processing failed" | The message gives the stage and reason | Send me the message, or the crash log from the app's diagnostics. |
| "Too hot: pausing" | The PC paused to cool | Open the closet door; it resumes by itself. |

---

## 13. Court day: quick reference

**Before:**
- [ ] Cameras charged, power banks charged, cables
- [ ] Empty cards in both cameras
- [ ] `TENNIS` preset on both
- [ ] Clamps, magenta cap
- [ ] Mount both cameras (table in section 6); lines, posts and back areas in view; heads locked
- [ ] App: start the session, pick the starting racquet (TBD, Part F)
- [ ] Quik: Timecode Sync, both cameras
- [ ] Record on both
- [ ] Ball drop at the T (TBD, Part D)
- [ ] Cap on for the first 10 minutes

**During:**
- [ ] Racquet switch: Switched racquet > new racquet > reason (TBD, Part F)

**After:**
- [ ] Stop both cameras, take the cards home
- [ ] Cards into the PC's readers; wait for "Cards safe to remove"
- [ ] Results in the app when done; answer any question it asks

---

## 14. Preliminary single-camera test: GoPro HERO7 Black and a ball machine

**Purpose:** test the ball detector and bounce finding on real footage early, before the closet PC and the MISSION 1 PRO cameras arrive.

- **One camera** means no stereo: no true 3D, no camera sync, no spin rate.
- **What it does test:**
  - the detector and tracker on real light and backgrounds;
  - bounce positions on the ground;
  - a rough launch speed from the known machine position;
  - topspin against backspin.
- It runs in **MATLAB Online**, as agreed in principle on 16 Nov. The single-camera script is not written yet.
- **TBD before the test:**
  - (a) your answer on the capture mode;
  - (b) whether a radar gun is available;
  - (c) whether your MATLAB licence includes the full MATLAB Online.

### 14.1 HERO7 settings
1. **Mode:** Video, **1080p, 120 fps** (TBD: recommended. 2.7K120 is sharper, but it records only in HEVC, and MATLAB Online may not read it. Decide after the step 14.6 check).
2. **Video compression:** Preferences > Video Compression > **Most Compatible (H.264)**. This is needed for 1080p120 in H.264. 2.7K120 and 1080p240 are HEVC only.
3. **Field of view:** **Linear** if the camera offers it at 1080p120 (less distortion); otherwise **Wide**. Never SuperView.
4. **Stabilisation:** **HyperSmooth off.**
5. **Protune on:**
   - shutter at the fastest offered at 120 fps (1/1920 if listed, else 1/960);
   - white balance 5500 K;
   - ISO max 1600;
   - colour GoPro (not Flat);
   - sharpness Medium.
6. **Audio:** on (not used).
7. **GPS:** on.

Note on screen exactly which mode, FOV and shutter you used: the calibration must match.

### 14.2 Lens calibration for the HERO7
**Yes, needed:** the PC has no lens model for the HERO7. Follow section 4 with these changes:
- the HERO7's settings from 14.1 (same mode, FOV, stabilisation off);
- only one camera;
- upload the 90-second clip with the test footage (14.7), named `H7_calib.MP4`.

The pass test is the same (≤ 0.5 px).

### 14.3 Camera placement
- **Where:** where camera 1 will go: on your side fence, at the end of the court nearest you, at the spot and height in the section 6 table for your fence distance.
  - Typically level with the baseline at 3–3.5 m high, turned about 22° toward the net and tilted down about 12°.
  - With no fence clamp yet, a tall tripod at the same spot.
- **What must be in view:**
  - the whole court, all lines;
  - both net posts, base to top;
  - 3 m behind each baseline.
- **Measure and note:**
  - the camera's height above the ground;
  - its distance from the nearest doubles sideline and from the baseline line.

  The PC finds the position from the lines, and these are a check.

### 14.4 Ball machine
- **Placement:** behind the **far baseline**, centre, about 1 m behind it. Measure its launch point's distance from the baseline and from the centre mark, and the launch height, to ±2 cm.
- **Target:** the near half, deep. Put **5 tape crosses** where the balls land (e.g. deep middle, deep left, deep right, mid-court left and right). Measure each cross's position from the lines: distance in from the baseline and from the sideline.
- **Settings:** 3 speeds (slow, medium, fast) × 3 spins (none, top, back) = 9 blocks.
  - Feed one ball every 3–4 seconds.
  - **15 balls per block**, about 1 minute each, so about 10 minutes of balls.
- **Before each block,** hold a card to the camera for 3 seconds with the block's setting, e.g. "FAST · TOP · 6/4" (the machine's dial readings).

### 14.5 Hitting or not
1. **Blocks 1–9: let them pass.** Nobody hits. Clean flights from a known point are what this test measures.
2. **Block 10 (optional, 3 minutes):** stand on the near baseline and hit forehands back crosscourt. This tests the tracker with a player in view and a hit. Wear the magenta cap, as practice for the real sessions; it isn't needed for this test.

### 14.6 Light, time of day, and a first check
- **Light:**
  - aim for **overcast**, or **sun high and behind or beside the camera** (late morning);
  - **avoid** low sun shining into the lens, and the time when the net's or fence's shadow cuts across the target area. Some shadow elsewhere is fine and useful.
- **First, a 10-second check** (a day before if possible):
  - record 10 s in the chosen mode;
  - upload it to MATLAB Drive and run the check script I'll give you;
  - it says whether MATLAB Online can read the file. This settles the 2.7K question.

### 14.7 At the start of recording
- **Ball drop:**
  - Drop a ball from about 2 m at the **centre of the near service line T**, in view.
  - One camera can measure it there, because the spot is known.
  - It checks scale and frame timing (gravity, 9.81 m/s² ± 1%).
- **No clap** (not useful with one camera).

### 14.8 Files
- On the phone: GoPro Quik > the camera > download the clips to the phone. Keep the original names (GX01xxxx.MP4).
- In MATLAB Drive (app or drive.matlab.com), make a folder `TennisVision/hero7/2026-MM-DD/` and upload:
  - the clips;
  - `H7_calib.MP4`;
  - a text note `notes.txt` with:
    - camera height and distances;
    - machine position and launch height;
    - the 5 crosses' positions;
    - the mode, FOV and shutter used;
    - the blocks' settings in order.
- Clips are about 0.5 GB per minute at 1080p120. TBD: your MATLAB Drive space (5 GB without the full licence, 20 GB with) may need the clips uploaded in two goes.

### 14.9 What it measures and what counts as a pass (preliminary)

| Measure | Pass |
|---|---|
| Ball found in flight frames | ≥ 90% of the frames where the ball is in the air |
| Bounce position vs the nearest tape cross, for balls landing within 30 cm of one | median ≤ 10 cm (one camera; the two-camera target is 5 cm) |
| Gravity from the ball drop | 9.81 m/s² ± 1% |
| Topspin vs backspin from the machine's spin blocks | right kind for ≥ 90% of balls |
| Launch speed | No pass mark without a radar gun; reported per block against the machine's dial |

**If the detector struggles:**
- the script saves the frames where it missed or doubted;
- you look at them as a picture grid;
- I retune the detector's colour and size settings from them;
- a second short session confirms.

### 14.10 Test-day checklist
- [ ] HERO7: 1080p120, Most Compatible, Linear (or Wide), HyperSmooth off, Protune shutter fast, 5500 K
- [ ] 10-second check clip read in MATLAB Online (beforehand)
- [ ] Checkerboard clip for the HERO7 (90 s, same settings)
- [ ] Camera at the camera-1 spot, all lines, both posts and back areas in view; height and distances noted
- [ ] Machine behind the far baseline; position and launch height measured
- [ ] 5 tape crosses placed and measured
- [ ] Record; ball drop at the near T
- [ ] 9 blocks × 15 balls, setting card before each
- [ ] Optional block 10: hit forehands back
- [ ] Upload clips, calibration clip and notes.txt to MATLAB Drive

---

## 15. iPhone match footage: the earliest pipeline test

**Purpose:** a first look at real footage of a real match, filmed by iPhone from behind the baseline, before any GoPro or the closet PC.
- **One camera,** so like section 14: detection, tracking and bounce positions on the ground, not true 3D or spin rate.
- **Private:** the footage shows you and your opponent.
  - It **never goes into the GitHub repository**, which is public. `.gitignore` blocks video files and footage folders.
  - It is **never processed in GitHub's test machines**, whose logs anyone can read.
  - It is processed only in my private session's machine.
  - Reports in the repository give numbers only, never pictures from it.

### 15.1 Check the file on the iPhone first
1. Photos > the video > swipe up (or tap ⓘ). Note:
   - the size (e.g. 4.2 GB);
   - the resolution and frame rate (e.g. 4K · 60 fps);
   - the length;
   - HEVC or H.264.
2. Send me those four things. They decide the route in 15.3.
3. Don't trim or edit it in Photos: an edited copy is re-encoded. I can cut parts out losslessly on my side.

### 15.2 Get the original off the iPhone without re-compressing
1. Photos > the video > **Share**.
2. At the top of the share sheet, tap **Options**.
   - Turn **All Photos Data** on (it keeps the original file and its metadata: time, location, frame timing).
   - If it shows **Format**, choose **Current** (keeps HEVC as recorded). **Never "Most Compatible"**: that re-encodes to H.264 and loses quality.
3. Tap **Save to Files** > **On My iPhone** > a new folder `TennisVision` > Save.
4. In Files, rename the file to the naming convention (15.4).

**Avoid:** Messages, WhatsApp, Mail, any "small / medium / actual size" choice, and social apps. They all re-compress. AirDrop to a Mac also keeps the original, but only with **All Photos Data** on; it isn't needed here.

### 15.3 Where it lives until the closet PC arrives

What my session can reach today: files you attach in our chat, and the open internet only through hosts the environment allows. Google Drive isn't connected (only Gmail and Calendar are), and Gmail can't carry videos (25 MB attachment limit).

| Option | Private? | Size | How I get it | Trade-offs |
|---|---|---|---|---|
| **A. Google Drive, folder `TennisVision/footage`, link-sharing on only while I download (recommended)** | Private, except for the minutes the link is on | 15 GB free (more with Google One) | You share a link, I allow Google Drive's download host once, then download it straight into my session's machine. You turn the link off when I say it's done. | Anyone with the link could open it during those minutes; the link is long and random, and not listed anywhere. Simple from the phone. It is also the hand-over route to the closet PC. |
| B. Attach the file in our chat | Private | Unknown limit; very likely too small for a whole match | Directly | Fine for a short clip, not for the full match. I can't confirm the limit. |
| C. A private Cloudflare R2 bucket (your account) | Fully private | Large | Needs the Cloudflare token (section 2.3) and a download key saved on the environment | Uploading from an iPhone is awkward: the dashboard takes up to 300 MB per file. Better once the cloud service is deployed. |
| D. A private GitHub repository | Private | 2 GB per file, quotas | Through the GitHub access I already have | Uploading big files from a phone is clumsy, GitHub's free storage quotas are small, and it's too close to the public repository for comfort. Not recommended. |

**Recommended: A.** Steps on the phone:
1. Install **Google Drive** from the App Store, and sign in.
2. Drive > **+** > **Folder** `TennisVision`, inside it `footage`.
3. Open `footage` > **+** > **Upload** > **Browse** > On My iPhone > `TennisVision` > the renamed file. Upload from **Files**, not from Photos, so Drive gets the untouched original.
4. Keep Drive open until the upload finishes (it can take a while on Wi-Fi). Plug in the phone.
5. **Tell me it's uploaded.** I'll then ask to allow Google Drive's download host for my session, which you approve on screen.
6. When I ask, open the file in Drive > ⋯ > **Share** > **Copy link**, with "General access: Anyone with the link · Viewer". Paste the link to me.
7. When I say the download is done and checked (I compare the size, and record its SHA-256 fingerprint), set General access back to **Restricted**.

### 15.4 File naming (all footage, now and later)

`YYYY-MM-DD_HHMM_LOCxx_CAMERA_TYPE_pNN.ext`

| Part | Meaning | Examples |
|---|---|---|
| `YYYY-MM-DD_HHMM` | Date and start time, local | `2026-11-14_1530` |
| `LOCxx` | Location code, never the court's name (court names stay on the phone) | `LOC01` your usual courts, `LOC02` the next |
| `CAMERA` | Which camera | `IPHONE`, `H7` (HERO7), `M1A`, `M1B` (the two MISSION 1 PROs) |
| `TYPE` | What it is | `MATCH`, `PRACTICE`, `MACHINE` (ball machine), `CALIB` (checkerboard), `TEST` |
| `pNN` | Part, if a recording is split | `p01`, `p02` |

Example: `2026-11-14_1530_LOC01_IPHONE_MATCH_p01.mov`.

GoPro cards imported by the closet PC keep GoPro's own names inside the archive's date and serial folders (section 9). This convention is for footage you bring in by hand.

### 15.5 What happens after you confirm
1. I download it into my session's private machine and check the size and fingerprint. Then you turn the link off.
2. I write the single-camera steps for it:
   - a lens model estimated from the court lines (no checkerboard exists for this iPhone);
   - the court's position;
   - detection and tracking;
   - bounces;
   - rough speeds.
3. I run them on my private machine.
4. The report gives numbers only, with no frames of you or your opponent. Pictures, if useful, come to you in the chat, never in the repository.
5. Nothing starts until you've confirmed the upload.

My session's machine is wiped when the session ends. Google Drive stays the master copy.

### 15.6 When the closet PC arrives
1. Over Remote Desktop, open Google Drive in the browser and download `TennisVision/footage/*` into `C:\TennisVision\inbox\`. TBD: a hand-delivered-footage inbox is part of the PC's import, to be built.
2. The PC fingerprints each file, archives it to `D:\TennisVision\raw\manual\`, and records it in the archive index. The same file is never imported twice.
3. Everything learnt from this test carries over: detector settings, and any labels you made. They live in the code and on the PC, not in my session. The PC simply reprocesses the footage with the full pipeline. Nothing has to be filmed or labelled again.
4. Keep the Drive copy as a backup until the PC's archive has it.

### 15.7 Phone checklist
- [ ] Photos > ⓘ: note size, resolution, frame rate, length; send them to me
- [ ] Share > Options: All Photos Data on, Format Current > Save to Files > On My iPhone > TennisVision
- [ ] Rename: `YYYY-MM-DD_HHMM_LOC01_IPHONE_MATCH_p01.mov`
- [ ] Google Drive > TennisVision > footage > Upload > Browse > the file
- [ ] Tell me it's uploaded; approve my request for Google Drive access
- [ ] Share link when I ask; set back to Restricted when I say it's done
