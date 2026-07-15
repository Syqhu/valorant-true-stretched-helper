Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

function Get-ValorantConfigFiles {
    $root = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
    if (-not (Test-Path -LiteralPath $root)) { return @() }

    return @(Get-ChildItem -LiteralPath $root -Recurse -Filter "GameUserSettings.ini" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
}

function Get-SelectedResolution {
    $text = [string]$resolutionBox.SelectedItem
    if ($text -match "(\d+)x(\d+)") {
        return @{ Width = [int]$Matches[1]; Height = [int]$Matches[2] }
    }
    return @{ Width = 1280; Height = 1080 }
}

function Get-IniValues($path) {
    $values = @{}
    if (-not (Test-Path -LiteralPath $path)) { return $values }

    Get-Content -LiteralPath $path | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            $values[$Matches[1]] = $Matches[2]
        }
    }

    return $values
}

function Get-IniFillState($path) {
    $values = Get-IniValues $path
    $letterbox = [string]$values["bShouldLetterbox"]
    $confirmed = [string]$values["bLastConfirmedShouldLetterbox"]

    if ($letterbox -ieq "False" -and $confirmed -ieq "False") { return "Fill" }
    if ($letterbox -ieq "True" -or $confirmed -ieq "True") { return "Letterbox" }
    return "Unknown"
}

function Get-IniResolutionText($path) {
    $values = Get-IniValues $path
    $x = [string]$values["ResolutionSizeX"]
    $y = [string]$values["ResolutionSizeY"]
    $desiredX = [string]$values["DesiredScreenWidth"]
    $desiredY = [string]$values["DesiredScreenHeight"]

    if ($x -and $y) {
        if ($desiredX -and $desiredY -and ($x -ne $desiredX -or $y -ne $desiredY)) {
            return "$($x)x$($y) / desired $($desiredX)x$($desiredY)"
        }
        return "$($x)x$($y)"
    }

    return "Unknown"
}

function Get-IniSnippet {
    $res = Get-SelectedResolution
    $fullscreenMode = if ([string]$displayModeBox.SelectedItem -eq "Windowed Fullscreen") { 1 } else { 2 }

    return @"
bShouldLetterbox=False
bLastConfirmedShouldLetterbox=False
ResolutionSizeX=$($res.Width)
ResolutionSizeY=$($res.Height)
LastUserConfirmedResolutionSizeX=$($res.Width)
LastUserConfirmedResolutionSizeY=$($res.Height)
WindowPosX=0
WindowPosY=0
LastConfirmedFullscreenMode=$fullscreenMode
PreferredFullscreenMode=$fullscreenMode
DesiredScreenWidth=$($res.Width)
DesiredScreenHeight=$($res.Height)
LastUserConfirmedDesiredScreenWidth=$($res.Width)
LastUserConfirmedDesiredScreenHeight=$($res.Height)
FullscreenMode=$fullscreenMode
bUseDesiredScreenHeight=False
"@
}

function Get-RelatedConfigPaths($selectedPath) {
    $paths = New-Object System.Collections.Generic.List[string]
    if ($selectedPath) { [void]$paths.Add($selectedPath) }

    $commonPath = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config\WindowsClient\GameUserSettings.ini"
    if ((Test-Path -LiteralPath $commonPath) -and ($paths -notcontains $commonPath)) {
        [void]$paths.Add($commonPath)
    }

    return @($paths)
}

function Escape-PowerShellSingleQuote($text) {
    return ([string]$text).Replace("'", "''")
}

