Add-Type -AssemblyName System.Windows.Forms

$ErrorActionPreference = "SilentlyContinue"
$statePath = Join-Path $PSScriptRoot "ValorantTrueStretch.state.json"

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DisplayModeTools {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        private const int CCHDEVICENAME = 32;
        private const int CCHFORMNAME = 32;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHDEVICENAME)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHFORMNAME)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY = 0x01;
    public const int CDS_TEST = 0x02;
    public const int DISP_CHANGE_SUCCESSFUL = 0;
    public const int DM_PELSWIDTH = 0x80000;
    public const int DM_PELSHEIGHT = 0x100000;
    public const int DM_DISPLAYFREQUENCY = 0x400000;
}
"@

function Get-CurrentDisplayMode {
    $mode = New-Object DisplayModeTools+DEVMODE
    $mode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mode)
    [void][DisplayModeTools]::EnumDisplaySettings($null, [DisplayModeTools]::ENUM_CURRENT_SETTINGS, [ref]$mode)
    return $mode
}

function Set-WindowsDisplayMode($width, $height, $frequency) {
    $mode = Get-CurrentDisplayMode
    $mode.dmPelsWidth = [int]$width
    $mode.dmPelsHeight = [int]$height
    $mode.dmDisplayFrequency = [int]$frequency
    $mode.dmFields = [DisplayModeTools]::DM_PELSWIDTH -bor [DisplayModeTools]::DM_PELSHEIGHT -bor [DisplayModeTools]::DM_DISPLAYFREQUENCY

    $test = [DisplayModeTools]::ChangeDisplaySettings([ref]$mode, [DisplayModeTools]::CDS_TEST)
    if ($test -ne [DisplayModeTools]::DISP_CHANGE_SUCCESSFUL) { return $false }

    $result = [DisplayModeTools]::ChangeDisplaySettings([ref]$mode, [DisplayModeTools]::CDS_UPDATEREGISTRY)
    return ($result -eq [DisplayModeTools]::DISP_CHANGE_SUCCESSFUL)
}

function Stop-RiotProcesses {
    $names = @("VALORANT-Win64-Shipping", "VALORANT", "Riot Client", "RiotClientServices", "RiotClientCrashHandler", "vgtray")
    $closed = 0
    Get-Process | Where-Object { $names -contains $_.ProcessName } | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
            $closed++
        } catch {}
    }
    return $closed
}

function Unlock-ValorantIni {
    $root = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
    if (-not (Test-Path -LiteralPath $root)) { return 0 }

    $count = 0
    Get-ChildItem -LiteralPath $root -Recurse -Filter "GameUserSettings.ini" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $_.IsReadOnly = $false
            $count++
        } catch {}
    }
    return $count
}

function Restore-Display {
    $current = Get-CurrentDisplayMode
    $freq = [int]$current.dmDisplayFrequency

    if (Test-Path -LiteralPath $statePath) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            if ($state.Width -and $state.Height -and $state.Frequency) {
                $ok = Set-WindowsDisplayMode ([int]$state.Width) ([int]$state.Height) ([int]$state.Frequency)
                Remove-Item -LiteralPath $statePath -Force
                return "Display restore from saved state: $ok"
            }
        } catch {}
    }

    $ok1920 = Set-WindowsDisplayMode 1920 1080 $freq
    return "Display restore to 1920x1080 @ ${freq}Hz: $ok1920"
}

function Start-VanguardService {
    $svc = Get-Service -Name "vgc" -ErrorAction SilentlyContinue
    if (-not $svc) { return "vgc service not found. Reinstall Riot Vanguard." }

    try {
        Start-Service -Name "vgc" -ErrorAction Stop
        Start-Sleep -Seconds 3
    } catch {
        return "vgc start failed: $($_.Exception.Message)"
    }

    $svc = Get-Service -Name "vgc" -ErrorAction SilentlyContinue
    return "vgc status: $($svc.Status)"
}

function Get-RecentVgcError {
    $event = Get-WinEvent -LogName System -MaxEvents 80 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match "vgc|Vanguard" } |
        Select-Object -First 1
    if ($event) {
        return "Latest vgc event: $($event.Message)"
    }
    return "No recent vgc event found."
}

$confirm = [System.Windows.Forms.MessageBox]::Show(
    "This will close Riot/VALORANT processes, unlock VALORANT INI files, restore display resolution, and try to start Vanguard service. Continue?",
    "VAN -102 Fix",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning
)

if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { exit }

$messages = New-Object System.Collections.Generic.List[string]
$messages.Add("Closed Riot/VALORANT processes: $(Stop-RiotProcesses)")
Start-Sleep -Seconds 1
$messages.Add("Unlocked GameUserSettings.ini files: $(Unlock-ValorantIni)")
$messages.Add((Restore-Display))
$messages.Add((Start-VanguardService))
$messages.Add((Get-RecentVgcError))
$messages.Add("")
$messages.Add("If vgc still says Incorrect function or stays Stopped, uninstall Riot Vanguard, reboot, launch VALORANT once to reinstall Vanguard, then reboot again.")

[System.Windows.Forms.MessageBox]::Show(
    ($messages -join [Environment]::NewLine),
    "VAN -102 Fix Result",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
