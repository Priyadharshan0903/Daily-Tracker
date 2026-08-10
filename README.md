# Daybook

A tiny native macOS menu bar app for logging what you did each day — built from the
"Tray Tracker" Claude Design mock. Swift + SwiftUI, no dependencies, ~800 KB bundle.

## Features

- Lives in the menu bar (checkmark icon, no Dock icon) — click to open the popover
- **Today** — quick-add tasks (Enter or the Add pill), file them under a tag,
  check them off, delete on hover
- **This Week** — per-day log with prev/next week navigation, Highlights & Blockers
  notes, JSON export, and a printable weekly report (opens styled HTML in your browser)
- **Settings** — daily reminder notification, week start (Mon/Sun), launch at login,
  default tag
- All data stays local: `~/Library/Application Support/Daybook/daybook.json`

## Build & run

Requires only the Swift toolchain (Command Line Tools — no Xcode needed).

```bash
bash Scripts/build-app.sh   # builds dist/Daybook.app (release, ad-hoc signed)
open dist/Daybook.app
```

For development, `swift run Daybook` also works, but notifications and
launch-at-login need the real `.app` bundle.

To keep it around, copy `dist/Daybook.app` to `/Applications` and enable
"Launch at login" in Settings.

## Project layout

```
Sources/Daybook/
  DaybookApp.swift     # @main — MenuBarExtra (window style)
  Models.swift         # Entry / Settings / week view models + JSON export shape
  Store.swift          # observable state + debounced JSON persistence
  Theme.swift          # design tokens from the mock
  Views/               # RootView (tabs + quip footer), Today, Week, Settings, components
  ReportGenerator.swift# weekly report → self-contained HTML in the browser
  Reminders.swift      # daily notification via UserNotifications
  LaunchAtLogin.swift  # SMAppService
Scripts/build-app.sh   # SwiftPM build → assemble .app → ad-hoc codesign
Resources/Info.plist   # LSUIElement (menu-bar-only), bundle id com.priyadharshan.daybook
```
