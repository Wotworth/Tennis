# Day one: the closet PC, from the box to the first checked card import

For the Lenovo Legion Tower 5i Gen 10 (Legion T5 30IAX10), spec TV-HW-01 to 08. Steps marked **(PC)** need a screen and keyboard at the PC. Everything after step 16 works from the tablet over Remote Desktop. Nothing here needs a command line, except two lines you copy and paste from this page.

## Before you start: what you need

- A TV or monitor with an HDMI cable, and a USB keyboard and mouse. You need them only for day one; borrowed ones are fine.
- Internet: an Ethernet cable to the router (best), or Wi-Fi.
- The 12 TB drive. If your PC has no 3.5-inch bay (step 3), you also need a powered USB-C enclosure for it.
- Two USB 3 microSD readers: one USB-A, one USB-C. The status light (blink(1)), a 1 m USB-A extension cable, and the HDMI dummy plug.
- An empty microSD card for the test import, any size.
- On your phone: the ntfy app. On the tablet: the Tailscale app and Microsoft's Windows App (for Remote Desktop).
- About 3 hours, plus 1–2 hours of unattended benchmark (step 20).

## Unbox and connect

1. **Place the PC (PC)** where it will live in the closet, with space behind it for air. Leave the closet door open while it runs (TV-HW-05).
2. **Screen and keyboard (PC).**
   - Plug the HDMI cable into the **graphics card**: its ports run horizontally, low on the back. Not the motherboard's port higher up, which shows nothing.
   - Plug the keyboard and mouse into two of the four **USB 2.0** ports on the back. Those are the black ones, without the "SS" mark.
   - Plug in the Ethernet cable, then the power cable.
3. **Does it have a 3.5-inch bay?** With the PC unplugged, remove the side panel (two screws at the back, then slide it off) and look at the bottom front.
   - A metal cage with a slide-out tray for a large drive, and a spare SATA cable, means yes.
   - No cage means no bay: use the USB enclosure.
   - Write down which, for step 14. You can also find the PC's MTM code (machine type, e.g. 90xx...) on the sticker and look it up on Lenovo's PSREF site. Its "Drive bays" line says the same.
4. **The archive drive (PC).**
   - **Bay:** screw the drive into the tray, slide it in, and connect the SATA data and power cables. Then put the side panel back.
   - **No bay:** put the drive in the enclosure, power the enclosure, and plug it into the **USB-C 20 Gbps port on the back** (the fastest; the only USB-C on the back).
   - Don't format it yet (step 14).

Where everything plugs in (TV-HW-03):

| Thing | Port | Why |
|---|---|---|
| Card reader 1 (USB-A) | top, USB-A 5 Gbps | you insert cards from above; full speed (about 90 MB/s) |
| Card reader 2 (USB-C) | top, USB-C 5 Gbps | the same, for the second card |
| Archive drive (if USB) | back, USB-C 20 Gbps | the fastest port, used by nothing else |
| Status light | back, any USB 2.0 port, on the 1 m extension | needs almost no speed; the extension puts it beside the readers |
| Keyboard, mouse (day one only) | back, USB 2.0 | |
| Spare: back USB-A 5 Gbps ×2 | — | a reader here also runs at full speed |

If a reader ever ends up on a USB 2.0 port, the PC tells your phone ("Slow card reader") and the import still finishes, just slower.

## Windows

5. **First start (PC).** Follow Windows' setup with your Microsoft account. When it is done:
   1. Go to Settings > Accounts > Other users > Add account.
   2. Choose "I don't have this person's sign-in information", then "Add a user without a Microsoft account".
   3. Make the user **tennis** with a password, and note the password.
   4. Change its account type to Administrator.
6. **Updates (PC).** Run Settings > Windows Update until nothing is left, restarting as asked. Then open **Lenovo Legion Space** and install its updates, including any BIOS update.
7. **Upgrade to Windows 11 Pro (PC).** Settings > System > Activation > Upgrade your edition of Windows. Buy Pro in the Microsoft Store (about $99) and let it restart. **This comes before Remote Desktop:** Windows 11 Home cannot be reached by Remote Desktop.
8. **Lighting off (PC).** Lenovo Legion Space > Lighting: turn all lighting off (TV-HW-06).
9. **Come back on after a power cut (PC).**
   1. Restart and press F2 repeatedly to open the BIOS.
   2. Find "After Power Loss" (it may be "AC Power Recovery", under Power or Configuration) and set it to **Power On**.
   3. Save and exit (F10).
10. **Sign in as tennis (PC)** from now on.

## Software

11. **NVIDIA driver (PC).** In Edge, go to nvidia.com, then Drivers, and install the NVIDIA App. Let it install the current Game Ready or Studio driver for the RTX 5070 Ti, then restart.
12. **MATLAB (PC).**
    1. Sign in at mathworks.com and download the installer for your Home licence. Install MATLAB with these toolboxes:
       - Image Processing, Computer Vision, Optimization, Statistics and Machine Learning;
       - Signal Processing, Deep Learning, Parallel Computing.
    2. Start MATLAB once to activate it, then close it.
13. **The code (PC).**
    1. In Edge, open github.com/Wotworth/Tennis and choose Code > Download ZIP.
    2. Extract it to `C:\TennisVision\code`, so that the folder `C:\TennisVision\code\vision` exists.
