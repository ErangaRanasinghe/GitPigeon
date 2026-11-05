# Changelog

All notable changes to GitPigeon are listed here.

## [1.1] - 2026-11-05

Laptop-friendly schedules.

### Added
- **Wake the PC from sleep to push** option for schedules
- Network retry: waits up to about a minute for the network (for example, right after waking) before reporting a fetch error

### Changed
- Schedules now run on battery and keep running if the laptop is unplugged (Windows' default skipped them)
- Missed runs still catch up after the PC is turned on; the task no longer requires the network to be up at the exact start time
- A stuck run is stopped after 30 minutes
- Schedules saved with 1.0 need **Save schedule** clicked again to pick up these settings

## [1.0] - 2026-11-05

First release.

### Added
- GitPigeon window with **Scheduler** and **About** tabs
- Push now, and scheduled pushes: daily, every N hours, or once on a chosen date
- Start date picker with a calendar pop-up in the standard Windows style
- Optional auto-commit of all changes before pushing
- Schedules stored in Windows Task Scheduler under a `GitPigeon` folder, with next run and last result shown in the tool
- Log file `%USERPROFILE%\gitpigeon.log`, with the latest lines shown in the tool
- `GitPigeon.exe` launcher with the GitPigeon icon and version details; it quietly runs `Start GitPigeon.bat`
- GitPigeon icon (pigeon with a gear wheel) for the launcher, window, taskbar and About tab
- Images kept in an `assets` folder
- Release tools: `build-launcher.ps1` and `make-release.ps1`
- Automatic unblocking of GitPigeon's own files after the first run, so the security prompt appears only once

### Security
- Secret-file guard: auto-commit is refused for `.env`, keys, certificates and similar files
- Remote and branch names are validated and quoted
- Credentials in URLs are masked in the log
- Git never waits for a password prompt or login window
- No force-push; rebase conflicts are aborted and left for manual resolution
- Clear log message when Windows Defender Controlled folder access blocks Git
