# Daybook

A native macOS menu bar app for keeping track of what you did — and what you're going to do.

Swift + SwiftUI, no third-party dependencies, ~2.7 MB, builds without Xcode.

---

## About

**What did you actually do last week?** Most of us reconstruct it from Git history, Slack and a
calendar — not because the work didn't happen, but because nothing recorded it while it did.

Daybook is a work log first, planner second. It sits in the menu bar: jot a line when something
ships, and by Friday you have an honest record for your standup, your 1:1, or the review six
months from now.

- **Capture is nearly free.** A log you don't write is worthless, so the popover opens focused
  and Return files it.
- **Nothing is rewritten behind your back.** Unfinished work follows you forward but keeps the
  date it started, so the weekly report stays truthful.
- **It stays on your Mac.** No account, no sync, no telemetry — one JSON file you own.

Workspaces keep separate books: the day job in one, career growth or a side project in another.

---

## Features

**Today**
- Quick-add with Return or ⌘↩; tag as you type, or leave it untagged and file it later
- Tick off, edit in place, re-tag, delete
- **Carried over** — unfinished work from earlier days surfaces automatically, labelled with
  the day it started
- Completed tasks fold into a collapsible "N done" group so live work stays on top
- Filter the list by tag
- Reorder by dragging the grip, or with ⌘↑ / ⌘↓
- Move to any date with the arrows or a built-in calendar — including **future days**, so you
  can plan ahead

**This Week**
- Every day of the week on a timeline, with dots marking activity and today's position
- Tick tasks off while you review
- Highlights and Blockers notes, kept per week
- Export a week as JSON, or open a printable HTML report

**Settings**
- Daily reminder at a time you choose
- Week starts Monday or Sunday
- Text size, 85%–130%, applied across the whole app
- Launch at login
- Workspaces: create, rename, delete, and pick an emoji avatar
- Per-workspace tags, and which tag new tasks get
- Export / import all data

---

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Return` | Add the task you've typed |
| `⌘↩` | Add from anywhere in the popover |
| `↑` / `↓` | Move through tasks |
| `Space` | Tick the selected task |
| `⌘⌫` | Delete the selected task |
| `⌘↑` / `⌘↓` | Reorder the selected task |
| `Esc` | Clear the selection, or discard an edit in progress |

While editing a task: `Return` or `⌘↩` saves, `Esc` discards, and clicking away saves.

---

## Install

Requires macOS 13 or later and the Swift toolchain (Command Line Tools is enough — no Xcode).

```bash
bash Scripts/build-app.sh     # → dist/Daybook.app, release, ad-hoc signed
open dist/Daybook.app
```

To keep it: drag `dist/Daybook.app` to `/Applications` and turn on **Launch at login** in
Settings.

`swift run Daybook` works for development, but notifications and launch-at-login need the real
`.app` bundle.

The app icon is generated from the same drawing as the menu bar glyph. Regenerate after changing
it:

```bash
swift Scripts/make-icon.swift   # → Resources/Daybook.icns
```

> **Sharing it:** the build is ad-hoc signed, so on someone else's Mac Gatekeeper will refuse to
> open it. Distributing properly needs a Developer ID and notarisation.

---

## Your data

Everything lives in one file:

```
~/Library/Application Support/Daybook/daybook.json
```

Plain JSON, pretty-printed, written atomically a moment after each change. **Settings → Export…**
writes a copy anywhere you like; **Import…** replaces everything after a confirmation. Older
file formats are migrated on launch.

---

## Project layout

```
Sources/Daybook/
  DaybookApp.swift          @main — MenuBarExtra, pins the light appearance
  Models.swift              Entry, Workspace, AppSettings, migration, export shapes
  Store.swift               observable state, workspace scoping, persistence, date handling
  Theme.swift               design tokens and the text-scale helpers
  TrayIcon.swift            the sunrise mark, drawn in code for menu bar / header / icon
  ReportGenerator.swift     a week → self-contained HTML report
  Reminders.swift           daily notification (UserNotifications)
  LaunchAtLogin.swift       SMAppService
  Views/
    RootView.swift          header, tabs, footer, workspace switcher
    TodayView.swift         the day's list, filters, keyboard navigation
    WeekView.swift          week timeline, notes, export
    SettingsView.swift      grouped settings sections
    CalendarPanel.swift     custom month grid
    EntryRow.swift          one task: check, edit, tag, delete, drag
    WorkspaceSwitcher.swift avatars, switcher, avatar picker
    ReorderController.swift in-window drag reordering
    InlineTextField.swift   NSTextField wrapper for inline editing
    NotesTextView.swift     NSTextView wrapper for the week notes
    Components.swift        shared controls — chips, toggles, layout helpers
Scripts/
  build-app.sh              SwiftPM build → assemble .app → ad-hoc codesign
  make-icon.swift           renders Resources/Daybook.icns
Resources/
  Info.plist                LSUIElement (menu-bar-only), bundle id, icon
  Daybook.icns              generated app icon
```

Roughly 3,800 lines of Swift.

---

## Notes for anyone working on it

A few decisions that look odd until you know why:

- **The app pins itself to the light appearance.** The design tokens are a hardcoded light
  theme, and AppKit controls follow the system appearance — under Dark Mode they drew white text
  on our white surfaces, which is invisible. There is no dark theme yet; that's the honest
  reason.
- **Text fields are AppKit, not SwiftUI.** SwiftUI gives no hook at the moment a field takes
  focus, so removing AppKit's automatic select-all meant waiting a frame, which visibly flashed.
  Owning `NSTextField` lets focus and caret placement happen in one pass.
- **Drag reordering is hand-rolled.** `.draggable` / `.dropDestination` begin a *system* drag
  session, which makes the menu bar panel resign key — dismissing the popover and cancelling the
  drag. `ReorderController` tracks the drag inside the window instead.
- **No SwiftUI tap gesture spans the task list.** Inside a `ScrollView` a tap gesture wins the
  click over AppKit-backed text fields, which made the add-task field unfocusable.
- **`todayKey` is stored, not computed.** A computed value is correct whenever it's read, but
  reading it never tells SwiftUI to re-render, so the date went stale at midnight. It's now
  refreshed from calendar-day, timezone and wake notifications.
- **Font sizes go through `Theme.font(_:)`** so the text-size setting can scale all of them.

### Known gaps

- No tests.
- No undo — deleting a task or a workspace is immediate and permanent.
- One data file with no rolling backups; export is manual.
- No search, which will start to hurt after a few hundred entries.
- No dark mode.
