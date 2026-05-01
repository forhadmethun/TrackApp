# TrackApp

A native macOS app-usage tracker. Floating, draggable, collapsible sidebar
that shows live time-spent per app with a premium frosted-glass look.

MVP v0.1 — first iteration.

## Requirements

- macOS 13 (Ventura) or newer
- Xcode 15+ command-line tools (Swift 5.9+)

## Build

```bash
./build.sh
```

This compiles the Swift package in release mode, assembles
`TrackApp.app` in the project root, and ad-hoc signs it.

## Install / Run

```bash
# Run in place
open ./TrackApp.app

# Or install to /Applications
mv ./TrackApp.app /Applications/
open /Applications/TrackApp.app
```

A small hourglass appears in the menu bar. The sidebar floats top-right
of your main display by default — drag it anywhere; position is remembered.

### Menu bar actions

- Show / Hide Sidebar (⌘S while menu open)
- Reset Today's Stats (⌘R)
- Quit TrackApp (⌘Q)

### First-launch Gatekeeper prompt

Because the app is ad-hoc signed (not Developer-ID notarized), macOS may
say "TrackApp is from an unidentified developer." Right-click the app →
Open → Open. After that, regular double-click works.

## Project layout

```
track-app/
├── Package.swift
├── Sources/TrackApp/
│   ├── TrackAppMain.swift      # @main + AppDelegate + status bar
│   ├── ActivityMonitor.swift   # NSWorkspace listener + idle detection
│   ├── UsageTracker.swift      # per-app time aggregation
│   ├── FloatingPanel.swift     # NSPanel host for the sidebar
│   └── SidebarView.swift       # SwiftUI premium UI
├── Resources/Info.plist        # LSUIElement = true (menu-bar-only)
└── build.sh                    # build + bundle + sign
```

## What's in this iteration

- Active-app detection via `NSWorkspace.didActivateApplicationNotification`
- 60-second idle threshold (no counting while AFK)
- Sleep/wake aware (pauses on sleep)
- Floating `NSPanel` — always on top, visible across all Spaces and full-screen apps
- Drag from anywhere in the sidebar to reposition
- Position persisted in `UserDefaults`
- Collapse/expand with spring animation
- Live progress rings around app icons (% of session)
- Frosted-glass background, layered shadows, hover micro-interactions
- Pulsing "Live" indicator
- Numeric text content transitions for smooth tickers

## Not in this iteration (planned)

- Persistence across launches (SwiftData — currently session-only)
- Daily/weekly history and charts
- App categories
- Goals and limits
- Launch-at-login
- App icon (currently uses default)
