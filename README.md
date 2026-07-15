# VALORANT True Stretched Helper for Windows 11

This repository contains a small Windows PowerShell/WinForms helper for Windows 11 PCs. It helps apply and restore local display/config settings used for true stretched resolution workflows in VALORANT.

It is being shared for support / troubleshooting context. It is not a cheat, does not read or write VALORANT memory, and does not attempt to bypass Vanguard. It changes local Windows display settings, local VALORANT configuration files, and window placement.

## Files

- `ValorantTrueStretch.ps1` - Main GUI helper for VALORANT true stretched testing.
- `Start-ValorantTrueStretch.cmd` - Starts the helper with administrator prompt.
- `VAN102Fix.ps1` - One-click recovery helper for local VAN -102 troubleshooting.
- `Start-VAN102Fix.cmd` - Starts the VAN -102 recovery helper with administrator prompt.
- `VAL51Fix.ps1` - Safe network/Riot Client reset helper for VAL 51 troubleshooting.
- `Start-VAL51Fix.cmd` - Starts the VAL 51 helper with administrator prompt.
- `ManualStretchHelper.ps1` - Safer manual-only helper. It does not launch VALORANT, monitor VALORANT, edit INI files automatically, touch Vanguard, use window APIs, or change registry values.
- `Start-ManualStretchHelper.cmd` - Starts the manual-only helper.
- `FPSBoostTool.ps1` - General FPS preparation helper. It can trim memory, switch power plan, open Windows game settings, and close selected non-system apps.
- `Start-FPSBoostTool.cmd` - Starts the FPS boost helper.
- `GameOptimizer.ps1` - Separate game preparation helper that can close selected non-system apps.
- `Start-GameOptimizer.cmd` - Starts the game optimizer helper.

## What the VALORANT helper can do

- Find `GameUserSettings.ini` under `%LOCALAPPDATA%\VALORANT\Saved\Config`.
- Apply selected resolution values to VALORANT config files.
- Optionally set the config file read-only while launching.
- Optionally change the Windows display resolution.
- Save the previous Windows display mode to `ValorantTrueStretch.state.json`.
- Restore the previous Windows display mode, or force restore to `1920x1080`, when VALORANT exits or when the restore button is pressed.
- Does not modify Windows graphics driver `Scaling` registry values.
- It does not start Riot Client or VALORANT. Launch the game manually after applying settings.

## Important notes

- Custom resolutions such as `1080x1080`, `1280x1080`, or `1600x1080` must already be registered in Windows/GPU settings. The script cannot safely create NVIDIA/AMD/Intel custom resolutions automatically.
- INI read-only locking may affect VALORANT/Vanguard behavior. This option should be used carefully.
- The script includes restore paths, but a PC restart may still be needed after Vanguard-related errors.

## VAN -102 recovery helper

`Start-VAN102Fix.cmd` does not launch VALORANT. It:

- Closes Riot/VALORANT processes after confirmation.
- Unlocks all local `GameUserSettings.ini` files.
- Restores display resolution from saved state, or falls back to `1920x1080`.
- Attempts to start the `vgc` Vanguard service.
- Shows the latest relevant `vgc` event message.

If `vgc` still reports `Incorrect function` or remains stopped, reinstall Riot Vanguard and reboot.

## VAL 51 recovery helper

`Start-VAL51Fix.cmd` does not launch VALORANT, control Vanguard, bypass restrictions, or edit registry values. It can:

- Close Riot/VALORANT processes after confirmation.
- Flush/register DNS.
- Run Winsock/IP reset after confirmation. A PC restart is needed after this step.
- Move local Riot Client `Config`, `Data`, and `HttpCache` folders to a timestamped backup folder, so Riot Client can rebuild login/session cache.
- Show a simple network snapshot.
- Open Riot service status, Windows Firewall, and Windows network settings.

Recommended order: close Riot Client, run DNS repair, reopen Riot Client manually. If VAL 51 remains and the logs show invalid token/session errors, use the Riot cache backup option and sign in again. Use Winsock/IP reset only if the simple DNS/cache repair does not help.

## Manual-only helper

`Start-ManualStretchHelper.cmd` is intended for safer sharing. It only:

- Lists local `GameUserSettings.ini` files with Fill/Letterbox, resolution, and read-only state.
- Opens the selected INI in Notepad.
- Copies suggested INI lines to the clipboard.
- Copies read-only / unlock commands to the clipboard.
- Copies a manual Fill repair command for the selected account INI plus the shared `WindowsClient` INI.
- Opens Windows display settings.

It does not automatically edit files, start VALORANT, monitor VALORANT, manipulate VALORANT windows, change registry values, or control Vanguard services.

If the game keeps returning to Letterbox, close VALORANT/Riot Client, set both the latest account `GameUserSettings.ini` and the shared `WindowsClient\GameUserSettings.ini` to Fill, then set both files read-only before launching the game manually. A `ResolutionSizeY` such as `1040` usually means the game saved a window/client-area size instead of the intended stretched height.

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
