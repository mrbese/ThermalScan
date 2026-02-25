# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview

Dezenit is a native iOS app (Swift/SwiftUI) for home energy assessment. It uses Apple-only frameworks (RoomPlan, ARKit, Vision, SwiftData, CoreLocation, AVFoundation, PDFKit) with zero external dependencies. There is no backend, no web frontend, and no package manager manifests (`Package.swift`, `Podfile`, etc.).

### Platform Constraint

This project **cannot be fully built or run on Linux**. It requires macOS with Xcode 15+ and the iOS 17.0+ Simulator (or a physical device with LiDAR). The Cloud Agent Linux VM can only perform partial checks.

### What Works on Linux

| Task | Command | Notes |
|---|---|---|
| **Swift syntax check** | `swiftc -parse <file.swift>` | Parses all 46 files without error. Does not type-check cross-file references. |
| **SwiftLint** | `swiftlint lint Dezenit/` | Runs with default rules (no `.swiftlint.yml` in repo). Expect ~270 warnings/errors from default config. Exit code 2 is normal (violations found). |
| **Swift REPL / scripts** | `swift <script.swift>` | Can run standalone Swift scripts that exercise Foundation-only logic. |

### What Does NOT Work on Linux

- `xcodebuild` / `swift build` for the full project — Apple frameworks are unavailable.
- Running the app — requires iOS Simulator on macOS.
- No automated test targets exist in the Xcode project.

### Key Architecture Notes

- 46 Swift source files across `Models/`, `Views/`, `Services/`, `Utils/`, `App/`.
- All views use SwiftUI; all models use SwiftData (`@Model`).
- Core business logic (BTU calculations, efficiency grading, recommendations) lives in `Services/` and uses only Foundation, making it testable with standalone Swift scripts on Linux.
- `Constants.swift` imports SwiftUI for `Color` types but also holds numerical calculation constants used throughout the codebase.

### Swift Toolchain

Swift 6.2.3 is installed at `/opt/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin/swift` and is on the PATH via `~/.bashrc`. SwiftLint 0.57.1 is at `/usr/local/bin/swiftlint`.
