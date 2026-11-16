<#
.SYNOPSIS
  One-time Windows 11 Pro setup for the Tennis Vision closet PC (TV-ARCH-04, "Closet PC setup" steps 3-5, 7, 9).
  The PC (Chris, 16 Nov): Lenovo Legion Tower 5i Gen 10 (Legion T5 30IAX10), Core Ultra 7 255HX,
  RTX 5070 Ti 16 GB, 32 GB RAM, 1 TB NVMe as C:, the 12 TB archive as D: (3.5-inch bay or USB).
  Follow docs/DAY-ONE.md; this script is its step "run the setup script".

.DESCRIPTION
  Run once, as administrator, after Chris has done steps 1-2 (Windows 11 Pro with a local
  account "tennis"; BIOS "Restore on AC power loss" = Power On). Each step prints what it
  changes. Safe to run again: every step sets a value rather than adding to it.
  Run with -WhatIf first to see the changes without making them.

  Not done here, on purpose:
  - Auto-login (step 3): it needs the account password. Use Sysinternals Autologon, which
    stores it encrypted (LSA secret), not this script.
  - Installing the NVIDIA driver and MATLAB (step 6): their installers and licences are
    interactive. With -InstallTools the script installs FFmpeg, Git and Tailscale through winget.
  - Tailscale sign-in (step 8): it opens a browser.
  - The at-log-on watcher task is created only when tv.watch exists (TV-PH-1). Until then this
    script skips it and says so.

  UNTESTED until it runs on the PC: written in a Linux cloud session with no Windows to try it on.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$User = 'tennis',
  [string]$VisionFolder = 'C:\TennisVision\code\vision',
  [string]$ArchiveDrive = 'D:',
  [int]$UpdateRestartHour = 14,  # Windows Update may restart only around this hour (the pipeline runs overnight)
  [switch]$InstallTools,          # also install FFmpeg, Git, Tailscale and LibreHardwareMonitor with winget
  [int]$GpuPowerCapW = 0           # 0: read pc.gpuPowerCapW from config/tennisvision.json (default 200 W)
)
$ErrorActionPreference = 'Stop'
function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }

# Step 4: power. Never sleep or hibernate; disks and USB stay awake (card readers must not drop mid-copy).
Step 'Power: never sleep, no hibernate, USB selective suspend off, disks never spin down'
if ($PSCmdlet.ShouldProcess('active power plan', 'set timeouts')) {
  powercfg /change standby-timeout-ac 0
  powercfg /change hibernate-timeout-ac 0
  powercfg /change disk-timeout-ac 0
  powercfg /change monitor-timeout-ac 10
  powercfg /hibernate off
  # USB selective suspend: subgroup 2a737441-..., setting 48e6b7a6-...; 0 = disabled
  powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
  powercfg /setactive SCHEME_CURRENT
}

# Step 5: AutoPlay off for removable drives, so no dialogs pile up on a screen nobody sees.
Step 'AutoPlay off for all drives'
$ap = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
if ($PSCmdlet.ShouldProcess($ap, 'NoDriveTypeAutoRun = 0xFF')) {
  New-Item -Path $ap -Force | Out-Null
  Set-ItemProperty -Path $ap -Name NoDriveTypeAutoRun -Type DWord -Value 0xFF
  Set-ItemProperty -Path $ap -Name NoAutorun -Type DWord -Value 1
}

# Step 4: Windows Update restarts only in a daytime window, never overnight while processing.
Step "Windows Update: active hours set so restarts fall near $($UpdateRestartHour):00"
$wu = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
if ($PSCmdlet.ShouldProcess($wu, 'active hours')) {
  New-Item -Path $wu -Force | Out-Null
  # Active hours (no restarts) may span at most 18 h, so restarts can happen only in the
  # 6 h around the restart hour: for 14:00, active 17:00-11:00, restarts 11:00-17:00.
  $start = ($UpdateRestartHour + 3) % 24
  $end   = ($UpdateRestartHour + 21) % 24
  Set-ItemProperty -Path $wu -Name ActiveHoursStart -Type DWord -Value $start
  Set-ItemProperty -Path $wu -Name ActiveHoursEnd   -Type DWord -Value $end
  Set-ItemProperty -Path $wu -Name SmartActiveHoursState -Type DWord -Value 0
}

