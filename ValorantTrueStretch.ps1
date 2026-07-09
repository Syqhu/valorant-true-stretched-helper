Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"
$script:ManualConfigFolder = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
$script:KnownConfigFile = ""
$script:StatePath = Join-Path $PSScriptRoot "ValorantTrueStretch.state.json"

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class ValorantWindowTools {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll", EntryPoint="GetWindowLong")]
    public static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLong")]
    public static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int GWL_STYLE = -16;
    public const int WS_CAPTION = 0x00C00000;
    public const int WS_THICKFRAME = 0x00040000;
    public const int WS_MINIMIZE = 0x20000000;
    public const int WS_MAXIMIZEBOX = 0x00010000;
    public const int WS_SYSMENU = 0x00080000;
    public const int WS_BORDER = 0x00800000;
    public const int WS_DLGFRAME = 0x00400000;
    public const uint SWP_NOSENDCHANGING = 0x0400;
    public const uint SWP_FRAMECHANGED = 0x0020;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const int SW_RESTORE = 9;

    public static IntPtr FindWindowForPid(int pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) return true;
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);
            if (windowPid == pid) {
                found = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}

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
    if ($test -ne [DisplayModeTools]::DISP_CHANGE_SUCCESSFUL) {
        return $false
    }

    $result = [DisplayModeTools]::ChangeDisplaySettings([ref]$mode, [DisplayModeTools]::CDS_UPDATEREGISTRY)
    return ($result -eq [DisplayModeTools]::DISP_CHANGE_SUCCESSFUL)
}

function Restore-WindowsDisplayMode {
    if ($restore1920Check -and $restore1920Check.Checked) {
        $freq = 60
        $savedMode = Get-SavedDisplayMode
        if ($savedMode -and $savedMode.Frequency) {
            $freq = [int]$savedMode.Frequency
        } elseif ($script:OriginalDisplayMode -and $script:OriginalDisplayMode.dmDisplayFrequency) {
            $freq = [int]$script:OriginalDisplayMode.dmDisplayFrequency
        }
        return Set-WindowsDisplayMode 1920 1080 $freq
    }

    $mode = Get-SavedDisplayMode
    if (-not $mode) { $mode = $script:OriginalDisplayMode }
    if (-not $mode) { return $false }
    return Set-WindowsDisplayMode $mode.Width $mode.Height $mode.Frequency
}

$script:OriginalDisplayMode = Get-CurrentDisplayMode
$script:DisplayChanged = $false

function Save-DisplayModeState {
    $mode = Get-CurrentDisplayMode
    $state = [ordered]@{
        Width = [int]$mode.dmPelsWidth
        Height = [int]$mode.dmPelsHeight
        Frequency = [int]$mode.dmDisplayFrequency
        SavedAt = (Get-Date).ToString("s")
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $script:StatePath -Encoding UTF8
}

function Get-SavedDisplayMode {
    if (-not (Test-Path -LiteralPath $script:StatePath)) { return $null }
    try {
        $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
        if ($state.Width -and $state.Height -and $state.Frequency) {
            return @{
                Width = [int]$state.Width
                Height = [int]$state.Height
                Frequency = [int]$state.Frequency
            }
        }
    } catch {}
    return $null
}

function Clear-DisplayModeState {
    if (Test-Path -LiteralPath $script:StatePath) {
        Remove-Item -LiteralPath $script:StatePath -Force
    }
}

function Update-CurrentDisplayInfo {
    $mode = Get-CurrentDisplayMode
    if ($hzBox) {
        $hzBox.Value = [Math]::Max([int]$hzBox.Minimum, [Math]::Min([int]$hzBox.Maximum, [int]$mode.dmDisplayFrequency))
    }
    if ($currentDisplayLabel) {
        $currentDisplayLabel.Text = "現在: $($mode.dmPelsWidth)x$($mode.dmPelsHeight) / $($mode.dmDisplayFrequency)Hz"
    }
    return $mode
}

function Get-SelectedRefreshRate {
    if ($autoHzCheck -and $autoHzCheck.Checked) {
        $mode = Update-CurrentDisplayInfo
        return [int]$mode.dmDisplayFrequency
    }
    return [int]$hzBox.Value
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-VanguardService {
    $service = Get-Service -Name "vgc" -ErrorAction SilentlyContinue
    if (-not $service) {
        return "Vanguardサービス(vgc)が見つかりません。"
    }

    if ($service.Status -ne "Running") {
        try {
            Start-Service -Name "vgc" -ErrorAction Stop
            Start-Sleep -Seconds 2
            $service = Get-Service -Name "vgc" -ErrorAction SilentlyContinue
        } catch {
            return "Vanguardサービス(vgc)を起動できませんでした。PC再起動が必要かもしれません。"
        }
    }

    return "Vanguardサービス: $($service.Status)"
}

function Restore-AllTemporarySettings {
    $messages = @()

    [void](Unlock-ValorantConfigs)
    $messages += "INIロック解除"

    $savedMode = Get-SavedDisplayMode
    if ($script:DisplayChanged -or $savedMode) {
        if (Restore-WindowsDisplayMode) {
            $messages += "Windows解像度復元"
            Clear-DisplayModeState
        } else {
            $messages += "Windows解像度復元失敗"
        }
        $script:DisplayChanged = $false
    } else {
        $messages += "Windows解像度変更なし"
    }

    return ($messages -join " / ")
}

function Get-ValorantConfigPath {
    $manual = @(Get-ManualConfigPaths)
    if ($manual.Count -gt 0) {
        return @($manual | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTime } -Descending)[0]
    }

    $paths = Get-ValorantConfigPaths
    if ($paths.Count -eq 0) { return $null }
    return @($paths | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTime } -Descending)[0]
}

