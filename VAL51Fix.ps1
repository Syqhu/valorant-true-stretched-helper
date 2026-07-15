Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-Log($message) {
    $time = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$time] $message`r`n")
}

function Show-Warning($message, $title) {
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        $title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

function Confirm-Action($message, $title) {
    return [System.Windows.Forms.MessageBox]::Show(
        $message,
        $title,
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
}

function Run-ConsoleCommand($title, $commands, $needsRestart) {
    if (-not (Test-IsAdministrator)) {
        Show-Warning "Please run this tool as administrator. Start-VAL51Fix.cmd will request admin rights." $title
        Add-Log "${title}: stopped because administrator rights are missing."
        return
    }

    $confirmText = "$title will run. Close VALORANT and Riot Client first."
    if ($needsRestart) {
        $confirmText += "`r`n`r`nRestart your PC after this step."
    }

    $result = Confirm-Action $confirmText $title
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Add-Log "${title}: cancelled."
        return
    }

    foreach ($command in $commands) {
        Add-Log "Run: $command"
        $output = cmd.exe /c $command 2>&1
        if ($output) {
            foreach ($line in $output) {
                Add-Log ([string]$line)
            }
        }
    }

    if ($needsRestart) {
        Add-Log "Done. Restart your PC before opening VALORANT manually."
    } else {
        Add-Log "Done. Open Riot Client manually and test again."
    }
}

function Close-RiotProcesses {
    $targets = @(
        "VALORANT-Win64-Shipping",
        "VALORANT",
        "RiotClientServices",
        "RiotClientUx",
        "RiotClientUxRender",
        "Riot Client"
    )

    $result = Confirm-Action "This will close VALORANT and Riot Client processes. Do not run this while in a match." "Close Riot Client"
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Add-Log "Close Riot Client: cancelled."
        return
    }

    $closed = 0
    foreach ($name in $targets) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Add-Log "Close: $($_.ProcessName) PID $($_.Id)"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            $closed++
        }
    }

    Add-Log "Closed processes: $closed. Open Riot Client manually."
}

function Backup-RiotClientCache {
    $result = Confirm-Action "This will close Riot Client and move local Riot Client Config/Data/HttpCache to a backup folder. You will need to sign in again." "Backup Riot Cache"
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Add-Log "Backup Riot Cache: cancelled."
        return
    }

    Close-RiotProcesses

    $root = Join-Path $env:LOCALAPPDATA "Riot Games\Riot Client"
    if (-not (Test-Path -LiteralPath $root)) {
        Add-Log "Riot Client local folder was not found: $root"
        return
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $root "Backups\VAL51-$stamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $names = @("Config", "Data", "HttpCache")
    foreach ($name in $names) {
        $source = Join-Path $root $name
        if (Test-Path -LiteralPath $source) {
            $dest = Join-Path $backupRoot $name
            Add-Log "Move: $source -> $dest"
            Move-Item -LiteralPath $source -Destination $dest -Force -ErrorAction SilentlyContinue
        } else {
            Add-Log "Skip missing: $source"
        }
    }

    Add-Log "Done. Backup folder: $backupRoot"
    Add-Log "Open Riot Client manually and sign in again."
}

