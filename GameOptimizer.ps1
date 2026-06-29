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
    "NVDisplay.Container", "nvcontainer", "Razer Synapse Service",
    "Cloudflare WARP", "warp-svc", "warp-taskbar", "CCleaner_service",
    "powershell", "pwsh", "WindowsTerminal", "OpenConsole",
    "Codex", "codex", "node"
)

$GoodCandidates = @(
    "chrome", "msedge", "firefox", "brave", "opera", "vivaldi",
    "Discord", "Slack", "Teams", "Spotify", "Steam", "EpicGamesLauncher",
    "Battle.net", "RiotClientServices", "Overwolf", "NVIDIA Overlay",
    "PhoneExperienceHost", "YourPhone", "OneDrive", "Dropbox", "GoogleDriveFS",
    "fdm", "uTorrent", "qbittorrent", "obs64", "obs32",
    "lghub", "lghub_agent", "lghub_updater", "GameManagerService",
    "AdobeCollabSync", "Creative Cloud", "CCXProcess", "EpicWebHelper"
)

$BrowserNames = @("chrome", "msedge", "firefox", "brave", "opera", "vivaldi")
$ChatNames = @("Discord", "Slack", "Teams")
$LauncherNames = @("Steam", "EpicGamesLauncher", "Battle.net", "RiotClientServices", "EpicWebHelper")
$MediaNames = @("Spotify", "obs64", "obs32")
$SyncDownloadNames = @("OneDrive", "Dropbox", "GoogleDriveFS", "fdm", "uTorrent", "qbittorrent", "AdobeCollabSync", "Creative Cloud", "CCXProcess")
$OverlayUtilityNames = @("Overwolf", "NVIDIA Overlay", "PhoneExperienceHost", "YourPhone", "lghub", "lghub_agent", "lghub_updater", "GameManagerService")

function Get-MemoryMb($process) {
    if ($null -eq $process.WorkingSet64) { return 0 }
    return [math]::Round($process.WorkingSet64 / 1MB, 1)
}

function Get-Category($name) {
    if ($BrowserNames -contains $name) { return "ブラウザ" }
    if ($ChatNames -contains $name) { return "チャット" }
    if ($LauncherNames -contains $name) { return "ランチャー" }
    if ($MediaNames -contains $name) { return "音楽/録画" }
    if ($SyncDownloadNames -contains $name) { return "同期/ダウンロード" }
    if ($OverlayUtilityNames -contains $name) { return "オーバーレイ/ユーティリティ" }
    return "その他"
}

function Test-OptionMatch($name, $memory) {
    if ($browserOption.Checked -and ($BrowserNames -contains $name)) { return $true }
    if ($chatOption.Checked -and ($ChatNames -contains $name)) { return $true }
    if ($launcherOption.Checked -and ($LauncherNames -contains $name)) { return $true }
    if ($mediaOption.Checked -and ($MediaNames -contains $name)) { return $true }
    if ($syncOption.Checked -and ($SyncDownloadNames -contains $name)) { return $true }
    if ($overlayOption.Checked -and ($OverlayUtilityNames -contains $name)) { return $true }
    if ($heavyOption.Checked -and ($memory -ge 250)) { return $true }
    return $false
}

