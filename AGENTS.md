# AGENTS.md

## Project Overview

ManorOS is a native iOS (Swift/SwiftUI) home energy auditing app. It uses LiDAR (RoomPlan), on-device OCR (Vision), and SwiftData for local persistence. Zero external dependencies — Apple frameworks only. No backend, no network calls.

See `README.md` for full architecture, BTU methodology, and equipment benchmarks.

## Cursor Cloud specific instructions

### Platform constraint

This is a **pure iOS/Xcode project**. It cannot be fully built or run on Linux — it requires macOS with Xcode 15+ and the iOS 17 SDK. On a Linux Cloud Agent VM, the available development tools are:

- **Swift toolchain** (`/opt/swift/usr/bin/swift`, `/opt/swift/usr/bin/swiftc`) — for syntax checking and compiling Foundation-only logic.
- **SwiftLint** (`/usr/local/bin/swiftlint`) — for linting all 60 Swift source files.

### Linting

```bash
swiftlint lint --reporter xcode
```

Runs against all `.swift` files in the repo root. The codebase currently has ~355 existing violations (50 serious), mostly identifier naming, line length, and complexity rules. No `.swiftlint.yml` config exists.

### Syntax / type checking (Foundation-only files)

Several source files depend only on `Foundation` and can be type-checked on Linux:

```bash
swiftc -typecheck \
  ManorOS/Utils/Constants.swift \
  ManorOS/Models/ClimateZone.swift \
  ManorOS/Models/InsulationQuality.swift \
  ManorOS/Models/WindowInfo.swift \
  ManorOS/Models/AgeRange.swift \
  ManorOS/Models/EquipmentType.swift
```

Files using `SwiftData`, `SwiftUI`, `RoomPlan`, `ARKit`, `Vision`, or other Apple-only frameworks will fail type-checking on Linux. Use `-parse` (syntax-only) for those:

```bash
swiftc -parse ManorOS/SomeFile.swift
```

### Running core logic

The `demo_energy_calc.swift` script at the repo root exercises the `EnergyCalculator` BTU calculation engine (the app's core computation) without iOS dependencies:

```bash
swift demo_energy_calc.swift
```

### What you cannot do on Linux

- Build the full Xcode project (`xcodebuild` is macOS-only)
- Run the iOS simulator
- Test SwiftUI views, RoomPlan scanning, camera/OCR, or SwiftData persistence
- Run any UI tests or integration tests (none exist in the repo currently)

### Project structure notes

- No `Package.swift`, no CocoaPods, no SPM — everything is managed via `ManorOS.xcodeproj`
- No test targets exist in the Xcode project
- No CI/CD configuration files
- No `.swiftlint.yml` — SwiftLint uses its default rules
