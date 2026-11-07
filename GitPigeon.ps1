<#
  GitPigeon.ps1  -  delivers your git commits on schedule (Windows).
  Keep gitpigeon-push.ps1 in the same folder and the images in assets\. Start with GitPigeon.exe (or "Start GitPigeon.bat").

  Developed by : EMR Industries
  Version      : 1.1.3
  Built date   : 2026.11.07
#>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- app details (shown on the About tab) ----------
$AppName      = "GitPigeon"
$AppTagline   = "Delivers your Git commits on schedule."
$AppDeveloper = "EMR Industries"
$AppVersion   = "1.1.3"
$AppBuildDate = "2026.11.07"

# Remove the "downloaded from the internet" mark from GitPigeon's own files, so the
# "Unknown Publisher" security prompt stops appearing on the next launch.
# Only touches files in this folder.
Get-ChildItem -Path $PSScriptRoot -File -Recurse -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

$pushScript = Join-Path $PSScriptRoot "gitpigeon-push.ps1"
$logFile    = "$env:USERPROFILE\gitpigeon.log"
$taskPath    = "\GitPigeon\"
$oldTaskPath = "\GitAutoPush\"   # folder used by the pre-GitPigeon version

if (-not (Test-Path $pushScript)) {
    [System.Windows.Forms.MessageBox]::Show("gitpigeon-push.ps1 must be in the same folder as this tool.", "Missing file") | Out-Null
    exit
}

