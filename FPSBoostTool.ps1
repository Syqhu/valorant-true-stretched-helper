Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

$ProtectedNames = @(
    "System", "Idle", "Registry", "smss", "csrss", "wininit", "winlogon", "services",
    "lsass", "svchost", "fontdrvhost", "dwm", "conhost", "spoolsv", "audiodg",
    "explorer", "sihost", "taskhostw", "RuntimeBroker", "SearchHost", "StartMenuExperienceHost",
    "ShellExperienceHost", "SecurityHealthService", "MsMpEng", "NisSrv", "WmiPrvSE",
    "SearchApp", "TextInputHost", "ctfmon", "dllhost", "ApplicationFrameHost",
    "SystemSettings", "UserOOBEBroker", "Widgets", "WidgetService",
    "NVDisplay.Container", "nvcontainer", "vgc", "vgtray",
    "powershell", "pwsh", "WindowsTerminal", "OpenConsole", "Codex", "codex", "node"
)

$BrowserNames = @("chrome", "msedge", "firefox", "brave", "opera", "vivaldi")
$ChatNames = @("Discord", "Slack", "Teams")
$LauncherNames = @("Steam", "EpicGamesLauncher", "Battle.net", "RiotClientServices", "EpicWebHelper")
$MediaNames = @("Spotify", "obs64", "obs32", "NVIDIA Overlay", "Overwolf")
$SyncDownloadNames = @("OneDrive", "Dropbox", "GoogleDriveFS", "fdm", "uTorrent", "qbittorrent", "AdobeCollabSync", "Creative Cloud", "CCXProcess")
$UtilityNames = @("PhoneExperienceHost", "YourPhone", "lghub", "lghub_agent", "lghub_updater", "GameManagerService", "CCleaner64", "CCleaner")
$CandidateNames = $BrowserNames + $ChatNames + $LauncherNames + $MediaNames + $SyncDownloadNames + $UtilityNames

function Get-MemoryMb($process) {
    if ($null -eq $process.WorkingSet64) { return 0 }
    return [math]::Round($process.WorkingSet64 / 1MB, 1)
}

function Get-SystemSummary {
    $os = Get-CimInstance Win32_OperatingSystem
    $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $used = [math]::Round($total - $free, 1)
    return "RAM: $used / $total GB  Free: $free GB"
}

function Get-Category($name) {
    if ($BrowserNames -contains $name) { return "ブラウザ" }
    if ($ChatNames -contains $name) { return "チャット" }
    if ($LauncherNames -contains $name) { return "ランチャー" }
    if ($MediaNames -contains $name) { return "録画/音楽/Overlay" }
    if ($SyncDownloadNames -contains $name) { return "同期/Download" }
    if ($UtilityNames -contains $name) { return "ユーティリティ" }
    return "その他"
}

function Test-Recommend($name, $memory) {
    if ($browserOption.Checked -and ($BrowserNames -contains $name)) { return $true }
    if ($chatOption.Checked -and ($ChatNames -contains $name)) { return $true }
    if ($mediaOption.Checked -and ($MediaNames -contains $name)) { return $true }
    if ($syncOption.Checked -and ($SyncDownloadNames -contains $name)) { return $true }
    if ($utilityOption.Checked -and ($UtilityNames -contains $name)) { return $true }
    if ($heavyOption.Checked -and ($memory -ge 250)) { return $true }
    return $false
}

function Get-CandidateProcesses {
    Get-Process |
        Where-Object {
            $_.MainWindowTitle -or
            $CandidateNames -contains $_.ProcessName -or
            (Get-MemoryMb $_) -ge 120
        } |
        Where-Object {
            $ProtectedNames -notcontains $_.ProcessName -and
            $_.Id -ne $PID
        } |
        Where-Object {
            try {
                $path = $_.Path
                -not ($path -and $path.StartsWith($env:windir, [System.StringComparison]::OrdinalIgnoreCase))
            } catch {
                $true
            }
        } |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 120
}

function Get-ActivePowerSchemeGuid {
    $line = powercfg /getactivescheme 2>$null
    if ($line -match "([0-9a-fA-F-]{36})") { return $Matches[1] }
    return $null
}