function Get-ManualConfigPaths {
    $folder = $script:ManualConfigFolder
    if ($configFolderText -and $configFolderText.Text.Trim()) {
        $folder = $configFolderText.Text.Trim()
    }

    if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { return @() }

    if ((Get-Item -LiteralPath $folder).PSIsContainer) {
        return @(Get-ChildItem -LiteralPath $folder -Recurse -Filter "GameUserSettings.ini" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName })
    }

    if ([System.IO.Path]::GetFileName($folder) -ieq "GameUserSettings.ini") {
        return @((Get-Item -LiteralPath $folder).FullName)
    }

    return @()
}

function Get-ValorantConfigPaths {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"),
        (Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config")
    ) | Select-Object -Unique

    $files = @()
    if ($script:KnownConfigFile -and (Test-Path -LiteralPath $script:KnownConfigFile)) {
        $files += $script:KnownConfigFile
    }
    $files += Get-ManualConfigPaths

    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $files += Get-ChildItem -LiteralPath $root -Recurse -Filter "GameUserSettings.ini" -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName }
        }
    }

    return @($files |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        Sort-Object -Unique)
}

function Backup-ValorantConfig($path) {
    $path = [string]$path
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $null }
    $backup = "$path.codex-backup"
    Copy-Item -LiteralPath $path -Destination $backup -Force
    return $backup
}

function Set-ConfigReadOnly($path, $enabled) {
    $path = [string]$path
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return }
    $item = Get-Item -LiteralPath $path
    $item.IsReadOnly = [bool]$enabled
}

function Set-IniValue([string[]]$lines, [string]$key, [string]$value) {
    $pattern = "^\s*" + [regex]::Escape($key) + "\s*="
    $done = $false
    $out = foreach ($line in $lines) {
        if ($line -match $pattern) {
            $done = $true
            "$key=$value"
        } else {
            $line
        }
    }
    if (-not $done) { $out += "$key=$value" }
    return $out
}

function Apply-ValorantConfigFile($path, $width, $height, $displayMode) {
    $path = [string]$path
    if (-not $path) {
        return @{ Ok = $false; Message = "設定ファイルが見つかりません。" }
    }
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ Ok = $false; Message = "設定ファイルが見つかりません: $path" }
    }

    Set-ConfigReadOnly $path $false
    $backup = Backup-ValorantConfig $path
    $lines = Get-Content -LiteralPath $path

    $fullscreenMode = 2
    if ($displayMode -eq "Windowed Fullscreen") {
        $fullscreenMode = 1
    }

    $keys = @{
        "bShouldLetterbox" = "False"
        "bLastConfirmedShouldLetterbox" = "False"
        "ResolutionSizeX" = $width
        "ResolutionSizeY" = $height
        "LastUserConfirmedResolutionSizeX" = $width
        "LastUserConfirmedResolutionSizeY" = $height
        "WindowPosX" = 0
        "WindowPosY" = 0
        "DesiredScreenWidth" = $width
        "DesiredScreenHeight" = $height
        "LastUserConfirmedDesiredScreenWidth" = $width
        "LastUserConfirmedDesiredScreenHeight" = $height
        "FullscreenMode" = $fullscreenMode
        "LastConfirmedFullscreenMode" = $fullscreenMode
        "PreferredFullscreenMode" = $fullscreenMode
        "bUseDesiredScreenHeight" = "False"
    }

    foreach ($key in $keys.Keys) {
        $lines = Set-IniValue $lines $key ([string]$keys[$key])
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding UTF8
    if ($lockIniCheck -and $lockIniCheck.Checked) {
        Set-ConfigReadOnly $path $true
    }
    return @{ Ok = $true; Message = "設定を書き換えました。バックアップ: $backup" }
}