# Scheduled tasks run gitpigeon-push.ps1 as you, so warn if it lives outside your own profile
# (e.g. a shared drive or a folder other users can edit)
if (-not $pushScript.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Tip: keep these scripts in a folder only you can edit, for example:`n$env:LOCALAPPDATA\GitPigeon`n`nAnyone who can change gitpigeon-push.ps1 can run code as you when a schedule fires.",
        "Script location") | Out-Null
}

# ---------- form + helper ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "$AppName v$AppVersion"
$form.Size = New-Object System.Drawing.Size(645, 718)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

# App icon (title bar + taskbar) - kept in the assets folder
$iconPath = Join-Path $PSScriptRoot "assets\gitpigeon.ico"
if (Test-Path $iconPath) { $form.Icon = New-Object System.Drawing.Icon($iconPath) }

# ---------- tabs: Scheduler + About ----------
$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(6, 6)
$tabs.Size = New-Object System.Drawing.Size(618, 668)
$pageMain  = New-Object Windows.Forms.TabPage; $pageMain.Text  = "Scheduler"
$pageAbout = New-Object Windows.Forms.TabPage; $pageAbout.Text = "About"
$tabs.TabPages.AddRange(@($pageMain, $pageAbout))
$form.Controls.Add($tabs)

function Add-Ctl($ctl, $x, $y, $w, $h, $text = $null, $parent = $pageMain) {
    $ctl.Location = New-Object System.Drawing.Point($x, $y)
    $ctl.Size = New-Object System.Drawing.Size($w, $h)
    if ($text) { $ctl.Text = $text }
    $parent.Controls.Add($ctl)
    return $ctl
}

# ---------- About tab ----------
$lblName = Add-Ctl (New-Object Windows.Forms.Label) 30 40 380 50 $AppName $pageAbout
$lblName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24)
$lblTag = Add-Ctl (New-Object Windows.Forms.Label) 33 92 380 24 $AppTagline $pageAbout

# Large logo on the right, beside the name, version and build details
# Uses gitpigeon.png (the 256px frame inside the .ico is PNG-compressed and
# Icon.ToBitmap() renders it as noise on Windows PowerShell 5.1)
$logoPath = Join-Path $PSScriptRoot "assets\gitpigeon.png"
if ((Test-Path $logoPath) -or (Test-Path $iconPath)) {
    $logo = Add-Ctl (New-Object Windows.Forms.PictureBox) 420 40 150 150 $null $pageAbout
    $logo.SizeMode = "Zoom"
    if (Test-Path $logoPath) {
        # Load via memory so the PNG file isn't locked while the tool is open
        $bytes = [System.IO.File]::ReadAllBytes($logoPath)
        $logo.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,$bytes)))
    } else {
        # Fallback: 48px frame is stored as a normal bitmap, so it decodes correctly
        $logo.Image = (New-Object System.Drawing.Icon($iconPath, 48, 48)).ToBitmap()
    }
}
$lblTag.ForeColor = "DimGray"

$y = 150
foreach ($row in @(@("Developed by", $AppDeveloper), @("Version", $AppVersion), @("Built date", $AppBuildDate))) {
    Add-Ctl (New-Object Windows.Forms.Label) 33 $y 120 24 ($row[0] + " :") $pageAbout | Out-Null
    $val = Add-Ctl (New-Object Windows.Forms.Label) 160 $y 250 24 $row[1] $pageAbout
    $val.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
    $y += 30
}

$lblInfo = Add-Ctl (New-Object Windows.Forms.Label) 33 ($y + 25) 540 60 `
    "Works alongside TortoiseGit using Git for Windows.`nSchedules are stored in Task Scheduler under the GitPigeon folder.`nLog file: $logFile" $pageAbout
$lblInfo.ForeColor = "DimGray"

# ---------- repo settings ----------
Add-Ctl (New-Object Windows.Forms.Label) 15 18 80 20 "Repository" | Out-Null
$txtRepo   = Add-Ctl (New-Object Windows.Forms.TextBox) 100 15 400 24
$btnBrowse = Add-Ctl (New-Object Windows.Forms.Button) 510 14 80 26 "Browse..."

Add-Ctl (New-Object Windows.Forms.Label) 15 53 80 20 "Remote" | Out-Null
$txtRemote = Add-Ctl (New-Object Windows.Forms.TextBox) 100 50 120 24 "origin"
Add-Ctl (New-Object Windows.Forms.Label) 240 53 60 20 "Branch" | Out-Null
$txtBranch = Add-Ctl (New-Object Windows.Forms.TextBox) 300 50 200 24
Add-Ctl (New-Object Windows.Forms.Label) 300 76 220 18 "(leave empty = current branch)" | ForEach-Object { $_.ForeColor = "Gray" }

$chkCommit = Add-Ctl (New-Object Windows.Forms.CheckBox) 100 98 400 22 "Commit all changes before pushing"

# ---------- schedule ----------
$grp = Add-Ctl (New-Object Windows.Forms.GroupBox) 15 128 575 108 "Schedule"
# Row 1: start date + time (used by all three options)
$lblStart = New-Object Windows.Forms.Label; $lblStart.Text = "Start on"; $lblStart.Location = "15,25"; $lblStart.Size = "60,20"
# Date button - opens the GitPigeon calendar pop-up (defined below)
$script:selDate = [datetime]::Today
$btnDate = New-Object Windows.Forms.Button
$btnDate.Location = "80,20"; $btnDate.Size = "140,26"
$btnDate.TextAlign = "MiddleLeft"; $btnDate.UseVisualStyleBackColor = $true   # standard Windows button
function Update-DateButton { $btnDate.Text = " " + $script:selDate.ToString("yyyy.MM.dd  ddd") }
Update-DateButton

# Draw a standard drop-down chevron at the right edge (like a Windows combo box)
$btnDate.Add_Paint({ param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen([Drawing.SystemColors]::ControlText, 1.4)
    $cx = $s.Width - 15; $cy = [int]($s.Height / 2)
    $g.DrawLines($pen, [Drawing.PointF[]]@(
        (New-Object Drawing.PointF(($cx - 4), ($cy - 2))),
        (New-Object Drawing.PointF($cx, ($cy + 2))),
        (New-Object Drawing.PointF(($cx + 4), ($cy - 2)))))
    $pen.Dispose()
})
$lblAt    = New-Object Windows.Forms.Label; $lblAt.Text = "at"; $lblAt.Location = "228,25"; $lblAt.Size = "20,20"
$dtTime   = New-Object Windows.Forms.DateTimePicker; $dtTime.Format = "Time"; $dtTime.ShowUpDown = $true; $dtTime.Location = "252,21"; $dtTime.Size = "110,24"
$dtTime.Value = [datetime]::Today.AddHours(18)
# Row 2: how often
$rbDaily  = New-Object Windows.Forms.RadioButton; $rbDaily.Text = "Daily";  $rbDaily.Location = "15,51";  $rbDaily.Size = "65,22"; $rbDaily.Checked = $true
$rbHourly = New-Object Windows.Forms.RadioButton; $rbHourly.Text = "Every"; $rbHourly.Location = "90,51"; $rbHourly.Size = "60,22"
$numHours = New-Object Windows.Forms.NumericUpDown; $numHours.Minimum = 1; $numHours.Maximum = 24; $numHours.Value = 2; $numHours.Location = "150,50"; $numHours.Size = "50,24"
$lblHours = New-Object Windows.Forms.Label; $lblHours.Text = "hour(s)"; $lblHours.Location = "205,53"; $lblHours.Size = "55,20"
$rbOnce   = New-Object Windows.Forms.RadioButton; $rbOnce.Text = "Once only (on the start date)"; $rbOnce.Location = "275,51"; $rbOnce.Size = "220,22"
# Row 3: wake option (runs on battery are always allowed - see Save schedule)
$chkWake  = New-Object Windows.Forms.CheckBox; $chkWake.Text = "Wake the PC from sleep to push"; $chkWake.Location = "15,79"; $chkWake.Size = "300,22"
$grp.Controls.AddRange(@($lblStart, $btnDate, $lblAt, $dtTime, $rbDaily, $rbHourly, $numHours, $lblHours, $rbOnce, $chkWake))

# ---------- calendar pop-up ----------
# Standard Windows system colours only (follows the normal window style)
$cText   = [Drawing.SystemColors]::ControlText        # normal text
$cFaint  = [Drawing.SystemColors]::GrayText           # days outside the month
$cHover  = [Drawing.SystemColors]::ControlLight       # hover
$cSelBg  = [Drawing.SystemColors]::Highlight          # selected day (standard selection colour)
$cSelFg  = [Drawing.SystemColors]::HighlightText

$cal = New-Object Windows.Forms.Form
$cal.FormBorderStyle = "None"; $cal.ShowInTaskbar = $false; $cal.StartPosition = "Manual"
$cal.Size = New-Object Drawing.Size(256, 278); $cal.BackColor = [Drawing.SystemColors]::ControlDark
$cal.Padding = New-Object Windows.Forms.Padding(1)          # 1px grey border
$cal.Font = New-Object Drawing.Font("Segoe UI", 9)
$calBody = New-Object Windows.Forms.Panel; $calBody.Dock = "Fill"; $calBody.BackColor = [Drawing.SystemColors]::Window
$cal.Controls.Add($calBody)

# Header: < November 2026 >
$calHead = New-Object Windows.Forms.Panel; $calHead.Location = "0,0"; $calHead.Size = "254,38"; $calHead.BackColor = [Drawing.SystemColors]::Window
$calTitle = New-Object Windows.Forms.Label; $calTitle.Location = "40,0"; $calTitle.Size = "174,38"; $calTitle.TextAlign = "MiddleCenter"
$calTitle.ForeColor = $cText; $calTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$calPrev = New-Object Windows.Forms.Button; $calPrev.Text = "<"; $calPrev.Location = "4,4"; $calPrev.Size = "34,30"
$calNext = New-Object Windows.Forms.Button; $calNext.Text = ">"; $calNext.Location = "216,4"; $calNext.Size = "34,30"
foreach ($b in @($calPrev, $calNext)) {
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0; $b.ForeColor = $cText
    $b.FlatAppearance.MouseOverBackColor = $cHover
    $b.Font = New-Object Drawing.Font("Segoe UI", 10)
}
$calHead.Controls.AddRange(@($calPrev, $calTitle, $calNext))
$calBody.Controls.Add($calHead)

# Weekday names (Monday first)
$i = 0
foreach ($dn in @("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")) {
    $l = New-Object Windows.Forms.Label; $l.Text = $dn; $l.TextAlign = "MiddleCenter"
    $l.Location = New-Object Drawing.Point((8 + $i * 34), 42); $l.Size = "34,20"; $l.ForeColor = $cFaint
    $calBody.Controls.Add($l); $i++
}

# 6 x 7 day grid
$dayBtns = @()
for ($i = 0; $i -lt 42; $i++) {
    $b = New-Object Windows.Forms.Button
    $b.Location = New-Object Drawing.Point((8 + ($i % 7) * 34), (64 + [int][math]::Floor($i / 7) * 30))
    $b.Size = "34,30"; $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $cHover
    $b.Add_Click({ param($s, $e)
        $script:selDate = [datetime]$s.Tag
        Update-DateButton
        $cal.Hide()
    })
    $calBody.Controls.Add($b); $dayBtns += $b
}

# Footer: Today shortcut
$calToday = New-Object Windows.Forms.Button; $calToday.Text = "Today"; $calToday.Location = "8,246"; $calToday.Size = "238,26"
$calToday.FlatStyle = "Flat"; $calToday.FlatAppearance.BorderSize = 0; $calToday.ForeColor = $cText
$calToday.FlatAppearance.MouseOverBackColor = $cHover
$calToday.Add_Click({ $script:selDate = [datetime]::Today; Update-DateButton; $cal.Hide() })
$calBody.Controls.Add($calToday)

function Render-Calendar {
    $first  = $script:viewMonth
    $calTitle.Text = $first.ToString("MMMM yyyy")
    $offset = ([int]$first.DayOfWeek + 6) % 7          # Monday = 0
    $start  = $first.AddDays(-$offset)
    for ($i = 0; $i -lt 42; $i++) {
        $d = $start.AddDays($i); $b = $dayBtns[$i]
        $b.Text = $d.Day; $b.Tag = $d
        $b.Font = New-Object Drawing.Font("Segoe UI", 9)
        $b.BackColor = [Drawing.SystemColors]::Window
        $b.ForeColor = $(if ($d.Month -eq $first.Month) { $cText } else { $cFaint })
        if ($d.Date -eq [datetime]::Today) {
            $b.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)   # today = bold
        }
        if ($d.Date -eq $script:selDate.Date) {
            $b.BackColor = $cSelBg; $b.ForeColor = $cSelFg
            $b.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)
        }
    }
}