# Step 7: folders. C: working files; D: raw archive.
Step 'Folders'
foreach ($f in @('C:\TennisVision\staging', 'C:\TennisVision\sessions', 'C:\TennisVision\logs', "$ArchiveDrive\TennisVision\raw")) {
  if (-not (Test-Path $f) -and $PSCmdlet.ShouldProcess($f, 'create')) { New-Item -ItemType Directory -Path $f | Out-Null }
  Write-Host "  $f"
}

# Step 6 (part): command-line tools, if asked for.
if ($InstallTools) {
  Step 'Tools: FFmpeg, Git, Tailscale, LibreHardwareMonitor (winget)'
  foreach ($id in @('Gyan.FFmpeg', 'Git.Git', 'Tailscale.Tailscale', 'LibreHardwareMonitor.LibreHardwareMonitor')) {
    if ($PSCmdlet.ShouldProcess($id, 'winget install')) {
      winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    }
  }
}

# Windows edition: Remote Desktop needs Pro (Chris upgrades Home to Pro on day one, DAY-ONE.md).
$edition = (Get-CimInstance Win32_OperatingSystem).Caption
Step "Windows edition: $edition"
$isPro = $edition -match 'Pro|Enterprise|Education'
if (-not $isPro) { Write-Warning 'This is Windows 11 Home: Remote Desktop cannot be switched on. Upgrade to Pro first (DAY-ONE.md), then run this script again.' }

# Archive drive D: (Chris, 16 Nov): the 12 TB drive, in the 3.5-inch bay or over USB. Never formatted here.
Step "Archive drive $ArchiveDrive"
$vol = Get-Volume -DriveLetter $ArchiveDrive.TrimEnd(':') -ErrorAction SilentlyContinue
if (-not $vol) {
  Write-Warning "No $ArchiveDrive drive. Fit the 12 TB drive (bay or USB 5 Gbps port), then in Disk Management give it the letter D and format it NTFS (DAY-ONE.md)."
} else {
  $part = Get-Partition -DriveLetter $ArchiveDrive.TrimEnd(':')
  $disk = Get-Disk -Number $part.DiskNumber
  Write-Host ("  {0:N1} TB, {1}, connected by {2}" -f ($vol.Size / 1TB), $vol.FileSystem, $disk.BusType)
  if ($vol.FileSystem -ne 'NTFS') { Write-Warning "  $ArchiveDrive is not NTFS: reformat it in Disk Management (it should be empty)." }
  if ($disk.BusType -eq 'USB') { Write-Host '  over USB: keep it on the 20 Gbps USB-C port on the back (or a 5 Gbps one), never a USB 2.0 port.' }
}

# GPU power cap (Chris, 16 Nov): nvidia-smi -pl needs administrator rights, so two scheduled tasks
# run it with highest privileges: one at every log-on (the cap), one on demand without the cap
# (tools/benchmarkPC.m starts it, then the capped one again, to measure what the cap costs).
Step 'GPU power cap at every log-on'
$cfgFile = Join-Path $VisionFolder 'config\tennisvision.json'
if ($GpuPowerCapW -le 0) {
  $GpuPowerCapW = 200
  if (Test-Path $cfgFile) { $j = Get-Content $cfgFile -Raw | ConvertFrom-Json; if ($j.pc -and $j.pc.gpuPowerCapW) { $GpuPowerCapW = [int]$j.pc.gpuPowerCapW } }
}
$smi = (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue).Source
if (-not $smi) { Write-Warning '  nvidia-smi is not on PATH: install the NVIDIA driver, then run this script again.' }
elseif ($PSCmdlet.ShouldProcess("GPU power limit $GpuPowerCapW W", 'register scheduled tasks')) {
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  $cap = New-ScheduledTaskAction -Execute $smi -Argument "-pl $GpuPowerCapW"
  Register-ScheduledTask -TaskName 'TennisVision GPU cap' -Action $cap -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
  $max = [int][double](& $smi --query-gpu=power.default_limit --format=csv,noheader,nounits)
  $uncap = New-ScheduledTaskAction -Execute $smi -Argument "-pl $max"
  Register-ScheduledTask -TaskName 'TennisVision GPU uncapped' -Action $uncap -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
  & $smi -pl $GpuPowerCapW | Out-Null
  Write-Host "  cap $GpuPowerCapW W now and at every log-on (the card's own default is $max W)"
}

