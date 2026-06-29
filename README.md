# VALORANT True Stretched Helper

This repository contains a small Windows PowerShell/WinForms helper that was created while testing true stretched resolution workflows for VALORANT.

It is being shared for support / troubleshooting context. It is not a cheat, does not read or write VALORANT memory, and does not attempt to bypass Vanguard. It changes local Windows display settings, local VALORANT configuration files, and window placement.

## Files

- `ValorantTrueStretch.ps1` - Main GUI helper for VALORANT true stretched testing.
- `Start-ValorantTrueStretch.cmd` - Starts the helper with administrator prompt.
- `GameOptimizer.ps1` - Separate game preparation helper that can close selected non-system apps.
- `Start-GameOptimizer.cmd` - Starts the game optimizer helper.

## What the VALORANT helper can do

- Find `GameUserSettings.ini` under `%LOCALAPPDATA%\VALORANT\Saved\Config`.
- Apply selected resolution values to VALORANT config files.
- Optionally set the config file read-only while launching.
- Optionally change the Windows display resolution.
- Save the previous Windows display mode to `ValorantTrueStretch.state.json`.
- Restore the previous Windows display mode when VALORANT exits or when the restore button is pressed.
- Optionally set Windows graphics driver `Scaling` registry values to `3`, then restore them later.
- Start the Riot Client/VALORANT through normal installed paths.

## Important notes

- Custom resolutions such as `1600x1080` must already be registered in Windows/GPU settings. The script cannot safely create NVIDIA/AMD/Intel/CRU custom resolutions automatically.
- `Scaling=3` registry changes and INI read-only locking may affect VALORANT/Vanguard behavior. These options should be used carefully.
- The script includes restore paths, but a PC restart may still be needed after Vanguard-related errors.

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

