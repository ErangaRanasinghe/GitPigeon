<p align="center">
  <img src="assets/gitpigeon.png" alt="GitPigeon logo" width="120">
</p>

# GitPigeon

Delivers your Git commits on schedule.

GitPigeon is a small Windows tool that pushes your Git repositories automatically, daily, every few hours, or once on a chosen date. It works alongside TortoiseGit, because both use the same Git for Windows underneath.

Developed by EMR Industries · Version 1.1 · Built 2026.11.05

---

## Features

- **Push now** with one click, or **schedule pushes**: daily, every N hours, or once on a chosen date and time
- Optional **auto-commit** of all changes before pushing
- **Secret-file guard**: refuses to auto-commit files such as `.env`, `*.pem`, `*.key` or SSH keys
- Rebases onto the remote before pushing, and **never force-pushes**
- Never stops to ask for a password; failures are written to the log instead
- Clear log messages, including when Windows Defender blocks Git
- Schedules are stored in Windows Task Scheduler under a **GitPigeon** folder

## Requirements

- Windows 10 or 11
- [Git for Windows](https://git-scm.com/download/win) (installed with or alongside TortoiseGit)
- Windows PowerShell 5.1 (built into Windows)
- Each repository must be able to push **without a prompt**:
  - HTTPS remotes: push once by hand so Git Credential Manager saves your login
  - SSH remotes: use an OpenSSH key without a passphrase, or TortoiseGitPlink with Pageant running

## Install

1. Download `GitPigeon-v1.1.zip` from the **Releases** page.
2. Extract it to a folder only you can edit, for example:
   `%LOCALAPPDATA%\GitPigeon`
3. Double-click **`GitPigeon.exe`** (the pigeon icon).
4. The first time, Windows may show a security warning because the file came from the internet:
   - *Windows protected your PC* (SmartScreen): click **More info**, then **Run anyway**.
   - *Unknown Publisher*: click **Run**.

   GitPigeon then unblocks its own files, so the warning does not appear again.

To pin it, right-click `GitPigeon.exe` and choose **Pin to Start** or **Pin to taskbar**, or **Send to > Desktop (create shortcut)**.

`GitPigeon.exe` is only a launcher: it quietly runs `Start GitPigeon.bat`, which opens the GitPigeon window. Keep all files together in the same folder.

### Get GitPigeon without security warnings

Windows shows *Windows protected your PC* (SmartScreen) or *Unknown Publisher* only for files downloaded from the internet that are not signed. You can avoid these warnings completely:

**Option A: Unblock the zip before extracting**

1. Right-click `GitPigeon-v1.1.zip` and choose **Properties**.
2. Tick **Unblock** at the bottom of the **General** tab, then click **OK**.
3. Extract the zip and open `GitPigeon.exe`. No warning appears.

If you already extracted it, run this once in PowerShell inside the GitPigeon folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

**Option B: Get it from the Git repository (recommended for the team)**

Files that arrive through `git clone` or a pull (including TortoiseGit) are not marked as downloaded, and an exe you build on your own PC is never blocked.

1. Clone the GitPigeon repository with TortoiseGit (**Git Clone...**) or `git clone`.
2. In the repository folder, build the launcher once:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\build-launcher.ps1
   ```

3. Open `GitPigeon.exe`. To update later, pull the latest changes and run the build again.

Turning SmartScreen off is not recommended. It protects you from genuinely harmful downloads. The warnings will disappear for downloads too once GitPigeon is signed with a code-signing certificate.

## Using GitPigeon

### Scheduler tab

<p align="center">
  <img src="assets/screenshots/scheduler.png" alt="GitPigeon Scheduler tab" width="560">
</p>

| Field | What it does |
|---|---|
| Repository | Folder of the Git repository (**Browse...** to pick it) |
| Remote | Usually `origin` |
| Branch | Leave empty to use the current branch |
| Commit all changes before pushing | Stages and commits everything first (see *Safety*) |
| Start on / at | Date and time of the first run |
| Daily / Every N hours / Once only | How often to push |
| Wake the PC from sleep to push | Wakes a sleeping PC at the scheduled time (see *How schedules run*) |

Buttons:

- **Push now**: pushes immediately and shows the result in the log
- **Save schedule**: creates or updates the schedule for that repository (one schedule per repository)
- **Remove selected**: deletes the selected schedule
- **Refresh**: reloads the schedule list and log

The **Scheduled pushes** list shows each schedule's repository, next run and last result. Click a row to load it for editing.

### About tab

Shows the version, developer and build date, and where the log file and schedules are kept.

<p align="center">
  <img src="assets/screenshots/about.png" alt="GitPigeon About tab" width="560">
</p>

## How schedules run

GitPigeon does not need to be open. **Save schedule** creates a task in Windows Task Scheduler (folder **GitPigeon**), and Windows runs `gitpigeon-push.ps1` in the background at the scheduled time. Schedules survive closing GitPigeon, logging off and restarting.

| Situation | What happens |
|---|---|
| PC was **off** at the scheduled time | The missed push runs a few minutes after you turn the PC on and log in. Several missed runs are caught up with one push. |
| PC was **asleep** | With *Wake the PC from sleep to push* ticked, Windows wakes it and pushes. Otherwise the missed push runs after the PC wakes. |
| Laptop on **battery** | Pushes run on battery and are not stopped if you unplug. |
| **No network** yet (for example, just after waking) | GitPigeon waits and retries for about a minute before logging an error. The next scheduled run tries again. |
| You are **logged off** | Schedules run only while you are logged in, because they use your saved Git login. |

**Wake from sleep on laptops:** Windows must allow wake timers. Open **Control Panel > Power Options > Change plan settings > Change advanced power settings > Sleep > Allow wake timers** and set it to **Enable** (for both *On battery* and *Plugged in* if you want both). Some laptops also disable wake timers in their own power software.

Schedules saved with version 1.0 do not have the battery and wake settings. Select each one in the list and click **Save schedule** again to update it.

## Log

Every run is written to `%USERPROFILE%\gitpigeon.log`. The last 40 lines are shown in the tool.

Typical messages:

| Message | Meaning |
|---|---|
| `Pushed N commit(s) to origin/main` | Success |
| `Nothing to push on main` | Already up to date |
| `BLOCKED: auto-commit refused, possible secret files: ...` | A file like `.env` would have been committed. Add it to `.gitignore` or commit manually. |
| `pull --rebase failed: hit a conflict` | Resolve the conflict in TortoiseGit, then push |
| `Blocked by Windows Defender Controlled folder access` | See *Troubleshooting* |

## Safety

- Runs as your own user, with no administrator rights, and only while you are logged in.
- Stores no passwords. Logins come from Git Credential Manager or your SSH key.
- Never force-pushes. Rebase conflicts are aborted and left for you to resolve.
- Masks credentials in URLs (`https://user:token@...`) in the log. Avoid putting tokens in remote URLs anyway.
- Validates remote and branch names before use.
- Keep the GitPigeon folder somewhere only you can edit. Scheduled tasks run `gitpigeon-push.ps1` as you, so anyone who can change that file can run code as you.

## Troubleshooting

**`cannot open '.git/FETCH_HEAD'` / "Blocked by Windows Defender Controlled folder access"**
Windows Defender's ransomware protection stopped Git from writing inside a protected folder such as Documents or Desktop. Either:

- allow `git.exe` (usually `C:\Program Files\Git\mingw64\bin\git.exe`) in **Windows Security > Virus & threat protection > Ransomware protection > Allow an app through Controlled folder access**, or
- keep repositories outside protected folders, for example `C:\Dev\`.

Allow `git.exe` only, not `powershell.exe`.

**Push fails with an authentication error**
Push once by hand (TortoiseGit or `git push`) so your credentials are saved, then try again. For SSH with Pageant, make sure Pageant is running with your key loaded.

**A schedule did not run**
Check the cases in *How schedules run* first. Then open Task Scheduler (`taskschd.msc`), go to the **GitPigeon** folder and check the task's *Last Run Result* and *History*.

## Uninstall

1. In GitPigeon, remove each schedule (or delete the **GitPigeon** folder in Task Scheduler).
2. Delete the GitPigeon folder.
3. Optionally delete `%USERPROFILE%\gitpigeon.log`.

## Files

```
GitPigeon/
├── GitPigeon.exe            Open this (launcher with the GitPigeon icon)
├── Start GitPigeon.bat      Started by GitPigeon.exe; opens the window
├── GitPigeon.ps1            The GitPigeon window (Scheduler and About tabs)
├── gitpigeon-push.ps1       Commits and pushes one repository (Push now and schedules)
├── assets/                  gitpigeon.ico, gitpigeon.png, gitpigeon.svg, screenshots/
├── launcher/                Source code of GitPigeon.exe
├── tools/                   build-launcher.ps1, make-release.ps1
├── README.md
└── CHANGELOG.md
```

`GitPigeon.exe` is built from `launcher/GitPigeonLauncher.cs` and is not stored in the repository. It is included in each release zip. To build it from source, run `tools\build-launcher.ps1`; it uses the C# compiler built into Windows, so nothing needs installing.

## Making a release

1. Update `$AppVersion` and `$AppBuildDate` in `GitPigeon.ps1`, and the headers in the other files.
2. Add the new version to `CHANGELOG.md`.
3. Run `powershell -ExecutionPolicy Bypass -File tools\make-release.ps1`. It rebuilds `GitPigeon.exe` with the new version, then creates the zip.
4. Commit, tag (for example `v1.1`), push, and attach `dist\GitPigeon-v1.1.zip` to a new release.

---

© 2026 EMR Industries