function Set-HighPerformancePower {
    $script:PreviousPowerScheme = Get-ActivePowerSchemeGuid

    $schemes = powercfg /list 2>$null
    $highPerformanceGuid = $null
    foreach ($line in $schemes) {
        if ($line -match "([0-9a-fA-F-]{36}).*(High performance|高パフォーマンス)") {
            $highPerformanceGuid = $Matches[1]
            break
        }
    }

    if (-not $highPerformanceGuid) {
        $highPerformanceGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    }

    powercfg /setactive $highPerformanceGuid 2>$null
    return $highPerformanceGuid
}

function Empty-WorkingSets {
    $signature = @"
using System;
using System.Runtime.InteropServices;
public static class PsApi {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@
    if (-not ("PsApi" -as [type])) {
        Add-Type $signature
    }

    $count = 0
    Get-Process | ForEach-Object {
        try {
            if ([PsApi]::EmptyWorkingSet($_.Handle)) { $count++ }
        } catch {}
    }
    return $count
}

$script:PreviousPowerScheme = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = "FPS Boost Tool"
$form.Size = New-Object System.Drawing.Size(920, 650)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(840, 560)

$title = New-Object System.Windows.Forms.Label
$title.Text = "FPS Boost Tool"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(360, 32)
$form.Controls.Add($title)

$summary = New-Object System.Windows.Forms.Label
$summary.Text = "ゲーム起動前の軽量化ツールです。Windows/Vanguard/ドライバ/このツール関連は終了候補から除外します。"
$summary.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$summary.Location = New-Object System.Drawing.Point(18, 52)
$summary.Size = New-Object System.Drawing.Size(860, 24)
$form.Controls.Add($summary)

$systemLabel = New-Object System.Windows.Forms.Label
$systemLabel.Text = Get-SystemSummary
$systemLabel.Location = New-Object System.Drawing.Point(18, 80)
$systemLabel.Size = New-Object System.Drawing.Size(860, 22)
$form.Controls.Add($systemLabel)

$optionsGroup = New-Object System.Windows.Forms.GroupBox
$optionsGroup.Text = "おすすめ選択に含めるもの"
$optionsGroup.Location = New-Object System.Drawing.Point(18, 110)
$optionsGroup.Size = New-Object System.Drawing.Size(864, 72)
$optionsGroup.Anchor = "Top, Left, Right"
$form.Controls.Add($optionsGroup)

$browserOption = New-Object System.Windows.Forms.CheckBox
$browserOption.Text = "ブラウザ"
$browserOption.Checked = $true
$browserOption.Location = New-Object System.Drawing.Point(14, 22)
$browserOption.Size = New-Object System.Drawing.Size(90, 22)
$optionsGroup.Controls.Add($browserOption)

$chatOption = New-Object System.Windows.Forms.CheckBox
$chatOption.Text = "チャット"
$chatOption.Checked = $true
$chatOption.Location = New-Object System.Drawing.Point(112, 22)
$chatOption.Size = New-Object System.Drawing.Size(84, 22)
$optionsGroup.Controls.Add($chatOption)

$mediaOption = New-Object System.Windows.Forms.CheckBox
$mediaOption.Text = "録画/Overlay"
$mediaOption.Checked = $true
$mediaOption.Location = New-Object System.Drawing.Point(204, 22)
$mediaOption.Size = New-Object System.Drawing.Size(110, 22)
$optionsGroup.Controls.Add($mediaOption)

$syncOption = New-Object System.Windows.Forms.CheckBox
$syncOption.Text = "同期/Download"
$syncOption.Checked = $true
$syncOption.Location = New-Object System.Drawing.Point(322, 22)
$syncOption.Size = New-Object System.Drawing.Size(125, 22)
$optionsGroup.Controls.Add($syncOption)

$utilityOption = New-Object System.Windows.Forms.CheckBox
$utilityOption.Text = "ユーティリティ"
$utilityOption.Checked = $false
$utilityOption.Location = New-Object System.Drawing.Point(456, 22)
$utilityOption.Size = New-Object System.Drawing.Size(112, 22)
$optionsGroup.Controls.Add($utilityOption)

$heavyOption = New-Object System.Windows.Forms.CheckBox
$heavyOption.Text = "大容量(250MB+)"
$heavyOption.Checked = $false
$heavyOption.Location = New-Object System.Drawing.Point(576, 22)
$heavyOption.Size = New-Object System.Drawing.Size(140, 22)
$optionsGroup.Controls.Add($heavyOption)

$optionHelp = New-Object System.Windows.Forms.Label
$optionHelp.Text = "手動チェックしたアプリはいつでも終了できます。未保存データがあるアプリは閉じる前に保存してください。"
$optionHelp.Location = New-Object System.Drawing.Point(14, 46)
$optionHelp.Size = New-Object System.Drawing.Size(820, 18)
$optionsGroup.Controls.Add($optionHelp)

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(18, 194)
$list.Size = New-Object System.Drawing.Size(864, 288)
$list.Anchor = "Top, Bottom, Left, Right"
$list.CheckBoxes = $true
$list.FullRowSelect = $true
$list.GridLines = $true
$list.View = "Details"
[void]$list.Columns.Add("終了", 52)
[void]$list.Columns.Add("アプリ", 170)
[void]$list.Columns.Add("種類", 140)
[void]$list.Columns.Add("PID", 70)
[void]$list.Columns.Add("メモリ MB", 100)
[void]$list.Columns.Add("CPU 秒", 90)
[void]$list.Columns.Add("ウィンドウ", 220)
$form.Controls.Add($list)

$status = New-Object System.Windows.Forms.Label
$status.Text = ""
$status.Location = New-Object System.Drawing.Point(18, 494)
$status.Size = New-Object System.Drawing.Size(864, 34)
$status.Anchor = "Bottom, Left, Right"
$form.Controls.Add($status)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "更新"
$refreshButton.Location = New-Object System.Drawing.Point(18, 548)
$refreshButton.Size = New-Object System.Drawing.Size(86, 32)
$refreshButton.Anchor = "Bottom, Left"
$form.Controls.Add($refreshButton)

$recommendedButton = New-Object System.Windows.Forms.Button
$recommendedButton.Text = "おすすめ選択"
$recommendedButton.Location = New-Object System.Drawing.Point(112, 548)
$recommendedButton.Size = New-Object System.Drawing.Size(118, 32)
$recommendedButton.Anchor = "Bottom, Left"
$form.Controls.Add($recommendedButton)

$quickBoostButton = New-Object System.Windows.Forms.Button
$quickBoostButton.Text = "Quick Boost"
$quickBoostButton.Location = New-Object System.Drawing.Point(238, 548)
$quickBoostButton.Size = New-Object System.Drawing.Size(110, 32)
$quickBoostButton.Anchor = "Bottom, Left"
$form.Controls.Add($quickBoostButton)

$memoryButton = New-Object System.Windows.Forms.Button
$memoryButton.Text = "メモリ整理"
$memoryButton.Location = New-Object System.Drawing.Point(356, 548)
$memoryButton.Size = New-Object System.Drawing.Size(104, 32)
$memoryButton.Anchor = "Bottom, Left"
$form.Controls.Add($memoryButton)

$powerButton = New-Object System.Windows.Forms.Button
$powerButton.Text = "高パフォーマンス"
$powerButton.Location = New-Object System.Drawing.Point(468, 548)
$powerButton.Size = New-Object System.Drawing.Size(132, 32)
$powerButton.Anchor = "Bottom, Left"
$form.Controls.Add($powerButton)

$restorePowerButton = New-Object System.Windows.Forms.Button
$restorePowerButton.Text = "電源を戻す"
$restorePowerButton.Location = New-Object System.Drawing.Point(608, 548)
$restorePowerButton.Size = New-Object System.Drawing.Size(110, 32)
$restorePowerButton.Anchor = "Bottom, Left"
$form.Controls.Add($restorePowerButton)

$settingsButton = New-Object System.Windows.Forms.Button
$settingsButton.Text = "ゲーム設定"
$settingsButton.Location = New-Object System.Drawing.Point(726, 548)
$settingsButton.Size = New-Object System.Drawing.Size(98, 32)
$settingsButton.Anchor = "Bottom, Right"
$form.Controls.Add($settingsButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "選択終了"
$closeButton.Location = New-Object System.Drawing.Point(830, 548)
$closeButton.Size = New-Object System.Drawing.Size(52, 32)
$closeButton.Anchor = "Bottom, Right"
$form.Controls.Add($closeButton)

function Refresh-List {
    $list.Items.Clear()
    $processes = Get-CandidateProcesses
    foreach ($p in $processes) {
        $cpu = if ($null -eq $p.CPU) { "" } else { [math]::Round($p.CPU, 1).ToString() }
        $item = New-Object System.Windows.Forms.ListViewItem("")
        [void]$item.SubItems.Add($p.ProcessName)
        [void]$item.SubItems.Add((Get-Category $p.ProcessName))
        [void]$item.SubItems.Add($p.Id.ToString())
        [void]$item.SubItems.Add((Get-MemoryMb $p).ToString())
        [void]$item.SubItems.Add($cpu)
        [void]$item.SubItems.Add($p.MainWindowTitle)
        $item.Tag = $p.Id
        $list.Items.Add($item) | Out-Null
    }

    $systemLabel.Text = Get-SystemSummary
    $total = [math]::Round(($processes | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
    $status.Text = "候補: $($processes.Count) 件 / 表示中プロセス合計メモリ: $total MB"
}

function Select-Recommended {
    foreach ($item in $list.Items) {
        $name = $item.SubItems[1].Text
        $memory = [double]$item.SubItems[4].Text
        $item.Checked = Test-Recommend $name $memory
    }
    $status.Text = "おすすめ候補を選択しました。閉じる前に内容を確認してください。"
}

function Close-CheckedApps {
    $selected = @()
    foreach ($item in $list.CheckedItems) {
        $selected += [int]$item.Tag
    }

    if ($selected.Count -eq 0) {
        $status.Text = "終了するアプリが選択されていません。"
        return 0
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        "$($selected.Count) 件のアプリを終了します。未保存データがあるアプリは失われることがあります。続行しますか？",
        "確認",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return 0 }

    $closed = 0
    foreach ($pidToStop in $selected) {
        try {
            $p = Get-Process -Id $pidToStop
            if ($ProtectedNames -contains $p.ProcessName) { continue }
            if ($p.MainWindowHandle -ne 0) {
                [void]$p.CloseMainWindow()
                Start-Sleep -Milliseconds 700
                $p.Refresh()
            }
            if (-not $p.HasExited) {
                Stop-Process -Id $pidToStop -Force
            }
            $closed++
        } catch {}
    }

    Refresh-List
    $status.Text = "終了処理が完了しました。終了できた件数: $closed"
    return $closed
}

$refreshButton.Add_Click({ Refresh-List })

$recommendedButton.Add_Click({ Select-Recommended })

$quickBoostButton.Add_Click({
    Select-Recommended
    $guid = Set-HighPerformancePower
    $count = Empty-WorkingSets
    $status.Text = "Quick Boost完了: 電源=高パフォーマンス / メモリ整理=$count プロセス。必要なら選択終了を押してください。"
    Refresh-List
})

$memoryButton.Add_Click({
    $count = Empty-WorkingSets
    [System.GC]::Collect()
    $status.Text = "メモリ整理を実行しました。対象プロセス数: $count"
    Refresh-List
})

$powerButton.Add_Click({
    $guid = Set-HighPerformancePower
    $status.Text = "電源プランを高パフォーマンスに切り替えました。GUID: $guid"
})

$restorePowerButton.Add_Click({
    if ($script:PreviousPowerScheme) {
        powercfg /setactive $script:PreviousPowerScheme 2>$null
        $status.Text = "電源プランを元に戻しました。GUID: $script:PreviousPowerScheme"
    } else {
        $status.Text = "このツールを開いてから変更前の電源プランを記録していません。"
    }
})

$settingsButton.Add_Click({
    Start-Process "ms-settings:gaming-gamebar"
    Start-Sleep -Milliseconds 300
    Start-Process "ms-settings:gaming-gamemode"
    $status.Text = "Windowsのゲーム設定を開きました。設定変更は手動で確認してください。"
})

$closeButton.Add_Click({ [void](Close-CheckedApps) })

Refresh-List
[void]$form.ShowDialog()
