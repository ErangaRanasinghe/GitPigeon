<#
  gitpigeon-push.ps1

  Developed by : EMR Industries
  Version      : 1.1.2
  Built date   : 2026.11.06

  GitPigeon - commits (optional) and pushes a Git repo on a schedule. Works alongside TortoiseGit,
  since TortoiseGit uses the same Git for Windows underneath.

  Usage examples:
    powershell -ExecutionPolicy Bypass -File gitpigeon-push.ps1 -RepoPath "D:\Projects\govi-fw"
    powershell -ExecutionPolicy Bypass -File gitpigeon-push.ps1 -RepoPath "D:\Projects\govi-fw" -CommitChanges

  Safety:
    - Remote and branch names are validated before use.
    - Auto-commit is refused if a likely secret file (.env, keys, certificates...) would be committed.
    - URLs with embedded credentials are masked in the log.
    - Git is never allowed to prompt for a password or open a login window.
    - Never force-pushes.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoPath,

    [string]$Remote = "origin",

    [string]$Branch = "",              # empty = current branch

    [switch]$CommitChanges,            # stage + commit everything before pushing

    [string]$LogFile = "$env:USERPROFILE\gitpigeon.log"
)

# Files that must never be auto-committed (matched against the file name)
$SecretPatterns = @(
    ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "*.ppk", "*.kdbx",
    "id_rsa*", "id_ed25519*", "id_ecdsa*", "*secret*", "*credential*", "*password*"
)

# Remote/branch names: letters, digits, . _ / - only, and must not start with "-"
$SafeName = '^[A-Za-z0-9._][A-Za-z0-9._/-]*$'

function Hide-Secrets([string]$text) {
    # https://user:token@host -> https://***@host
    return ($text -replace '://[^@/\s]+@', '://***@')
}

function Log($msg) {
    $msg  = Hide-Secrets (($msg -replace '\s+', ' ').Trim())
    $line = "{0}  [{1}]  {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), (Split-Path $RepoPath -Leaf), $msg
    Add-Content -Path $LogFile -Value $line
    Write-Output $line
}

# Turns raw git errors into a clearer reason when Windows blocked a file write
function Explain-GitError([string]$text) {
    $blocked = @(
        "cannot open '.git/", "unable to create", "unable to write", "could not lock",
        "Permission denied", "Operation not permitted", "Access is denied", "insufficient permission"
    )
    foreach ($p in $blocked) {
        if ($text -like "*$p*") {
            return "Blocked by Windows Defender Controlled folder access (git could not write inside the repo). " +
                   "Allow git.exe in Windows Security > Ransomware protection > Allow an app, or move the repo " +
                   "outside Documents/Desktop. Details: $text"
        }
    }
    return $text
}

# ---------- Never let Git wait for input in an unattended run ----------
$env:GIT_TERMINAL_PROMPT = "0"      # no username/password prompt in the console
$env:GCM_INTERACTIVE     = "Never"  # Git Credential Manager: no login pop-up window

# ---------- Validate input ----------
if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    Log "ERROR: $RepoPath is not a Git repository"
    exit 1
}
if ($Remote -notmatch $SafeName) {
    Log "ERROR: invalid remote name '$Remote'"
    exit 1
}
if ($Branch -and $Branch -notmatch $SafeName) {
    Log "ERROR: invalid branch name '$Branch'"
    exit 1
}

Set-Location $RepoPath

# SSH: fail instead of asking for a passphrase, unless an SSH client is already configured
# (e.g. TortoiseGitPlink via GIT_SSH or core.sshCommand - leave that alone)
if (-not $env:GIT_SSH -and -not $env:GIT_SSH_COMMAND -and -not (git config --get core.sshCommand)) {
    $env:GIT_SSH_COMMAND = "ssh -o BatchMode=yes"
}

if (-not $Branch) {
    $Branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($Branch -eq "HEAD") { Log "ERROR: repo is in detached HEAD state, nothing pushed"; exit 1 }
}

$remotes = git remote
if ($remotes -notcontains $Remote) {
    Log "ERROR: remote '$Remote' does not exist in this repo"
    exit 1
}

# ---------- 1. Optionally commit local changes ----------
if ($CommitChanges) {
    $status = git status --porcelain --untracked-files=all
    if ($status) {
        # Secret-file guard
        $risky = foreach ($row in $status) {
            $path = $row.Substring(3)
            if ($path -like "* -> *") { $path = ($path -split ' -> ')[-1] }   # renames
            $path = $path.Trim('"')
            $name = Split-Path $path -Leaf
            foreach ($pat in $SecretPatterns) {
                if ($name -like $pat) { $path; break }
            }
        }
        if ($risky) {
            Log ("BLOCKED: auto-commit refused, possible secret files: " + (($risky | Select-Object -Unique) -join ", ") +
                 ". Add them to .gitignore or commit manually in TortoiseGit.")
            exit 1
        }

        $addOut = git add -A 2>&1
        if ($LASTEXITCODE -ne 0) { Log ("ERROR: staging failed: " + (Explain-GitError "$addOut")); exit 1 }
        $msg = "GitPigeon auto-commit " + (Get-Date -Format "yyyy-MM-dd HH:mm")
        $commitOut = git commit -m $msg 2>&1
        if ($LASTEXITCODE -ne 0) { Log ("ERROR: commit failed: " + (Explain-GitError "$commitOut")); exit 1 }
        Log "Committed changes: $msg"
    }
}

# ---------- 2. Anything to push? ----------
# Retry the fetch: right after a laptop wakes or starts, the network may not be up yet
for ($try = 1; $try -le 4; $try++) {
    $fetchOut = git fetch $Remote $Branch 2>&1
    if ($LASTEXITCODE -eq 0) { break }
    if ($try -lt 4) { Start-Sleep -Seconds 20 }
}
if ($LASTEXITCODE -ne 0) {
    $why = Explain-GitError "$fetchOut"
    if ($why -eq "$fetchOut") { $why = "check network / credentials: $fetchOut" }
    Log "ERROR: fetch failed: $why"
    exit 1
}
$ahead = (git rev-list --count "$Remote/$Branch..HEAD" 2>$null)
if (-not $ahead -or [int]$ahead -eq 0) {
    Log "Nothing to push on $Branch"
    exit 0
}

# ---------- 3. Rebase onto the remote first so the push isn't rejected ----------
$pullOut = git pull --rebase $Remote $Branch 2>&1
if ($LASTEXITCODE -ne 0) {
    git rebase --abort 2>$null
    $why = Explain-GitError "$pullOut"
    if ($why -eq "$pullOut") { $why = "hit a conflict. Resolve manually in TortoiseGit." }
    Log "ERROR: pull --rebase failed: $why"
    exit 1
}

# ---------- 4. Push (never forced) ----------
$out = git push $Remote $Branch 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "Pushed $ahead commit(s) to $Remote/$Branch"
    exit 0
} else {
    Log ("ERROR: push failed: " + (Explain-GitError "$out"))
    exit 1
}
