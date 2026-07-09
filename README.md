# VALORANT True Stretched Helper for Windows 11

This repository contains a small Windows PowerShell/WinForms helper for Windows 11 PCs. It helps apply and restore local display/config settings used for true stretched resolution workflows in VALORANT.

It is being shared for support / troubleshooting context. It is not a cheat, does not read or write VALORANT memory, and does not attempt to bypass Vanguard. It changes local Windows display settings, local VALORANT configuration files, and window placement.

## Files

- `ValorantTrueStretch.ps1` - Main GUI helper for VALORANT true stretched testing.
- `Start-ValorantTrueStretch.cmd` - Starts the helper with administrator prompt.
- `VAN102Fix.ps1` - One-click recovery helper for local VAN -102 troubleshooting.
- `Start-VAN102Fix.cmd` - Starts the VAN -102 recovery helper with administrator prompt.
- `ManualStretchHelper.ps1` - Safer manual-only helper. It does not launch VALORANT, monitor VALORANT, edit INI files automatically, touch Vanguard, use window APIs, or change registry values.
- `Start-ManualStretchHelper.cmd` - Starts the manual-only helper.
- `GameOptimizer.ps1` - Separate game preparation helper that can close selected non-system apps.
- `Start-GameOptimizer.cmd` - Starts the game optimizer helper.

## What the VALORANT helper can do

- Find `GameUserSettings.ini` under `%LOCALAPPDATA%\VALORANT\Saved\Config`.
- Apply selected resolution values to VALORANT config files.
- Optionally set the config file read-only while launching.
- Optionally change the Windows display resolution.
- Save the previous Windows display mode to `ValorantTrueStretch.state.json`.
- Restore the previous Windows display mode, or force restore to `1920x1080`, when VALORANT exits or when the restore button is pressed.
- Optionally set Windows graphics driver `Scaling` registry values to `3`, then restore them later.
- It does not start Riot Client or VALORANT. Launch the game manually after applying settings.

## Important notes

- Custom resolutions such as `1080x1080`, `1280x1080`, or `1600x1080` must already be registered in Windows/GPU settings. The script cannot safely create NVIDIA/AMD/Intel custom resolutions automatically.
- `Scaling=3` registry changes and INI read-only locking may affect VALORANT/Vanguard behavior. These options should be used carefully.
- The script includes restore paths, but a PC restart may still be needed after Vanguard-related errors.

## VAN -102 recovery helper

`Start-VAN102Fix.cmd` does not launch VALORANT. It:

- Closes Riot/VALORANT processes after confirmation.
- Unlocks all local `GameUserSettings.ini` files.
- Restores display resolution from saved state, or falls back to `1920x1080`.
- Attempts to start the `vgc` Vanguard service.
- Shows the latest relevant `vgc` event message.

If `vgc` still reports `Incorrect function` or remains stopped, reinstall Riot Vanguard and reboot.

## Manual-only helper

`Start-ManualStretchHelper.cmd` is intended for safer sharing. It only:

- Lists local `GameUserSettings.ini` files.
- Opens the selected INI in Notepad.
- Copies suggested INI lines to the clipboard.
- Copies read-only / unlock commands to the clipboard.
- Opens Windows display settings.

It does not automatically edit files, start VALORANT, monitor VALORANT, manipulate VALORANT windows, change registry values, or control Vanguard services.

## Reported test symptoms

During testing, these errors were observed:

- `VAN102`
- `VAL5`
- A short temporary queue/ban after repeated launch attempts

After those errors, the local troubleshooting step was to:

- Unlock all `GameUserSettings.ini` files.
- Stop using repeated automated launch attempts.
- Confirm `vgc` / Vanguard service state.
- Restart the PC before testing normal VALORANT launch again.

## Safety / privacy

Generated runtime files are ignored by Git:

- `*.codex-backup`
- `ValorantTrueStretch.state.json`
- screenshots and videos

The script uses environment variables such as `%LOCALAPPDATA%` instead of hardcoded user profile paths.
