# Support Notes

This was a personal helper script made to reproduce and troubleshoot true stretched resolution behavior in VALORANT.

## Timeline Summary

- Tried a WinExp-style window stretch approach.
- Added support for applying settings across multiple VALORANT account config folders.
- Added optional Windows display resolution switching and automatic restore, including a fixed `1920x1080` restore option.
- Older test builds included optional `Scaling=3` registry handling; current builds remove that behavior.
- Added optional INI read-only lock because the stretched setup did not persist without it.
- Encountered `VAN102`, then later `VAL5` with a short temporary restriction after repeated tests.

## Current Concern

The concern is whether any of these local changes, especially read-only `GameUserSettings.ini` or display mode switching, can trigger VALORANT/Vanguard errors.

The script does not modify game binaries, inject code, read process memory, write process memory, hook Vanguard, or bypass anti-cheat.
