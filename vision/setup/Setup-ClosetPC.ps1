<#
.SYNOPSIS
  One-time Windows 11 Pro setup for the Tennis Vision closet PC (TV-ARCH-04, "Closet PC setup" steps 3-5, 7, 9).

.DESCRIPTION
  Run once, as administrator, after Chris has done steps 1-2 (Windows 11 Pro with a local
  account "tennis"; BIOS "Restore on AC power loss" = Power On). Each step prints what it
  changes. Safe to run again: every step sets a value rather than adding to it.
  Run with -WhatIf first to see the changes without making them.

  Not done here, on purpose:
  - Auto-login (step 3): it needs the account password. Use Sysinternals Autologon, which
    stores it encrypted (LSA secret), not this script.
  - Installing NVIDIA driver, MATLAB, FFmpeg, Git, Tailscale, Claude Code (step 6): installers
    and licences are interactive.
  - Remote Desktop users and Tailscale sign-in (step 8).
  - The at-log-on watcher task is created only when tv.watch exists (TV-PH-1). Until then this
    script skips it and says so.

  UNTESTED until it runs on the PC: written in a Linux cloud session with no Windows to try it on.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$User = 'tennis',
  [string]$VisionFolder = 'C:\TennisVision\code\vision',
  [string]$ArchiveDrive = 'D:',
  [int]$UpdateRestartHour = 14   # Windows Update may restart only around this hour (the pipeline runs overnight)
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

Step 'Done. Still by hand: Autologon for the tennis account, installers (step 6), Tailscale and Remote Desktop (step 8), ntfy on the phone (step 9).'
