# StatusTodo

A minimal macOS todo app with Monday.com-style status pills, category tabs, and weekly auto-clear.

![macOS](https://img.shields.io/badge/macOS-14%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Status pills** — Todo (grey), In Progress (orange), Waiting (blue), Done (green)
- **Category tabs** — Work, Life, Personal (fully customisable in Settings)
- **Drag to reorder** items and tabs
- **Done items sink to the bottom** and are greyed out automatically
- **Weekly auto-clear** — all Done items are removed every Sunday at 9 pm
- **Rolling backups** — 14 most recent backups saved to `~/Documents/StatusTodo Backups/`
- **Launch at login** toggle
- **Always on top** toggle — pin next to Outlook or any other app

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later

## Build & Run

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Clone and build
git clone https://github.com/Levijj22/StatusTodo.git
cd StatusTodo
xcodegen generate
open StatusTodo.xcodeproj
```

Then press `Cmd+R` in Xcode to run.

## Installing to /Applications

After building in Xcode, copy the built app:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/StatusTodo-*/Build/Products/Debug/StatusTodo.app /Applications/
```

## First launch on someone else's Mac

Because the app isn't signed with a paid Apple Developer certificate, macOS will warn it's from an unidentified developer. To open it:

1. Right-click the app → **Open**
2. Click **Open** in the dialog

After that it opens normally.

## Data & Backups

- Data is stored in `~/Library/Application Support/StatusTodo/data.json`
- Backups are saved to `~/Documents/StatusTodo Backups/` on every launch and before each auto-clear
- Use Settings → Backup → "Show in Finder" to browse backups