function Get-ManualPatchCommand($selectedPath) {
    $res = Get-SelectedResolution
    $fullscreenMode = if ([string]$displayModeBox.SelectedItem -eq "Windowed Fullscreen") { 1 } else { 2 }
    $paths = Get-RelatedConfigPaths $selectedPath
    if ($paths.Count -eq 0) { return "" }

    $quotedPaths = @($paths | ForEach-Object { "'" + (Escape-PowerShellSingleQuote $_) + "'" })
    $pathText = $quotedPaths -join ", "

    return @"
# VALORANT / Riot Client を閉じてから実行してください。
`$paths = @($pathText)
`$values = [ordered]@{
    bShouldLetterbox = 'False'
    bLastConfirmedShouldLetterbox = 'False'
    ResolutionSizeX = '$($res.Width)'
    ResolutionSizeY = '$($res.Height)'
    LastUserConfirmedResolutionSizeX = '$($res.Width)'
    LastUserConfirmedResolutionSizeY = '$($res.Height)'
    WindowPosX = '0'
    WindowPosY = '0'
    LastConfirmedFullscreenMode = '$fullscreenMode'
    PreferredFullscreenMode = '$fullscreenMode'
    DesiredScreenWidth = '$($res.Width)'
    DesiredScreenHeight = '$($res.Height)'
    LastUserConfirmedDesiredScreenWidth = '$($res.Width)'
    LastUserConfirmedDesiredScreenHeight = '$($res.Height)'
    FullscreenMode = '$fullscreenMode'
    bUseDesiredScreenHeight = 'False'
}
foreach (`$path in `$paths) {
    if (-not (Test-Path -LiteralPath `$path)) { continue }
    attrib -R "`$path"
    `$lines = @(Get-Content -LiteralPath `$path)
    foreach (`$key in `$values.Keys) {
        `$pattern = '^{0}=' -f [regex]::Escape(`$key)
        `$found = `$false
        `$lines = @(`$lines | ForEach-Object {
            if (`$_ -match `$pattern) {
                `$found = `$true
                "`$key=`$(`$values[`$key])"
            } else {
                `$_
            }
        })
        if (-not `$found) {
            `$lines += "`$key=`$(`$values[`$key])"
        }
    }
    Set-Content -LiteralPath `$path -Value `$lines -Encoding UTF8
    attrib +R "`$path"
}
"@
}

function Refresh-ConfigList {
    $configList.Items.Clear()
    $files = Get-ValorantConfigFiles

    foreach ($file in $files) {
        $item = New-Object System.Windows.Forms.ListViewItem($file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
        [void]$item.SubItems.Add((Get-IniFillState $file.FullName))
        [void]$item.SubItems.Add((Get-IniResolutionText $file.FullName))
        [void]$item.SubItems.Add($file.IsReadOnly.ToString())
        [void]$item.SubItems.Add($file.FullName)
        $item.Tag = $file.FullName
        $configList.Items.Add($item) | Out-Null
    }

    $status.Text = "設定ファイル: $($files.Count) 件。最新アカウントINIと WindowsClient の両方を Fill にして、起動前に読み取り専用へ。"
}

function Get-SelectedConfigPath {
    if ($configList.SelectedItems.Count -gt 0) {
        return [string]$configList.SelectedItems[0].Tag
    }

    $files = Get-ValorantConfigFiles
    if ($files.Count -gt 0) { return $files[0].FullName }
    return $null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Manual Stretch Helper"
$form.Size = New-Object System.Drawing.Size(880, 640)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(820, 560)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Manual Stretch Helper"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(820, 32)
$form.Controls.Add($title)

$note = New-Object System.Windows.Forms.Label
$note.Text = "安全寄りの手動補助版です。VALORANT起動、Vanguard操作、レジストリ変更、ウィンドウ操作、INI自動編集はしません。"
$note.Location = New-Object System.Drawing.Point(18, 52)
$note.Size = New-Object System.Drawing.Size(820, 28)
$form.Controls.Add($note)

$resLabel = New-Object System.Windows.Forms.Label
$resLabel.Text = "解像度"
$resLabel.Location = New-Object System.Drawing.Point(18, 96)
$resLabel.Size = New-Object System.Drawing.Size(90, 24)
$form.Controls.Add($resLabel)

$resolutionBox = New-Object System.Windows.Forms.ComboBox
$resolutionBox.DropDownStyle = "DropDownList"
$resolutionBox.Location = New-Object System.Drawing.Point(112, 92)
$resolutionBox.Size = New-Object System.Drawing.Size(210, 26)
[void]$resolutionBox.Items.Add("1080x1080 (Square)")
[void]$resolutionBox.Items.Add("1280x1080 (Wide stretch)")
[void]$resolutionBox.Items.Add("1440x1080 (4:3)")
[void]$resolutionBox.Items.Add("1600x1080 (Wide stretch)")
[void]$resolutionBox.Items.Add("1280x960  (4:3)")
[void]$resolutionBox.Items.Add("1024x768  (4:3)")
[void]$resolutionBox.Items.Add("1280x1024 (5:4)")
$resolutionBox.SelectedIndex = 1
$form.Controls.Add($resolutionBox)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Text = "表示モード"
$modeLabel.Location = New-Object System.Drawing.Point(340, 96)
$modeLabel.Size = New-Object System.Drawing.Size(90, 24)
$form.Controls.Add($modeLabel)

$displayModeBox = New-Object System.Windows.Forms.ComboBox
$displayModeBox.DropDownStyle = "DropDownList"
$displayModeBox.Location = New-Object System.Drawing.Point(438, 92)
$displayModeBox.Size = New-Object System.Drawing.Size(190, 26)
[void]$displayModeBox.Items.Add("Windowed")
[void]$displayModeBox.Items.Add("Windowed Fullscreen")
$displayModeBox.SelectedIndex = 0
$form.Controls.Add($displayModeBox)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "INI一覧更新"
$refreshButton.Location = New-Object System.Drawing.Point(650, 90)
$refreshButton.Size = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($refreshButton)

$configList = New-Object System.Windows.Forms.ListView
$configList.Location = New-Object System.Drawing.Point(18, 136)
$configList.Size = New-Object System.Drawing.Size(828, 210)
$configList.Anchor = "Top, Left, Right"
$configList.FullRowSelect = $true
$configList.GridLines = $true
$configList.View = "Details"
[void]$configList.Columns.Add("更新日時", 140)
[void]$configList.Columns.Add("状態", 82)
[void]$configList.Columns.Add("解像度", 170)
[void]$configList.Columns.Add("読取専用", 78)
[void]$configList.Columns.Add("GameUserSettings.ini", 350)
$form.Controls.Add($configList)

$snippetBox = New-Object System.Windows.Forms.TextBox
$snippetBox.Location = New-Object System.Drawing.Point(18, 370)
$snippetBox.Size = New-Object System.Drawing.Size(828, 126)
$snippetBox.Anchor = "Top, Left, Right"
$snippetBox.Multiline = $true
$snippetBox.ScrollBars = "Vertical"
$snippetBox.ReadOnly = $true
$snippetBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$snippetBox.Text = Get-IniSnippet
$form.Controls.Add($snippetBox)

$copySnippetButton = New-Object System.Windows.Forms.Button
$copySnippetButton.Text = "INI値をコピー"
$copySnippetButton.Location = New-Object System.Drawing.Point(18, 516)
$copySnippetButton.Size = New-Object System.Drawing.Size(104, 32)
$form.Controls.Add($copySnippetButton)

$openIniButton = New-Object System.Windows.Forms.Button
$openIniButton.Text = "選択INIを開く"
$openIniButton.Location = New-Object System.Drawing.Point(130, 516)
$openIniButton.Size = New-Object System.Drawing.Size(104, 32)
$form.Controls.Add($openIniButton)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = "フォルダを開く"
$openFolderButton.Location = New-Object System.Drawing.Point(242, 516)
$openFolderButton.Size = New-Object System.Drawing.Size(104, 32)
$form.Controls.Add($openFolderButton)

$copyReadonlyButton = New-Object System.Windows.Forms.Button
$copyReadonlyButton.Text = "読取専用コマンド"
$copyReadonlyButton.Location = New-Object System.Drawing.Point(354, 516)
$copyReadonlyButton.Size = New-Object System.Drawing.Size(126, 32)
$form.Controls.Add($copyReadonlyButton)

$copyUnlockButton = New-Object System.Windows.Forms.Button
$copyUnlockButton.Text = "解除コマンド"
$copyUnlockButton.Location = New-Object System.Drawing.Point(488, 516)
$copyUnlockButton.Size = New-Object System.Drawing.Size(96, 32)
$form.Controls.Add($copyUnlockButton)

$copyPatchButton = New-Object System.Windows.Forms.Button
$copyPatchButton.Text = "Fill修正コマンド"
$copyPatchButton.Location = New-Object System.Drawing.Point(592, 516)
$copyPatchButton.Size = New-Object System.Drawing.Size(124, 32)
$form.Controls.Add($copyPatchButton)

$displaySettingsButton = New-Object System.Windows.Forms.Button
$displaySettingsButton.Text = "Windows画面設定"
$displaySettingsButton.Location = New-Object System.Drawing.Point(724, 516)
$displaySettingsButton.Size = New-Object System.Drawing.Size(122, 32)
$form.Controls.Add($displaySettingsButton)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(18, 566)
$status.Size = New-Object System.Drawing.Size(828, 36)
$status.Anchor = "Bottom, Left, Right"
$status.Text = ""
$form.Controls.Add($status)

$resolutionBox.Add_SelectedIndexChanged({
    $snippetBox.Text = Get-IniSnippet
})

$displayModeBox.Add_SelectedIndexChanged({
    $snippetBox.Text = Get-IniSnippet
})

$refreshButton.Add_Click({
    Refresh-ConfigList
})

$copySnippetButton.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($snippetBox.Text)
    $status.Text = "INIに貼り付ける値をクリップボードへコピーしました。保存は手動で行ってください。"
})

$openIniButton.Add_Click({
    $path = Get-SelectedConfigPath
    if ($path) {
        Start-Process notepad.exe $path
        $status.Text = "NotepadでINIを開きました。編集と保存は手動です。"
    } else {
        $status.Text = "GameUserSettings.ini が見つかりません。VALORANTを一度起動して設定を作成してください。"
    }
})

$openFolderButton.Add_Click({
    $path = Get-SelectedConfigPath
    if ($path) {
        Start-Process explorer.exe "/select,`"$path`""
    } else {
        Start-Process explorer.exe (Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config")
    }
})

$copyReadonlyButton.Add_Click({
    $path = Get-SelectedConfigPath
    if ($path) {
        $cmd = "attrib +R `"$path`""
        [System.Windows.Forms.Clipboard]::SetText($cmd)
        $status.Text = "読み取り専用にする手動コマンドをコピーしました。VALORANT起動中は実行しないでください。"
    } else {
        $status.Text = "INIが選択されていません。"
    }
})

$copyUnlockButton.Add_Click({
    $path = Get-SelectedConfigPath
    if ($path) {
        $cmd = "attrib -R `"$path`""
        [System.Windows.Forms.Clipboard]::SetText($cmd)
        $status.Text = "読み取り専用を解除する手動コマンドをコピーしました。"
    } else {
        $status.Text = "INIが選択されていません。"
    }
})

$copyPatchButton.Add_Click({
    $path = Get-SelectedConfigPath
    if ($path) {
        $cmd = Get-ManualPatchCommand $path
        [System.Windows.Forms.Clipboard]::SetText($cmd)
        $status.Text = "Fill修正コマンドをコピーしました。VALORANT/Riotを閉じた状態で手動実行してください。実行後は一覧更新で確認できます。"
    } else {
        $status.Text = "INIが選択されていません。"
    }
})

$displaySettingsButton.Add_Click({
    Start-Process "ms-settings:display"
    $status.Text = "Windows画面設定を開きました。解像度変更は手動で行ってください。"
})

Refresh-ConfigList
[void]$form.ShowDialog()