# Temperatures (Chris, 16 Nov): Windows has no reliable CPU temperature; LibreHardwareMonitor
# publishes its sensors to WMI (root/LibreHardwareMonitor) while it runs, so it starts at log-on.
Step 'LibreHardwareMonitor at log-on (temperature sensors)'
$lhm = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles" -Filter 'LibreHardwareMonitor.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $lhm) { Write-Warning '  LibreHardwareMonitor not found: run this script with -InstallTools.' }
elseif ($PSCmdlet.ShouldProcess('LibreHardwareMonitor', 'register scheduled task')) {
  $a = New-ScheduledTaskAction -Execute $lhm.FullName
  Register-ScheduledTask -TaskName 'TennisVision sensors' -Action $a -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $User) -User $User -RunLevel Highest -Force | Out-Null
  Write-Host "  $($lhm.FullName): in its Options, tick 'Start minimized' and 'Minimize to tray' once"
}

# Step 8 (part): Remote Desktop on, through the firewall (reached over Tailscale only).
Step 'Remote Desktop on'
if ($isPro -and $PSCmdlet.ShouldProcess('Remote Desktop', 'enable')) {
  Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Type DWord -Value 0
  Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
}

# Config files that never go to Git: copied from the template once, then filled in by hand.
Step 'Config files'
$cfgDir = Join-Path $VisionFolder 'config'
$cfg = Join-Path $cfgDir 'tennisvision.json'
if (-not (Test-Path $cfg) -and (Test-Path (Join-Path $cfgDir 'tennisvision.example.json'))) {
  if ($PSCmdlet.ShouldProcess($cfg, 'create from the template')) { Copy-Item (Join-Path $cfgDir 'tennisvision.example.json') $cfg }
  Write-Host "  created ${cfg}: fill in the camera serials, courts and home location"
}
$sec = Join-Path $cfgDir 'secrets.local.json'
if (-not (Test-Path $sec)) {
  if ($PSCmdlet.ShouldProcess($sec, 'create')) {
    $topic = 'tennis-' + -join ((48..57) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
    @{ ntfyTopic = $topic; ntfyToken = ''; uploadToken = '' } | ConvertTo-Json | Set-Content -Path $sec -Encoding UTF8
  }
  Write-Host "  created ${sec} with a random ntfy topic: subscribe to it in the ntfy app on your phone"
}

# Step 3: the watcher starts at log-on, in Chris's normal user session (MATLAB licence, drives, GPU).
Step 'Watcher task at log-on'
$watch = Join-Path $VisionFolder '+tv\watch.m'
if (Test-Path $watch) {
  $matlab = (Get-Command matlab.exe -ErrorAction SilentlyContinue).Source
  if (-not $matlab) { Write-Warning 'matlab.exe is not on PATH; install MATLAB first, then run this again.' }
  elseif ($PSCmdlet.ShouldProcess('TennisVision watcher', 'register scheduled task')) {
    $action   = New-ScheduledTaskAction -Execute $matlab -Argument "-batch `"tv.watch`"" -WorkingDirectory $VisionFolder
    $trigger  = New-ScheduledTaskTrigger -AtLogOn -User $User
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'TennisVision watcher' -Action $action -Trigger $trigger -Settings $settings -User $User -RunLevel Limited -Force | Out-Null
    Write-Host '  registered: restarts within a minute if MATLAB exits'
  }
} else {
  Write-Host "  skipped: $watch does not exist yet (it arrives in TV-PH-1)"
}

Step 'Done. Still by hand (DAY-ONE.md): Autologon for the tennis account, NVIDIA driver and MATLAB, Tailscale sign-in, ntfy on the phone, and the case lighting off in Lenovo Legion Space (Lighting > Off).'