$calPrev.Add_Click({ $script:viewMonth = $script:viewMonth.AddMonths(-1); Render-Calendar })
$calNext.Add_Click({ $script:viewMonth = $script:viewMonth.AddMonths(1);  Render-Calendar })

# Close when clicking anywhere else; remember when, so the date button doesn't instantly reopen it
$script:calHiddenAt = [datetime]::MinValue
$cal.Add_Deactivate({ $cal.Hide(); $script:calHiddenAt = Get-Date })
$cal.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq "Escape") { $cal.Hide() } }); $cal.KeyPreview = $true

$btnDate.Add_Click({
    if (((Get-Date) - $script:calHiddenAt).TotalMilliseconds -lt 250) { return }   # it was just closed by this click
    $script:viewMonth = New-Object DateTime($script:selDate.Year, $script:selDate.Month, 1)
    Render-Calendar
    $cal.Location = $btnDate.PointToScreen((New-Object Drawing.Point(0, ($btnDate.Height + 2))))
    $cal.Show($form); $cal.Activate()
})

# ---------- buttons ----------
$btnPush   = Add-Ctl (New-Object Windows.Forms.Button) 15 248 130 32 "Push now"
$btnSave   = Add-Ctl (New-Object Windows.Forms.Button) 155 248 130 32 "Save schedule"
$btnRemove = Add-Ctl (New-Object Windows.Forms.Button) 295 248 150 32 "Remove selected"
$btnRefresh = Add-Ctl (New-Object Windows.Forms.Button) 455 248 135 32 "Refresh"