function Apply-ValorantConfig($width, $height, $allAccounts, $displayMode) {
    $paths = if ($allAccounts) { Get-ValorantConfigPaths } else { @((Get-ValorantConfigPath)) }
    $paths = @($paths | ForEach-Object { [string]$_ } | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)

    if ($paths.Count -eq 0) {
        return @{ Ok = $false; Message = "VALORANT の GameUserSettings.ini が見つかりません。先に一度 VALORANT を起動して設定を作ってください。" }
    }

    $ok = 0
    $failed = 0
    foreach ($path in $paths) {
        $result = Apply-ValorantConfigFile $path $width $height $displayMode
        if ($result.Ok) { $ok++ } else { $failed++ }
    }

    if ($failed -gt 0) {
        return @{ Ok = ($ok -gt 0); Message = "$ok 件に適用しました。失敗: $failed 件" }
    }

    return @{ Ok = $true; Message = "$ok 件のアカウント/設定ファイルに $displayMode / Fill 用設定を適用しました。各ファイルは .codex-backup にバックアップ済みです。" }
}

function Restore-ValorantConfig($allAccounts) {
    $paths = if ($allAccounts) { Get-ValorantConfigPaths } else { @((Get-ValorantConfigPath)) }
    $paths = @($paths | ForEach-Object { [string]$_ } | Where-Object { $_ })

    $restored = 0
    foreach ($path in $paths) {
        $backup = "$path.codex-backup"
        if (Test-Path -LiteralPath $backup) {
            Set-ConfigReadOnly $path $false
            Copy-Item -LiteralPath $backup -Destination $path -Force
            $restored++
        }
    }

    return $restored
}

function Unlock-ValorantConfigs {
    $paths = @(Get-ValorantConfigPaths)
    if ($paths.Count -eq 0 -and $script:KnownConfigFile -and (Test-Path -LiteralPath $script:KnownConfigFile)) {
        $paths = @($script:KnownConfigFile)
    }

    $count = 0
    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Set-ConfigReadOnly $path $false
            $count++
        }
    }
    return $count
}

function Resolve-ValorantLaunch {
    $shortcut = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Riot Games\VALORANT.lnk"
    if (Test-Path $shortcut) {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($shortcut)
        if ($lnk.TargetPath -and (Test-Path $lnk.TargetPath)) {
            return @{ File = $lnk.TargetPath; Args = $lnk.Arguments }
        }
    }

    $riot = "C:\Riot Games\Riot Client\RiotClientServices.exe"
    if (Test-Path $riot) {
        return @{ File = $riot; Args = "--launch-product=valorant --launch-patchline=live" }
    }

    return $null
}

function Get-ValorantRenderProcess {
    Get-Process -Name "VALORANT-Win64-Shipping" -ErrorAction SilentlyContinue |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
}