function Get-CandidateProcesses {
    Get-Process |
        Where-Object {
            $_.MainWindowTitle -or
            $GoodCandidates -contains $_.ProcessName -or
            (Get-MemoryMb $_) -ge 80
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
$form.Text = "ゲーム最適化ツール"
$form.Size = New-Object System.Drawing.Size(860, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(760, 520)

$title = New-Object System.Windows.Forms.Label
$title.Text = "ゲーム最適化ツール"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(360, 32)
$form.Controls.Add($title)

$summary = New-Object System.Windows.Forms.Label
$summary.Text = "消しちゃいけない Windows / ドライバ / このツール関連は除外しています。残りから終了したいアプリを選んでください。"
$summary.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$summary.Location = New-Object System.Drawing.Point(18, 52)
$summary.Size = New-Object System.Drawing.Size(800, 28)
$form.Controls.Add($summary)

$optionsGroup = New-Object System.Windows.Forms.GroupBox
$optionsGroup.Text = "消すオプション"
$optionsGroup.Location = New-Object System.Drawing.Point(18, 82)
$optionsGroup.Size = New-Object System.Drawing.Size(808, 72)
$optionsGroup.Anchor = "Top, Left, Right"
$form.Controls.Add($optionsGroup)

$browserOption = New-Object System.Windows.Forms.CheckBox
$browserOption.Text = "ブラウザ"
$browserOption.Checked = $true
$browserOption.Location = New-Object System.Drawing.Point(14, 22)
$browserOption.Size = New-Object System.Drawing.Size(92, 22)
$optionsGroup.Controls.Add($browserOption)

$chatOption = New-Object System.Windows.Forms.CheckBox
$chatOption.Text = "チャット"
$chatOption.Checked = $true
$chatOption.Location = New-Object System.Drawing.Point(112, 22)
$chatOption.Size = New-Object System.Drawing.Size(86, 22)
$optionsGroup.Controls.Add($chatOption)

$launcherOption = New-Object System.Windows.Forms.CheckBox
$launcherOption.Text = "ランチャー"
$launcherOption.Checked = $false
$launcherOption.Location = New-Object System.Drawing.Point(204, 22)
$launcherOption.Size = New-Object System.Drawing.Size(100, 22)
$optionsGroup.Controls.Add($launcherOption)

$mediaOption = New-Object System.Windows.Forms.CheckBox
$mediaOption.Text = "音楽/録画"
$mediaOption.Checked = $true
$mediaOption.Location = New-Object System.Drawing.Point(310, 22)
$mediaOption.Size = New-Object System.Drawing.Size(96, 22)
$optionsGroup.Controls.Add($mediaOption)

$syncOption = New-Object System.Windows.Forms.CheckBox
$syncOption.Text = "同期/ダウンロード"
$syncOption.Checked = $true
$syncOption.Location = New-Object System.Drawing.Point(412, 22)
$syncOption.Size = New-Object System.Drawing.Size(130, 22)
$optionsGroup.Controls.Add($syncOption)

$overlayOption = New-Object System.Windows.Forms.CheckBox
$overlayOption.Text = "オーバーレイ"
$overlayOption.Checked = $true
$overlayOption.Location = New-Object System.Drawing.Point(548, 22)
$overlayOption.Size = New-Object System.Drawing.Size(112, 22)
$optionsGroup.Controls.Add($overlayOption)

$heavyOption = New-Object System.Windows.Forms.CheckBox
$heavyOption.Text = "大容量(250MB+)"
$heavyOption.Checked = $false
$heavyOption.Location = New-Object System.Drawing.Point(666, 22)
$heavyOption.Size = New-Object System.Drawing.Size(130, 22)
$optionsGroup.Controls.Add($heavyOption)

$optionHelp = New-Object System.Windows.Forms.Label
$optionHelp.Text = "チェックした種類だけが「おすすめ選択」で選ばれます。手動チェックしたものはいつでも終了できます。"
$optionHelp.Location = New-Object System.Drawing.Point(14, 46)
$optionHelp.Size = New-Object System.Drawing.Size(760, 18)
$optionsGroup.Controls.Add($optionHelp)

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(18, 164)
$list.Size = New-Object System.Drawing.Size(808, 288)
$list.Anchor = "Top, Bottom, Left, Right"
$list.CheckBoxes = $true
$list.FullRowSelect = $true
$list.GridLines = $true
$list.View = "Details"
[void]$list.Columns.Add("終了", 52)
[void]$list.Columns.Add("アプリ", 170)
[void]$list.Columns.Add("種類", 150)
[void]$list.Columns.Add("PID", 80)
[void]$list.Columns.Add("メモリ MB", 100)
[void]$list.Columns.Add("CPU 秒", 90)
[void]$list.Columns.Add("ウィンドウ", 180)
$form.Controls.Add($list)

$status = New-Object System.Windows.Forms.Label
$status.Text = ""
$status.Location = New-Object System.Drawing.Point(18, 462)
$status.Size = New-Object System.Drawing.Size(808, 32)
$status.Anchor = "Bottom, Left, Right"
$form.Controls.Add($status)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "更新"
$refreshButton.Location = New-Object System.Drawing.Point(18, 508)
$refreshButton.Size = New-Object System.Drawing.Size(92, 32)
$refreshButton.Anchor = "Bottom, Left"
$form.Controls.Add($refreshButton)

$selectRecommendedButton = New-Object System.Windows.Forms.Button
$selectRecommendedButton.Text = "おすすめ選択"
$selectRecommendedButton.Location = New-Object System.Drawing.Point(120, 508)
$selectRecommendedButton.Size = New-Object System.Drawing.Size(120, 32)
$selectRecommendedButton.Anchor = "Bottom, Left"
$form.Controls.Add($selectRecommendedButton)

$memoryButton = New-Object System.Windows.Forms.Button
$memoryButton.Text = "メモリ整理"
$memoryButton.Location = New-Object System.Drawing.Point(250, 508)
$memoryButton.Size = New-Object System.Drawing.Size(104, 32)
$memoryButton.Anchor = "Bottom, Left"
$form.Controls.Add($memoryButton)

$powerButton = New-Object System.Windows.Forms.Button
$powerButton.Text = "高パフォーマンス"
$powerButton.Location = New-Object System.Drawing.Point(364, 508)
$powerButton.Size = New-Object System.Drawing.Size(132, 32)
$powerButton.Anchor = "Bottom, Left"
$form.Controls.Add($powerButton)

$restorePowerButton = New-Object System.Windows.Forms.Button
$restorePowerButton.Text = "電源を戻す"
$restorePowerButton.Location = New-Object System.Drawing.Point(506, 508)
$restorePowerButton.Size = New-Object System.Drawing.Size(128, 32)
$restorePowerButton.Anchor = "Bottom, Left"
$form.Controls.Add($restorePowerButton)

$killButton = New-Object System.Windows.Forms.Button
$killButton.Text = "選択アプリを終了"
$killButton.Location = New-Object System.Drawing.Point(658, 508)
$killButton.Size = New-Object System.Drawing.Size(168, 32)
$killButton.Anchor = "Bottom, Right"
$form.Controls.Add($killButton)

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

    $total = [math]::Round(($processes | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
    $status.Text = "候補: $($processes.Count) 件 / 表示中プロセス合計メモリ: $total MB"
}

$refreshButton.Add_Click({ Refresh-List })

$selectRecommendedButton.Add_Click({
    foreach ($item in $list.Items) {
        $name = $item.SubItems[1].Text
        $memory = [double]$item.SubItems[4].Text
        $item.Checked = Test-OptionMatch $name $memory
    }
    $status.Text = "消すオプションに合う候補を選択しました。内容を確認してから終了してください。"
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

$killButton.Add_Click({
    $selected = @()
    foreach ($item in $list.CheckedItems) {
        $selected += [int]$item.Tag
    }

    if ($selected.Count -eq 0) {
        $status.Text = "終了するアプリが選択されていません。"
        return
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        "$($selected.Count) 件のアプリを終了します。未保存データがあるアプリは失われることがあります。続行しますか？",
        "確認",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

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

    $status.Text = "終了処理が完了しました。終了できた件数: $closed"
    Refresh-List
})

Refresh-List
[void]$form.ShowDialog()