# ---------- scheduled tasks list ----------
Add-Ctl (New-Object Windows.Forms.Label) 15 290 200 20 "Scheduled pushes" | Out-Null
$list = Add-Ctl (New-Object Windows.Forms.ListView) 15 310 575 130
$list.View = "Details"; $list.FullRowSelect = $true; $list.MultiSelect = $false
[void]$list.Columns.Add("Task", 150)
[void]$list.Columns.Add("Repository", 230)
[void]$list.Columns.Add("Next run", 120)
[void]$list.Columns.Add("Last result", 70)

# ---------- log ----------
Add-Ctl (New-Object Windows.Forms.Label) 15 448 200 20 "Log (latest 40 lines)" | Out-Null
$txtLog = Add-Ctl (New-Object Windows.Forms.TextBox) 15 468 575 145
$txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)

# ---------- logic ----------
# Reads only GitPigeon's own Task Scheduler folders through the Task Scheduler
# service. (Get-ScheduledTask lists every task on the PC and fails with
# "The system cannot find the file specified" if any unrelated task is broken.)
function Get-PigeonTasks {
    $found = @()
    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    foreach ($path in @($taskPath, $oldTaskPath)) {
        try   { $folder = $svc.GetFolder($path.TrimEnd('\')) }
        catch { continue }                       # folder not created yet = no schedules
        foreach ($t in $folder.GetTasks(1)) {    # 1 = include hidden tasks
            $found += [pscustomobject]@{
                Name        = [string]$t.Name
                Path        = $path
                Description = [string]$t.Definition.RegistrationInfo.Description
                NextRun     = $t.NextRunTime
                LastRun     = $t.LastRunTime
                LastResult  = [int64]$t.LastTaskResult
                Enabled     = [bool]$t.Enabled
            }
        }
    }
    return $found
}

function Refresh-View {
    $list.Items.Clear()
    $problems = @()

    try {
        $tasks = @(Get-PigeonTasks)
    } catch {
        $tasks = @()
        $problems += "Could not read Task Scheduler: $($_.Exception.Message)"
    }

    foreach ($t in $tasks) {
        $next = "-"; $last = "-"
        try {
            if ($t.NextRun -and ([datetime]$t.NextRun).Year -ge 2000) { $next = ([datetime]$t.NextRun).ToString("yyyy.MM.dd HH:mm") }
            if     ($t.LastResult -eq 0x41301) { $last = "Running" }
            elseif ($t.LastResult -eq 0x41303 -or -not $t.LastRun -or ([datetime]$t.LastRun).Year -lt 2000) { $last = "-" }
            elseif ($t.LastResult -eq 0) { $last = "OK" }
            else   { $last = "Error" }
        } catch { $next = "?"; $last = "?" }
        if (-not $t.Enabled) { $next = "Disabled" }

        $label = $t.Name
        if ($t.Path -eq $oldTaskPath) { $label += "  (old - re-save)" }

        $item = New-Object Windows.Forms.ListViewItem
        $item.Text = $label
        $item.Tag  = @{ Name = $t.Name; Path = $t.Path }
        [void]$item.SubItems.Add($t.Description)
        [void]$item.SubItems.Add([string]$next)
        [void]$item.SubItems.Add([string]$last)
        [void]$list.Items.Add($item)
    }

    $lines = @()
    if (Test-Path $logFile) { $lines = @(Get-Content $logFile -Tail 40) }
    if ($tasks.Count -eq 0 -and $problems.Count -eq 0) { $lines += "(No schedules saved yet. Fill in the details and click Save schedule.)" }
    $lines += $problems
    $txtLog.Text = $lines -join "`r`n"
    $txtLog.SelectionStart = $txtLog.Text.Length; $txtLog.ScrollToCaret()
}

# Deletes one task from a GitPigeon folder (same reason: avoid Get-ScheduledTask)
function Remove-PigeonTask($name, $path) {
    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    $svc.GetFolder($path.TrimEnd('\')).DeleteTask($name, 0)
}

function Get-Repo {
    $repo = $txtRepo.Text.Trim()
    if (-not $repo -or -not (Test-Path (Join-Path $repo ".git"))) {
        [Windows.Forms.MessageBox]::Show("Pick a folder that contains a Git repository.", "Not a repository") | Out-Null
        return $null
    }
    # Remote/branch: letters, digits, . _ / - only, must not start with "-"
    $safe = '^[A-Za-z0-9._][A-Za-z0-9._/-]*$'
    if ($txtRemote.Text.Trim() -notmatch $safe) {
        [Windows.Forms.MessageBox]::Show("Remote name may only contain letters, numbers and . _ / -", "Invalid remote") | Out-Null
        return $null
    }
    if ($txtBranch.Text.Trim() -and $txtBranch.Text.Trim() -notmatch $safe) {
        [Windows.Forms.MessageBox]::Show("Branch name may only contain letters, numbers and . _ / -", "Invalid branch") | Out-Null
        return $null
    }
    return $repo
}

$btnBrowse.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the Git repository folder"
    if ($dlg.ShowDialog() -eq "OK") { $txtRepo.Text = $dlg.SelectedPath }
})

$btnPush.Add_Click({
    $repo = Get-Repo; if (-not $repo) { return }
    $form.Cursor = "WaitCursor"
    $p = @{ RepoPath = $repo; Remote = $txtRemote.Text.Trim() }
    if ($txtBranch.Text.Trim()) { $p.Branch = $txtBranch.Text.Trim() }
    if ($chkCommit.Checked)    { $p.CommitChanges = $true }
    & $pushScript @p | Out-Null
    $form.Cursor = "Default"
    Refresh-View
})

$btnSave.Add_Click({
    $repo = Get-Repo; if (-not $repo) { return }
    $arg = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$pushScript`" -RepoPath `"$repo`" -Remote `"$($txtRemote.Text.Trim())`""
    if ($txtBranch.Text.Trim()) { $arg += " -Branch `"$($txtBranch.Text.Trim())`"" }
    if ($chkCommit.Checked)    { $arg += " -CommitChanges" }

    # Start = chosen date + chosen time
    $start = $script:selDate.Date + $dtTime.Value.TimeOfDay

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    if ($rbOnce.Checked) {
        if ($start -le (Get-Date)) {
            [Windows.Forms.MessageBox]::Show("The start date and time is in the past. Pick a future date for a one-time push.", "Check the date") | Out-Null
            return
        }
        $trigger = New-ScheduledTaskTrigger -Once -At $start
    } elseif ($rbDaily.Checked) {
        $trigger = New-ScheduledTaskTrigger -Daily -At $start
    } else {
        $trigger = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval (New-TimeSpan -Hours ([int]$numHours.Value))
    }
    # Laptop-friendly settings:
    #  - run on battery and keep running if unplugged (Windows' default would skip it)
    #  - catch up after a missed run (PC off or asleep)
    #  - no network check here: after waking, Wi-Fi can take a few seconds, so
    #    gitpigeon-push.ps1 waits and retries instead
    #  - stop a stuck run after 30 minutes
    $sp = @{
        StartWhenAvailable         = $true
        AllowStartIfOnBatteries    = $true
        DontStopIfGoingOnBatteries = $true
        ExecutionTimeLimit         = (New-TimeSpan -Minutes 30)
    }
    if ($chkWake.Checked) { $sp.WakeToRun = $true }
    $settings = New-ScheduledTaskSettingsSet @sp

    $name = "Push - " + (Split-Path $repo -Leaf)
    try {
        Register-ScheduledTask -TaskName $name -TaskPath $taskPath -Action $action -Trigger $trigger `
            -Settings $settings -Description $repo -Force -ErrorAction Stop | Out-Null
        # Same repo saved with the old version? Remove that copy so it doesn't run twice
        try {
            Get-PigeonTasks | Where-Object { $_.Path -eq $oldTaskPath -and $_.Description -eq $repo } |
                ForEach-Object { Remove-PigeonTask $_.Name $_.Path }
        } catch { }
        [Windows.Forms.MessageBox]::Show("Schedule saved: $name", "Saved") | Out-Null
    } catch {
        [Windows.Forms.MessageBox]::Show("Could not create the task:`n$($_.Exception.Message)", "Error") | Out-Null
    }
    Refresh-View
})

$btnRemove.Add_Click({
    if ($list.SelectedItems.Count -eq 0) { return }
    $t = $list.SelectedItems[0].Tag
    if ([Windows.Forms.MessageBox]::Show("Remove '$($t.Name)'?", "Confirm", "YesNo") -eq "Yes") {
        try {
            Remove-PigeonTask $t.Name $t.Path
        } catch {
            [Windows.Forms.MessageBox]::Show("Could not remove the task:`n$($_.Exception.Message)", "Error") | Out-Null
        }
        Refresh-View
    }
})

# Selecting a task fills the repo box, so you can edit and re-save it
$list.Add_SelectedIndexChanged({
    if ($list.SelectedItems.Count) { $txtRepo.Text = $list.SelectedItems[0].SubItems[1].Text }
})

$btnRefresh.Add_Click({ Refresh-View })
$form.Add_Shown({ Refresh-View })
[void]$form.ShowDialog()
