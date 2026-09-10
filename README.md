# StatusTodo

A minimal macOS todo app with Monday.com-style status pills and category tabs, backed by Todoist.

![macOS](https://img.shields.io/badge/macOS-14%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

Todoist holds the data; StatusTodo is a native client onto it. That means the todos are reachable from the Todoist phone and web apps, and from automation, whether or not this Mac is running — while keeping the status-pill workflow Todoist itself doesn't offer.

## Features

- **Tick box** — not done (grey) or done (green); one click completes, another reopens
- **Category tabs** — one per Todoist project
- **Backed by Todoist** — add, rename, re-status and delete all sync to your account
- **Live** — refreshes every 60 seconds and whenever the window comes to the front, so changes made on your phone show up here
- **Optimistic edits** — changes apply instantly and push in the background; a failed push resyncs so the view can't drift from the server
- **Launch at login** toggle
- **Always on top** toggle — pin next to Outlook or any other app

## How status maps to Todoist

Done closes the task in Todoist; un-ticking reopens it. Priority is left
untouched and no longer encodes anything.

Completing something removes it from Todoist's open list before the completed
feed indexes it, so the app holds a just-completed task locally until a feed
agrees - otherwise it would flick back to not-done, or vanish for a cycle.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- A Todoist account and API token

## Setup

Create `StatusTodo/Services/Secrets.swift` with your API token from Todoist → Settings → Integrations → Developer:

```swift
enum Secrets {
    static let todoistToken = "your-token-here"
}
```

This file is gitignored — don't commit it. Regenerate it after rotating the token, then rebuild.

## Build & Run

```bash
brew install xcodegen
git clone https://github.com/Levijj22/StatusTodo.git
cd StatusTodo
xcodegen generate
open StatusTodo.xcodeproj
```

Then press `Cmd+R` in Xcode.

## Installing to /Applications

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/StatusTodo-*/Build/Products/Debug/StatusTodo.app /Applications/
```

## First launch on someone else's Mac

Because the app isn't signed with a paid Apple Developer certificate, macOS will warn it's from an unidentified developer. To open it:

1. Right-click the app → **Open**
2. Click **Open** in the dialog

After that it opens normally.

## Backups

Your data lives in your Todoist account, so local backups are no longer the safety net they were. Settings → Backup still writes a JSON snapshot to `~/Documents/StatusTodo Backups/` on demand.

Backups run only when you ask, and never on the main thread — that folder is often cloud-synced (OneDrive, iCloud Drive), and scanning it can block on network I/O.

## Known limitations

- Task ordering uses the Sync API (`item_reorder` / `child_order`); REST v1 neither returns nor accepts task order.
- **The weekly Sunday auto-clear is gone.** Completing an item removes it immediately, so there's nothing left to sweep up.