14. **Format the archive drive (PC).** It must be the new, empty 12 TB drive: formatting erases it.
    1. Right-click Start, then Disk Management. A pop-up asks to initialise the new disk: choose GPT.
    2. Right-click its unallocated space, then New Simple Volume. Use the full size, letter **D**, file system NTFS, label `TV Archive`.
    3. If D is already used by something else, change that drive's letter first. Right-click it, then "Change Drive Letter and Paths".
15. **Run the setup script (PC).**
    1. Right-click Start, then **Terminal (Admin)**.
    2. Copy this line, paste it into the window, and press Enter:

       ```
       Set-ExecutionPolicy -Scope Process Bypass -Force; & C:\TennisVision\code\vision\setup\Setup-ClosetPC.ps1 -InstallTools
       ```

    3. It sets the power options, AutoPlay, the update hours and the folders. It installs FFmpeg, Git, Tailscale and LibreHardwareMonitor, checks it is Pro, and turns Remote Desktop on. It checks D: and says whether it is internal or USB. It sets the **GPU power cap (200 W)** at every log-on and starts the temperature sensors at log-on. It makes `config\tennisvision.json` and `config\secrets.local.json`.
    4. Read what it prints. If it warns about something (for example "matlab.exe is not on PATH"), fix that and **run the same line again**: it is safe to repeat.
    5. Open LibreHardwareMonitor once from the Start menu. In Options, tick "Start minimized" and "Minimize to tray".
16. **Remote access.**
    1. **(PC)** Open Tailscale from the Start menu and sign in. Use the same account as on the tablet.
    2. **(PC)** Install **Autologon** from the Microsoft Store (Sysinternals Autologon), and enter the tennis user and its password. The PC then signs in by itself after a restart.
    3. **(Tablet)** In Tailscale, find the PC's name. In the Windows App, add a PC with that name, user `tennis` and its password. Connect once to check.
    4. **(PC)** Swap the HDMI cable for the **HDMI dummy plug**, in the same graphics card port. Unplug the keyboard and mouse. Everything from here is done from the tablet.

## From the tablet (Remote Desktop)

17. **Alerts on your phone.**
    1. On the PC, open `C:\TennisVision\code\vision\config\secrets.local.json` in Notepad and copy the `ntfyTopic` value (it starts with `tennis-`).
    2. In the ntfy app on your phone, subscribe to that topic.
18. **Your settings.** Open `C:\TennisVision\code\vision\config\tennisvision.json` in Notepad.
    - Fill in your home ZIP code.
    - Set `pc` > `archiveConnection` to `internal` or `usb`.
    - Leave the camera serials and courts as they are; they get filled in when the cameras arrive.
    - Save.
19. **The status light.**
    1. Download `blink1-tool` for Windows from the blink(1) GitHub releases page and put `blink1-tool.exe` in `C:\TennisVision\tools`.
    2. Plug the light into a back USB 2.0 port with the extension, and stand it beside the readers.
20. **The benchmark (TV-HW-08), within the return window.**
    1. Start MATLAB and type, in the Command Window:

       ```
       cd C:\TennisVision\code\vision; addpath(pwd, 'tools'); benchmarkPC
       ```

    2. Leave it for one to two hours, with the Remote Desktop window closed if you like: it keeps running. It makes synthetic 4K footage (not timed) and runs the whole pipeline three times: 4K120 with the 200 W cap, 4K120 without it, and 4K240. It logs temperatures every minute.
    3. Your phone gets "Benchmark done" with the hours for a 2-hour session in each mode.
    4. The full table is in `C:\TennisVision\benchmark\benchmark.md`; open it in Notepad. It shows each stage, the total against the 12-hour limit and the 6-hour goal, what the cap costs, and the peak CPU and GPU temperatures.
    5. **Keep the PC** if 4K120 with the cap is within 12 hours and the peaks stay under 90 °C (CPU) and 80 °C (GPU). Otherwise send me the table before the return window ends.
21. **Start the watcher.** Restart the PC from the Start menu. It signs in by itself, starts the temperature sensors, applies the GPU cap and starts the watcher. Your phone gets "Watcher started: the closet PC is ready for cards."

## The first checked card import

22. **Make a test card.**
    1. Put the empty microSD card in reader 1.
    2. In MATLAB, type (use the card's drive letter from File Explorer, e.g. E:):

       ```
       makeTestCard('E:')
       ```

    3. If MATLAB is in use by the watcher, open a second MATLAB window for this.
    4. Take the card out, wait a few seconds, and put it back in reader 1.
23. **Watch the import.** Within a minute your phone gets three alerts, and the light goes blue while copying, then green:
    - "New camera" (the test card's made-up serial);
    - "Import started: … 6 files";
    - "Cards safe to remove".
24. **Check it.** On the PC, open `D:\TennisVision\raw\<today's date>\C3509999000001`: the six files are there. The card's `DCIM\100GOPRO` folder is now empty.
    - The PC wiped only the files it had copied and checked: their SHA-256 fingerprints matched on the card, in staging and in D:. The record is `import.json` in `C:\TennisVision\staging\C3509999000001`.
    - **This is the first verified card import.**
25. **Remove the card** and keep it as a spare. The test camera's files can stay in D: or be deleted.

When the cameras arrive, their serials go into `tennisvision.json` and the TV-PH-0 steps begin: the lens calibration and the trial sessions.