function Apply-BorderlessStretch {
    $proc = Get-ValorantRenderProcess
    if (-not $proc) { return @{ Ok = $false; Message = "VALORANT の描画プロセス待機中..." } }

    $hwnd = [ValorantWindowTools]::FindWindowForPid($proc.Id)
    if ($hwnd -eq [IntPtr]::Zero) { return @{ Ok = $false; Message = "VALORANT のウィンドウ待機中..." } }

    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    [void][ValorantWindowTools]::ShowWindow($hwnd, [ValorantWindowTools]::SW_RESTORE)
    [void][ValorantWindowTools]::BringWindowToTop($hwnd)

    $style = [ValorantWindowTools]::GetWindowLong32($hwnd, [ValorantWindowTools]::GWL_STYLE)
    $remove = [ValorantWindowTools]::WS_CAPTION -bor [ValorantWindowTools]::WS_THICKFRAME -bor [ValorantWindowTools]::WS_MINIMIZE -bor [ValorantWindowTools]::WS_MAXIMIZEBOX -bor [ValorantWindowTools]::WS_SYSMENU -bor [ValorantWindowTools]::WS_BORDER -bor [ValorantWindowTools]::WS_DLGFRAME
    $newStyle = $style -band (-bnot $remove)
    [void][ValorantWindowTools]::SetWindowLong32($hwnd, [ValorantWindowTools]::GWL_STYLE, $newStyle)
    [void][ValorantWindowTools]::MoveWindow($hwnd, $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height, $true)
    Start-Sleep -Milliseconds 120
    [void][ValorantWindowTools]::SetWindowPos($hwnd, [IntPtr]::Zero, $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height, [ValorantWindowTools]::SWP_FRAMECHANGED -bor [ValorantWindowTools]::SWP_SHOWWINDOW -bor [ValorantWindowTools]::SWP_NOSENDCHANGING)
    Start-Sleep -Milliseconds 120
    [void][ValorantWindowTools]::MoveWindow($hwnd, $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height, $true)

    return @{ Ok = $true; Message = "特殊 stretched を適用しました。Windowed または Windowed Fullscreen / Fill に対応しています。" }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "VALORANT True Stretched 特殊ツール"
$form.Size = New-Object System.Drawing.Size(760, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(720, 560)

$title = New-Object System.Windows.Forms.Label
$title.Text = "VALORANT True Stretched 特殊ツール"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(700, 30)
$form.Controls.Add($title)

$note = New-Object System.Windows.Forms.Label
$note.Text = "WinExp 風の特殊方式です。設定ファイルをバックアップして 4:3 Windowed にし、VALORANT のウィンドウを枠なし全画面へ伸ばします。Vanguard 回避やメモリ改変はしません。"
$note.Location = New-Object System.Drawing.Point(18, 50)
$note.Size = New-Object System.Drawing.Size(700, 44)
$form.Controls.Add($note)

$resLabel = New-Object System.Windows.Forms.Label
$resLabel.Text = "ゲーム内解像度"
$resLabel.Location = New-Object System.Drawing.Point(18, 112)
$resLabel.Size = New-Object System.Drawing.Size(110, 24)
$form.Controls.Add($resLabel)

$resolutionBox = New-Object System.Windows.Forms.ComboBox
$resolutionBox.DropDownStyle = "DropDownList"
$resolutionBox.Location = New-Object System.Drawing.Point(140, 108)
$resolutionBox.Size = New-Object System.Drawing.Size(190, 26)
[void]$resolutionBox.Items.Add("1280x960  (4:3)")
[void]$resolutionBox.Items.Add("1440x1080 (4:3)")
[void]$resolutionBox.Items.Add("1080x1080 (Square)")
[void]$resolutionBox.Items.Add("1280x1080 (Wide stretch)")
[void]$resolutionBox.Items.Add("1600x1080 (Wide stretch)")
[void]$resolutionBox.Items.Add("1680x1050 (16:10)")
[void]$resolutionBox.Items.Add("1024x768  (4:3)")
[void]$resolutionBox.Items.Add("1280x1024 (5:4)")
$resolutionBox.SelectedIndex = 3
$form.Controls.Add($resolutionBox)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Text = "表示モード"
$modeLabel.Location = New-Object System.Drawing.Point(18, 148)
$modeLabel.Size = New-Object System.Drawing.Size(110, 24)
$form.Controls.Add($modeLabel)

$displayModeBox = New-Object System.Windows.Forms.ComboBox
$displayModeBox.DropDownStyle = "DropDownList"
$displayModeBox.Location = New-Object System.Drawing.Point(140, 144)
$displayModeBox.Size = New-Object System.Drawing.Size(190, 26)
[void]$displayModeBox.Items.Add("Windowed")
[void]$displayModeBox.Items.Add("Windowed Fullscreen")
$displayModeBox.SelectedIndex = 0
$form.Controls.Add($displayModeBox)

$allAccountsCheck = New-Object System.Windows.Forms.CheckBox
$allAccountsCheck.Text = "すべてのアカウントに適用"
$allAccountsCheck.Checked = $true
$allAccountsCheck.Location = New-Object System.Drawing.Point(360, 108)
$allAccountsCheck.Size = New-Object System.Drawing.Size(220, 24)
$form.Controls.Add($allAccountsCheck)

$lockIniCheck = New-Object System.Windows.Forms.CheckBox
$lockIniCheck.Text = "起動中だけINIをロック"
$lockIniCheck.Checked = $true
$lockIniCheck.Location = New-Object System.Drawing.Point(360, 136)
$lockIniCheck.Size = New-Object System.Drawing.Size(220, 24)
$form.Controls.Add($lockIniCheck)

$changeWindowsResCheck = New-Object System.Windows.Forms.CheckBox
$changeWindowsResCheck.Text = "Windows解像度も変更して自動復元"
$changeWindowsResCheck.Checked = $true
$changeWindowsResCheck.Location = New-Object System.Drawing.Point(360, 164)
$changeWindowsResCheck.Size = New-Object System.Drawing.Size(300, 24)
$form.Controls.Add($changeWindowsResCheck)

$restore1920Check = New-Object System.Windows.Forms.CheckBox
$restore1920Check.Text = "終了時は1920x1080へ戻す"
$restore1920Check.Checked = $true
$restore1920Check.Location = New-Object System.Drawing.Point(360, 188)
$restore1920Check.Size = New-Object System.Drawing.Size(260, 24)
$form.Controls.Add($restore1920Check)

$hzLabel = New-Object System.Windows.Forms.Label
$hzLabel.Text = "Hz"
$hzLabel.Location = New-Object System.Drawing.Point(18, 184)
$hzLabel.Size = New-Object System.Drawing.Size(110, 24)
$form.Controls.Add($hzLabel)

$hzBox = New-Object System.Windows.Forms.NumericUpDown
$hzBox.Location = New-Object System.Drawing.Point(140, 180)
$hzBox.Size = New-Object System.Drawing.Size(90, 24)
$hzBox.Minimum = 30
$hzBox.Maximum = 500
$hzBox.Value = [Math]::Max(30, [Math]::Min(500, $script:OriginalDisplayMode.dmDisplayFrequency))
$form.Controls.Add($hzBox)

$autoHzCheck = New-Object System.Windows.Forms.CheckBox
$autoHzCheck.Text = "現在Hzを自動使用"
$autoHzCheck.Checked = $true
$autoHzCheck.Location = New-Object System.Drawing.Point(240, 180)
$autoHzCheck.Size = New-Object System.Drawing.Size(150, 24)
$form.Controls.Add($autoHzCheck)

$refreshHzButton = New-Object System.Windows.Forms.Button
$refreshHzButton.Text = "Hz更新"
$refreshHzButton.Location = New-Object System.Drawing.Point(392, 178)
$refreshHzButton.Size = New-Object System.Drawing.Size(76, 28)
$form.Controls.Add($refreshHzButton)

$currentDisplayLabel = New-Object System.Windows.Forms.Label
$currentDisplayLabel.Text = "現在: $($script:OriginalDisplayMode.dmPelsWidth)x$($script:OriginalDisplayMode.dmPelsHeight) / $($script:OriginalDisplayMode.dmDisplayFrequency)Hz"
$currentDisplayLabel.Location = New-Object System.Drawing.Point(18, 216)
$currentDisplayLabel.Size = New-Object System.Drawing.Size(330, 24)
$form.Controls.Add($currentDisplayLabel)

$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Text = "INIフォルダ"
$folderLabel.Location = New-Object System.Drawing.Point(18, 260)
$folderLabel.Size = New-Object System.Drawing.Size(110, 24)
$form.Controls.Add($folderLabel)

$configFolderText = New-Object System.Windows.Forms.TextBox
$configFolderText.Location = New-Object System.Drawing.Point(140, 256)
$configFolderText.Size = New-Object System.Drawing.Size(580, 24)
$configFolderText.Text = $script:ManualConfigFolder
$form.Controls.Add($configFolderText)

$openConfigButton = New-Object System.Windows.Forms.Button
$openConfigButton.Text = "設定フォルダ"
$openConfigButton.Location = New-Object System.Drawing.Point(18, 300)
$openConfigButton.Size = New-Object System.Drawing.Size(120, 32)
$form.Controls.Add($openConfigButton)

$restoreConfigButton = New-Object System.Windows.Forms.Button
$restoreConfigButton.Text = "設定を戻す"
$restoreConfigButton.Location = New-Object System.Drawing.Point(154, 300)
$restoreConfigButton.Size = New-Object System.Drawing.Size(120, 32)
$form.Controls.Add($restoreConfigButton)

$restoreAllButton = New-Object System.Windows.Forms.Button
$restoreAllButton.Text = "画面を今すぐ戻す"
$restoreAllButton.Location = New-Object System.Drawing.Point(290, 300)
$restoreAllButton.Size = New-Object System.Drawing.Size(140, 32)
$form.Controls.Add($restoreAllButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "設定だけ適用"
$startButton.Location = New-Object System.Drawing.Point(18, 354)
$startButton.Size = New-Object System.Drawing.Size(210, 38)
$form.Controls.Add($startButton)

$applyNowButton = New-Object System.Windows.Forms.Button
$applyNowButton.Text = "今すぐ特殊適用"
$applyNowButton.Location = New-Object System.Drawing.Point(244, 354)
$applyNowButton.Size = New-Object System.Drawing.Size(150, 38)
$form.Controls.Add($applyNowButton)

$configOnlyButton = New-Object System.Windows.Forms.Button
$configOnlyButton.Text = "設定だけ書き換え"
$configOnlyButton.Location = New-Object System.Drawing.Point(410, 354)
$configOnlyButton.Size = New-Object System.Drawing.Size(150, 38)
$form.Controls.Add($configOnlyButton)

$help = New-Object System.Windows.Forms.Label
$help.Text = "手順: 1) VALORANT を閉じる  2) 設定だけ適用  3) VALORANTは手動で起動  4) ゲーム内 Fill  5) 終了後に自動復元"
$help.Location = New-Object System.Drawing.Point(18, 416)
$help.Size = New-Object System.Drawing.Size(700, 45)
$form.Controls.Add($help)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(18, 482)
$status.Size = New-Object System.Drawing.Size(700, 62)
$status.Text = "待機中"
$form.Controls.Add($status)

[void](Update-CurrentDisplayInfo)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2500
$script:AutoApply = $false
$script:Applied = $false
$script:UnlockedAfterGame = $false
$script:SeenValorant = $false
$script:AutoConfigRefreshes = 0
$script:MaxAutoConfigRefreshes = 8

function Get-SelectedResolution {
    $text = [string]$resolutionBox.SelectedItem
    if ($text -match "(\d+)x(\d+)") {
        return @{ Width = [int]$Matches[1]; Height = [int]$Matches[2] }
    }
    return @{ Width = 1280; Height = 960 }
}

function Write-SelectedConfig {
    $res = Get-SelectedResolution
    return Apply-ValorantConfig $res.Width $res.Height $allAccountsCheck.Checked ([string]$displayModeBox.SelectedItem)
}

function Write-KnownConfigFallback {
    $res = Get-SelectedResolution
    $mode = [string]$displayModeBox.SelectedItem

    $manualPaths = @(Get-ManualConfigPaths)
    if ($manualPaths.Count -eq 0 -and $script:KnownConfigFile -and (Test-Path -LiteralPath $script:KnownConfigFile)) {
        $manualPaths = @($script:KnownConfigFile)
    }

    if ($manualPaths.Count -eq 0) {
        return @{ Ok = $false; Message = "フォールバックでも GameUserSettings.ini が見つかりません。INIフォルダ欄を確認してください。" }
    }

    $ok = 0
    $failed = 0
    foreach ($path in $manualPaths) {
        $result = Apply-ValorantConfigFile $path $res.Width $res.Height $mode
        if ($result.Ok) { $ok++ } else { $failed++ }
    }

    return @{ Ok = ($ok -gt 0); Message = "指定INIフォルダから $ok 件に適用しました。失敗: $failed 件" }
}

$configOnlyButton.Add_Click({
    $result = Write-SelectedConfig
    if (-not $result.Ok) {
        $result = Write-KnownConfigFallback
    }
    $status.Text = $result.Message
})

$refreshHzButton.Add_Click({
    $mode = Update-CurrentDisplayInfo
    $status.Text = "現在Hzを取得しました: $($mode.dmDisplayFrequency)Hz"
})

$startButton.Add_Click({
    $result = Write-SelectedConfig
    if (-not $result.Ok) {
        $firstMessage = $result.Message
        $result = Write-KnownConfigFallback
        if (-not $result.Ok) {
            $status.Text = "$firstMessage / $($result.Message)"
            return
        }
    }

    $setupMessages = @($result.Message)

    if ($changeWindowsResCheck.Checked) {
        $res = Get-SelectedResolution
        $script:OriginalDisplayMode = Get-CurrentDisplayMode
        Save-DisplayModeState
        $selectedHz = Get-SelectedRefreshRate
        $okDisplay = Set-WindowsDisplayMode $res.Width $res.Height $selectedHz
        if ($okDisplay) {
            $script:DisplayChanged = $true
            $setupMessages += "Windows解像度を $($res.Width)x$($res.Height) / $selectedHz Hz に変更しました。"
        } else {
            Clear-DisplayModeState
            [void](Unlock-ValorantConfigs)
            $status.Text = "Windows解像度を $($res.Width)x$($res.Height) / $selectedHz Hz に変更できませんでした。この解像度/HzがWindowsに未登録です。GPU設定またはカスタム解像度ツールで先に追加してください。VALORANTは起動していません。"
            return
        }
    }

    $script:AutoApply = $true
    $script:Applied = $false
    $script:UnlockedAfterGame = $false
    $script:SeenValorant = $false
    $script:AutoConfigRefreshes = 0
    $status.Text = ($setupMessages -join " / ") + " / VALORANTは起動していません。手動で起動すると監視と自動復元だけ行います。"
})

$applyNowButton.Add_Click({
    $result = Apply-BorderlessStretch
    $status.Text = $result.Message
    if ($result.Ok) { $script:Applied = $true }
})

$restoreConfigButton.Add_Click({
    $count = Restore-ValorantConfig $allAccountsCheck.Checked
    if ($count -gt 0) {
        $status.Text = "$count 件をバックアップから戻しました。VALORANT 起動中なら再起動してください。"
    } else {
        $status.Text = "戻せるバックアップが見つかりません。"
    }
})

$restoreAllButton.Add_Click({
    $status.Text = Restore-AllTemporarySettings
})

$openConfigButton.Add_Click({
    $path = Get-ValorantConfigPath
    if ($path) {
        Start-Process explorer.exe "/select,`"$path`""
    } elseif ($configFolderText.Text.Trim() -and (Test-Path -LiteralPath $configFolderText.Text.Trim())) {
        Start-Process explorer.exe $configFolderText.Text.Trim()
    } else {
        Start-Process explorer.exe (Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config")
    }
})

$timer.Add_Tick({
    $valorant = Get-ValorantRenderProcess
    if ($valorant) {
        $script:SeenValorant = $true
    }

    if (($script:Applied -or $script:SeenValorant) -and -not $script:UnlockedAfterGame -and -not $valorant) {
        $count = Unlock-ValorantConfigs
        $displayText = ""
        if ($script:DisplayChanged) {
            if (Restore-WindowsDisplayMode) {
                $displayText = " / Windows解像度を元に戻しました。"
                Clear-DisplayModeState
            } else {
                $displayText = " / Windows解像度の復元に失敗しました。"
            }
            $script:DisplayChanged = $false
        }

        $script:UnlockedAfterGame = $true
        $script:AutoApply = $false
        $status.Text = "VALORANT 終了を検知したので、INIロックを解除しました。解除: $count 件$displayText"
        return
    }

    if (-not $script:AutoApply -or $script:Applied) { return }

    if ($script:AutoConfigRefreshes -lt $script:MaxAutoConfigRefreshes) {
        $refreshResult = Write-SelectedConfig
        if (-not $refreshResult.Ok) {
            $refreshResult = Write-KnownConfigFallback
        }
        $script:AutoConfigRefreshes++
        if ($refreshResult.Ok) {
            $status.Text = "アカウント切替対応: INIを再スキャンして再適用しました。$($script:AutoConfigRefreshes)/$($script:MaxAutoConfigRefreshes)"
        }
    }

    if ($valorant) {
        $result = Apply-BorderlessStretch
        $status.Text = $result.Message
        if ($result.Ok) {
            $script:Applied = $true
            $script:AutoApply = $false
        }
    }
})
$timer.Start()

$form.Add_FormClosing({
    [void](Restore-AllTemporarySettings)
})

[void]$form.ShowDialog()