function Show-NetworkSnapshot {
    Add-Log "Network snapshot started."

    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        Add-Log "Adapter: $($adapter.Name) / $($adapter.InterfaceDescription) / LinkSpeed $($adapter.LinkSpeed)"
    }

    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses.Count -gt 0 }
    foreach ($entry in $dns) {
        Add-Log "DNS: $($entry.InterfaceAlias) -> $($entry.ServerAddresses -join ', ')"
    }

    $pingTargets = @("1.1.1.1", "8.8.8.8", "auth.riotgames.com")
    foreach ($target in $pingTargets) {
        $ok = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        Add-Log "Ping ${target}: $ok"
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "VAL51 Fix Helper"
$form.Size = New-Object System.Drawing.Size(820, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)

$title = New-Object System.Windows.Forms.Label
$title.Text = "VAL51 Fix Helper"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(760, 34)
$form.Controls.Add($title)

$note = New-Object System.Windows.Forms.Label
$note.Text = "Safe network/Riot Client repair. No VALORANT launch, Vanguard control, bypass, registry edit, or INI edit."
$note.Location = New-Object System.Drawing.Point(18, 54)
$note.Size = New-Object System.Drawing.Size(760, 28)
$form.Controls.Add($note)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close Riot"
$closeButton.Location = New-Object System.Drawing.Point(18, 96)
$closeButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($closeButton)

$flushDnsButton = New-Object System.Windows.Forms.Button
$flushDnsButton.Text = "Repair DNS Cache"
$flushDnsButton.Location = New-Object System.Drawing.Point(180, 96)
$flushDnsButton.Size = New-Object System.Drawing.Size(170, 36)
$form.Controls.Add($flushDnsButton)

$winsockButton = New-Object System.Windows.Forms.Button
$winsockButton.Text = "Reset Winsock/IP"
$winsockButton.Location = New-Object System.Drawing.Point(362, 96)
$winsockButton.Size = New-Object System.Drawing.Size(170, 36)
$form.Controls.Add($winsockButton)

$snapshotButton = New-Object System.Windows.Forms.Button
$snapshotButton.Text = "Network Check"
$snapshotButton.Location = New-Object System.Drawing.Point(544, 96)
$snapshotButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($snapshotButton)

$statusButton = New-Object System.Windows.Forms.Button
$statusButton.Text = "Riot Status"
$statusButton.Location = New-Object System.Drawing.Point(18, 144)
$statusButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($statusButton)

$firewallButton = New-Object System.Windows.Forms.Button
$firewallButton.Text = "Firewall Settings"
$firewallButton.Location = New-Object System.Drawing.Point(180, 144)
$firewallButton.Size = New-Object System.Drawing.Size(170, 36)
$form.Controls.Add($firewallButton)

$adapterButton = New-Object System.Windows.Forms.Button
$adapterButton.Text = "Network Settings"
$adapterButton.Location = New-Object System.Drawing.Point(362, 144)
$adapterButton.Size = New-Object System.Drawing.Size(170, 36)
$form.Controls.Add($adapterButton)

$cacheButton = New-Object System.Windows.Forms.Button
$cacheButton.Text = "Backup Riot Cache"
$cacheButton.Location = New-Object System.Drawing.Point(544, 144)
$cacheButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($cacheButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = "Clear Log"
$clearButton.Location = New-Object System.Drawing.Point(18, 186)
$clearButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($clearButton)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(18, 236)
$logBox.Size = New-Object System.Drawing.Size(760, 304)
$logBox.Anchor = "Top, Left, Right, Bottom"
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

$footer = New-Object System.Windows.Forms.Label
$footer.Location = New-Object System.Drawing.Point(18, 548)
$footer.Size = New-Object System.Drawing.Size(760, 28)
$footer.Anchor = "Bottom, Left, Right"
$footer.Text = "Order: Close Riot -> Repair DNS Cache -> open Riot Client manually. Use Winsock/IP reset only if DNS repair fails."
$form.Controls.Add($footer)

$closeButton.Add_Click({ Close-RiotProcesses })

$flushDnsButton.Add_Click({
    Run-ConsoleCommand "Repair DNS Cache" @(
        "ipconfig /flushdns",
        "ipconfig /registerdns"
    ) $false
})

$winsockButton.Add_Click({
    Run-ConsoleCommand "Reset Winsock/IP" @(
        "netsh winsock reset",
        "netsh int ip reset",
        "ipconfig /release",
        "ipconfig /renew",
        "ipconfig /flushdns"
    ) $true
})

$snapshotButton.Add_Click({ Show-NetworkSnapshot })

$statusButton.Add_Click({
    Start-Process "https://status.riotgames.com/valorant"
    Add-Log "Opened Riot Games Service Status."
})

$firewallButton.Add_Click({
    Start-Process "control.exe" "firewall.cpl"
    Add-Log "Opened Windows Defender Firewall settings. Check that Riot Client and VALORANT are not blocked."
})

$adapterButton.Add_Click({
    Start-Process "ms-settings:network"
    Add-Log "Opened Windows network settings. Try disabling VPN or proxy before testing."
})

$cacheButton.Add_Click({ Backup-RiotClientCache })

$clearButton.Add_Click({ $logBox.Clear() })

Add-Log "Started. Administrator: $(Test-IsAdministrator)"
Add-Log "VAL51 is often a Riot platform/network connection issue. Start with Close Riot and Repair DNS Cache."

[void]$form.ShowDialog()
