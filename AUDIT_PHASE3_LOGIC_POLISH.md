# Dezenit Pre-Launch Audit — Phase 3: State, Logic & Polish

**Date:** 2026-02-22
**Audited from:** Every Swift file, line-by-line code review

---

## Table of Contents

- [A. State Management Audit](#a-state-management-audit)
- [B. Data & API Audit](#b-data--api-audit)
- [C. UI Polish Audit](#c-ui-polish-audit)
- [D. Permissions & Device Features](#d-permissions--device-features)
- [E. Master Issue Registry (Phase 3)](#e-master-issue-registry-phase-3)

---

## A. State Management Audit

### A1. Complete Persisted State Inventory

#### @AppStorage (UserDefaults)

| Key | Type | Default | Read by | Written by |
|-----|------|---------|---------|------------|
| `"hasSeenOnboarding"` | `Bool` | `false` | `DezenitApp.swift:6`, `OnboardingView.swift` | `OnboardingView.swift:35` |

Single key, clean lifecycle. No stale-key risk.

#### SwiftData @Model CRUD Map

| Model | Create | Read | Update | Delete |
|-------|--------|------|--------|--------|
| **Home** | `HomeListView` (AddHomeSheet callback) | `@Query` in HomeListView; passed to all child views | `home.updatedAt` on room/equipment/appliance save; `home.envelope` on envelope save | HomeListView swipe-delete (with confirmation) |
| **Room** | `DetailsView.saveAndCalculate()` | `home.rooms` in HomeDashboardView, AuditFlowView | **Never** (no edit flow) | HomeDashboardView swipe-delete |
| **Equipment** | `EquipmentDetailsView.saveEquipment()` | `home.equipment` in HomeDashboardView, AuditFlowView, HomeReportView | **Never** (no edit flow) | HomeDashboardView swipe-delete |
| **Appliance** | `ApplianceDetailsView.saveAppliance()` | `home.appliances` in HomeDashboardView, AuditFlowView, HomeReportView | **Never** (no edit flow) | HomeDashboardView swipe-delete |
| **EnergyBill** | `BillDetailsView.saveBill()` | `home.energyBills` in HomeDashboardView, HomeReportView | **Never** (no edit flow) | HomeDashboardView swipe-delete |
| **AuditProgress** | `AuditFlowView.setupAudit()` | `home.currentAudit` in HomeDashboardView, AuditFlowView | `markComplete()`, `currentStep` writes | **Never** (cascade-deleted with Home) |

#### JSON-Encoded Data Properties

| Property | Model | Stored as | Encode path | Decode path | Status |
|----------|-------|-----------|-------------|-------------|--------|
| `windowsData` | Room | `[WindowInfo]` → Data? | `Room.init()`, `Room.windows` setter | `Room.windows` getter | CORRECT |
| `envelopeData` | Home | `EnvelopeInfo` → Data? | `Home.envelope` setter | `Home.envelope` getter | CORRECT |
| `completedStepsData` | AuditProgress | `[String]` → Data? | `AuditProgress.init()`, `completedSteps` setter | `completedSteps` getter | CORRECT |

All three use `try? JSONEncoder/JSONDecoder`. Encode failures silently set to nil (data loss risk — extremely low but present). Decode failures return `[]` or `nil`. All Codable types are simple enums/structs.

---

### A2. State Correctness After Key Actions

#### After saving a Room ✅
- `room.home = home` — relationship set (DetailsView:212)
- `home.updatedAt = Date()` — timestamp updated (DetailsView:213)
- `modelContext.insert(room)` — persisted (DetailsView:215)
- Room appears on dashboard via live `home.rooms` relationship

**Issue:** `home` parameter is optional (`var home: Home? = nil`). If nil, room is inserted as orphan (line 211: `if let home { ... }` guards the relationship). Cannot happen in current flows but is fragile.

#### After saving Equipment ✅
- `eq.home = home` — set (EquipmentDetailsView:206)
- `home.updatedAt = Date()` — updated (EquipmentDetailsView:208)
- `modelContext.insert(eq)` — persisted

#### After saving an Appliance ✅
- `appliance.home = home` — set (ApplianceDetailsView:232)
- `appliance.room = selectedRoom` — optional room link set (ApplianceDetailsView:233)
- `home.updatedAt = Date()` — updated (ApplianceDetailsView:235)

#### After saving a Bill ❌
- `bill.home = home` — set (BillDetailsView:137)
- **`home.updatedAt` is NOT updated** — BillDetailsView.saveBill() omits this
- Home position in sorted HomeListView does not change

#### After completing an audit step ⚠️
- `audit.markComplete(currentStep)` called — step added to completedSteps, JSON re-encoded
- **Competing writes:** `markComplete()` advances `currentStep` to next incomplete step, then `moveToNextStep()` overwrites it to sequential next step. The sequential write wins.
- **`home.updatedAt` is NOT updated** on audit step completion

#### After deleting any entity ❌
- `modelContext.delete()` removes from SwiftData
- **`home.updatedAt` is NOT updated on ANY delete** (rooms, equipment, appliances, bills)

---

### A3. State Staleness and Conflicts

#### Stale prefill data never cleared

| Variable | View | Issue |
|----------|------|-------|
| `showingApplianceDetailsPrefill: (ApplianceCategory, UIImage)?` | HomeDashboardView:132 | Holds UIImage indefinitely after sheet dismissal |
| `showingLightingDetailsPrefill: (BulbOCRResult, UIImage)?` | HomeDashboardView:134 | Same |
| `showingBillDetailsPrefill: (ParsedBillResult, UIImage)?` | HomeDashboardView:17 | Same |
| `appliancePrefill`, `lightingPrefill`, `billPrefill` | AuditFlowView:21-25 | Same |

These optional tuples hold `UIImage` data in memory for the lifetime of the parent view. Never set to `nil` after use.

#### Dual source of truth for currentStep

`AuditFlowView` maintains:
1. `@State private var currentStep: AuditStep` — view-local
2. `audit?.currentStep` — persisted SwiftData string

Synced in `setupAudit()` on first appear. But `markComplete()` writes only to the persisted value while `moveToNextStep()` writes to both. If `markComplete` computes a different "next step" than `moveToNextStep`, the persisted value is immediately overwritten by `moveToNextStep`. The `@State` version always wins for display.

#### home.updatedAt inconsistency

Updated on: Room save, Equipment save, Appliance save, Envelope save
**NOT updated on:** Bill save, any entity deletion, audit step completion

---

### A4. Force-Close Resume Behavior

#### SwiftData auto-save timing
Default `.modelContainer` uses autosave: triggers on navigation events, app backgrounding, periodic idle, and context deallocation. Does NOT save synchronously after every mutation.

#### Screen-by-screen analysis

| Screen | State at risk | Persisted? | Recovery |
|--------|--------------|------------|----------|
| OnboardingView | `currentPage` position | NO | Restarts at page 0. Clean. |
| AddHomeSheet | All form fields | NO | Data lost. Home not yet created. Clean loss. |
| HomeDashboardView | No mutable state | N/A | Full recovery from SwiftData |
| DetailsView (room entry) | Form fields, windows | NO until "Calculate" | Room data lost if force-closed before save |
| ScanView (LiDAR) | Scan in progress | NO | Must rescan |
| EquipmentDetailsView | Form + OCR + photo | NO until "Save" | All lost |
| ApplianceDetailsView | Form fields | NO until "Save" | All lost |
| BillDetailsView | Form fields | NO until "Save" | All lost |
| AuditFlowView | Step position | PARTIALLY | `currentStep` persisted on each step change but subject to auto-save timing |
| EnvelopeAssessmentView | 3-step form data | NO until "Save" | All lost |
| WindowQuestionnaireView | Window changes | Via @Binding only | Only persisted when parent room is saved |

**App always resumes to HomeListView.** No navigation state persistence. No deep-link resume.

#### Critical risk window
After `modelContext.insert()` but before auto-save: a force-close could lose the inserted entity. Window is typically milliseconds to seconds.

---

### A5. SwiftData Schema and Migration

#### All @Model properties have defaults ✅
Every non-optional property is assigned in its initializer. Every optional defaults to `nil`. SwiftData lightweight migration can handle adding any of these properties.

#### No VersionedSchema defined ⚠️
The app relies entirely on automatic lightweight migration. Safe for current schema, but:
- Property **renames** will be treated as remove+add (data loss)
- Non-optional property **additions without defaults** in future versions will crash
- **Recommendation:** Define VersionedSchema before v2

#### @Relationship inverse specifications

| Parent | Child | Inverse specified? | Inference safe? |
|--------|-------|--------------------|-----------------|
| `Home.rooms → Room.home` | ✅ types unique | No explicit inverse | YES |
| `Home.equipment → Equipment.home` | ✅ types unique | No explicit inverse | YES |
| `Home.appliances → Appliance.home` | ⚠️ Appliance has TWO parents | No explicit inverse | **AMBIGUOUS** |
| `Home.energyBills → EnergyBill.home` | ✅ types unique | No explicit inverse | YES |
| `Home.auditProgress → AuditProgress.home` | ✅ types unique | No explicit inverse | YES |
| `Room.appliances → Appliance.room` | ⚠️ Appliance has TWO parents | No explicit inverse | **AMBIGUOUS** |

**Issue:** `Appliance` has both `home: Home?` and `room: Room?`. Both `Home` and `Room` declare `var appliances: [Appliance]` with cascade delete and no explicit `inverse:` parameter. SwiftData must infer which array maps to which parent. Should add explicit `inverse: \Appliance.home` and `inverse: \Appliance.room`.

#### Cascade delete — double-cascade bug

| Delete action | Cascade effect | Problem? |
|---|---|---|
| Delete Home | Deletes all rooms, equipment, appliances, bills, audit progress | Correct ✅ |
| Delete Room | Cascade-deletes Room's appliances | **YES** — appliances that also belong to Home are permanently destroyed |

**Room.appliances uses `.cascade` delete rule.** Deleting a room permanently deletes all appliances assigned to it, even though those appliances also exist in `Home.appliances`. The user likely expects appliances to become "unassigned" (room = nil) rather than deleted.

**Fix:** Change `Room.appliances` to `@Relationship(deleteRule: .nullify)` so deleting a room sets `appliance.room = nil` instead of deleting the appliance.

---

## B. Data & API Audit

### B1. Network / API Calls

**The app makes ZERO network requests.** Entirely offline. No API calls, no REST endpoints, no GraphQL, no WebSocket. Internet status is irrelevant.

### B2. Hardcoded Data Audit

| Database | File | Size | Quality |
|----------|------|------|---------|
| **Efficiency specs** | `EfficiencyDatabase.swift` | 11 equipment types × 5 age ranges | Industry-standard values ✅ |
| **Upgrade recommendations** | `UpgradeEngine.swift` | 11 types × 3 tiers (Good/Better/Best) | Realistic costs, savings, brands ✅ |
| **State rebates** | `RebateDatabase.swift` | 15 states, 53 rebate entries | Real programs and URLs ⚠️ |
| **Energy constants** | `Constants.swift` | ~30 values | Standard industry values ✅ |
| **Known brands (OCR)** | `OCRService.swift` | 38 manufacturers | Comprehensive ✅ |
| **Known utilities (OCR)** | `BillParsingService.swift` | 35 utility names | Major US utilities ✅ |
| **Appliance categories** | `Appliance.swift` | 25 categories with defaults | Reasonable ✅ |
| **Vision ID mappings** | `ApplianceClassificationService.swift` | ~30 identifier-to-category mappings | Reasonable ✅ |

**Issues with hardcoded data:**

| Issue | Detail | Severity |
|---|---|---|
| Rebate expiration | All 53 rebates have `expirationNote: nil`. Programs change annually. | MEDIUM |
| Rebate URLs | All point to real websites but URLs go stale. No verification date. | MEDIUM |
| 35 states missing | Users in CO, OR, MD, CT, MN, etc. silently get no rebates | MEDIUM |
| Tax credit dates | References IRS 25C/25D without noting 2032 expiration (under IRA) | LOW |
| `lampFixture` default | 60W (incandescent assumption). Most modern fixtures use LED. | LOW |
| Default electricity rate | $0.16/kWh — correct US national average but varies widely by state ($0.10-$0.40) | LOW |

### B3. Console/Debug Output

**ZERO instances** of `print(`, `debugPrint(`, `NSLog(`, `os_log(`, `Logger(`, `dump(` in the entire codebase. Production-clean.

### B4. Dev-Only Code

**ZERO instances** of `#if DEBUG`, `#if PREVIEW`, `PreviewProvider`, `#Preview`, `@available`. No conditional compilation, no feature flags, no test-only paths.

**Notable:** No SwiftUI previews anywhere — cannot use Xcode Canvas for development, but no preview code to strip for production.

### B5. Duplicate Code

**4 nearly-identical camera service classes:**
1. `CameraService` in EquipmentCameraView.swift
2. `ApplianceCameraService` in ApplianceScanView.swift
3. `BulbCameraService` in LightingCloseupView.swift
4. `BillCameraService` in BillUploadView.swift

All follow the same AVCaptureSession + AVCapturePhotoOutput pattern with `start()`, `stop()`, `capturePhoto()`. Should be consolidated into a shared reusable service.

---

## C. UI Polish Audit

### C1. Loading States

| Screen | Async Operation | Loading UI | Verdict |
|--------|----------------|------------|---------|
| ScanView | LiDAR processing | `ProgressView()` + "Processing scan..." | ✅ GOOD |
| EquipmentDetailsView | OCR processing | `ProgressView()` + "Reading label..." | ✅ GOOD |
| ApplianceScanView | Classification | `ProgressView("Identifying...")` | ✅ GOOD |
| LightingCloseupView | OCR processing | `ProgressView("Reading label...")` | ✅ GOOD |
| BillUploadView | Bill parsing | `ProgressView("Parsing bill...")` | ✅ GOOD |
| AddHomeSheet | Location detection | **NOTHING** | ❌ Silent GPS |
| DetailsView | Location detection | **NOTHING** | ❌ Silent GPS |
| HomeReportView | State detection for rebates | **NOTHING** | ❌ Rebates pop in late |

3 silent async operations with no loading feedback.

### C2. Empty States

| Screen / Section | Empty content | Quality |
|---|---|---|
| HomeListView | Icon + "Dezenit" + subtitle + [Add Your Home] CTA | EXCELLENT |
| Dashboard — Rooms | "No rooms scanned yet..." + add button | GOOD |
| Dashboard — Equipment | "No equipment logged yet..." + add button | GOOD |
| Dashboard — Appliances | "No appliances tracked yet..." + add button | GOOD |
| Dashboard — Bills | "No bills uploaded yet..." + add button | GOOD |
| Dashboard — Grade | "--" with "No Data" label | GOOD |
| Dashboard — Report | **Hidden entirely** when 0 rooms AND 0 equipment | ⚠️ Could show disabled state |
| Audit Step 7 | "Add rooms first (Step 2)..." | GOOD |
| HomeReportView rebates | "No matching rebates found..." with DSIRE link | GOOD |

### C3. Error States

| Screen | Failure | Error UI | Quality |
|--------|---------|----------|---------|
| ScanView — LiDAR unavailable | Full screen with explanation + manual fallback CTA | EXCELLENT |
| ScanView — Scan failed | Error icon + message + "Try Again" | EXCELLENT |
| EquipmentCameraView — Camera unavailable | Alert with message | GOOD |
| EquipmentCameraView — Photo fail | Alert with message | GOOD |
| ApplianceScanView — Classification empty | Alert "add it manually" (but no manual button!) | ⚠️ MISLEADING |
| ApplianceScanView — Camera fail | Alert | GOOD |
| LightingCloseupView — OCR finds nothing | Shows card with nil values, user can still proceed | ⚠️ No explicit message |
| BillUploadView — Parse finds nothing | "Could not parse... edit values in next step" | GOOD |
| BillUploadView — Photo library fail | Alert | GOOD |
| ReportPDFGenerator — Failure | Returns nil silently | ❌ No user feedback |

**No alerts anywhere have a "Retry" action** — all use only "OK" dismiss.

### C4. Keyboard Behavior

**CRITICAL: Zero keyboard dismiss mechanisms in the entire app.**

| View | Input fields | Keyboard type | Dismiss method | Issue |
|------|-------------|---------------|----------------|-------|
| AddHomeSheet | Name, Address, Sq Ft | default, default, `.numberPad` | **NONE** | Number pad has no Done key — user is trapped |
| DetailsView | Room Name, Floor Area | default, `.decimalPad` | **NONE** | Decimal pad has no return key |
| EquipmentDetailsView | Manufacturer, Model, Efficiency, Notes | default, default, `.decimalPad`, default | **NONE** | Decimal pad trapped |
| ApplianceDetailsView | Name, Wattage, Hours | default, `.decimalPad`, `.decimalPad` | **NONE** | Two decimal pads |
| BillDetailsView | Utility, kWh, Cost, Rate | default, `.decimalPad`, `.decimalPad`, `.decimalPad` | **NONE** | Three decimal pads |
| EnvelopeAssessmentView | Notes | default | **NONE** | Less critical (at bottom) |

**Required fixes:**
- Add `.scrollDismissesKeyboard(.interactively)` to all Form/ScrollView parents
- Add toolbar keyboard Done button for `.numberPad` and `.decimalPad` fields
- Consider `@FocusState` for field-to-field navigation

### C5. Text Audit

**Placeholder/debug text:** None found in user-visible strings. All user text is grammatically correct.

**Code comments indicating incomplete features:**
- `AuditFlowView.swift:237`: `// Actually need a separate state for manual room` — the button does nothing
- `AuditFlowView.swift:249`: `// Placeholder -- manual room entry handled by showingScan already` — dead sheet binding

**Truncation risks:**

| Location | Text | Risk |
|---|---|---|
| BillSummaryView | Utility name in `.title2.bold()` | MEDIUM — long utility names could truncate |
| HomeRowView | Home name in headline | LOW — HStack compresses |
| EquipmentResultView | Manufacturer in hero card | LOW |

**No typos, Lorem ipsum, or placeholder text found.**

### C6. Accessibility Audit

#### Explicit accessibility labels — partial coverage

**Present:** HomeListView "+" button, grade badges, dashboard section add buttons, all camera capture buttons, report grade display.

**Missing:**
- Onboarding page decorative icons
- AuditProgressBar step circles (no step name labels)
- DetailsView window info.circle button
- WindowQuestionnaireView/EnvelopeAssessmentView progress capsules
- DisclosureGroups in HomeReportView
- Decorative elements not hidden from VoiceOver

#### Touch target issues

| Element | Size | Minimum | Verdict |
|---------|------|---------|---------|
| Window info.circle button | ~12×12pt (`.font(.caption)`) | 44×44pt | **CRITICAL FAIL** |
| AuditProgressBar step circles | 28×28pt | 44×44pt | FAIL |
| Report tier badges | ~9pt text in capsule | N/A (not interactive) | OK |

#### Color contrast (WCAG 2.1 AA requires 4.5:1 for normal text, 3:1 for large)

| Combination | Ratio | Verdict |
|---|---|---|
| Accent (#E8720C) on white | ~3.3:1 | **FAILS** AA normal text, passes large text |
| White on accent (#E8720C) | ~3.3:1 | **FAILS** AA for caption text |
| Grade C (yellow) on white | ~2:1 | **FAILS** |
| `.white.opacity(0.7)` on accent (hero captions) | ~2.3:1 | **FAILS** |
| White on secondaryColor (#1A1A2E) | ~15:1 | PASSES |

#### Dynamic Type

**20 instances of hardcoded `.font(.system(size:))`** across the app:
- Most are for hero/icon display (40-72pt) — acceptable
- **Two at 9pt** in progress ring percentage (HomeDashboardView:176) and tier badge (HomeReportView:422) — **unreadable at larger Dynamic Type and won't scale**

#### VoiceOver
- Zero `.accessibilityElement(children:)` modifiers
- Zero `.accessibilityHidden()` modifiers
- Decorative elements (progress lines, dividers, balance spacers) all exposed to VoiceOver

### C7. Animation and Transitions

| Transition | Type | Quality |
|---|---|---|
| HomeList → Dashboard | NavigationLink push | ✅ Standard |
| Dashboard → any sheet | `.sheet()` | ✅ Standard |
| Dashboard → result/summary views | NavigationLink push | ✅ Standard |
| Camera → Details (3 flows) | Sheet dismiss + 0.3s asyncAfter + new sheet | ⚠️ Fragile timing |
| Onboarding pages | TabView `.page` with `withAnimation` | ✅ Smooth |
| WindowQuestionnaire steps | `.animation(.easeInOut, value: step)` | ✅ Smooth |
| EnvelopeAssessment steps | `.animation(.easeInOut, value: step)` | ✅ Smooth |
| **AuditFlow step changes** | **NO animation** | ❌ Jarring content swap |
| **Dashboard data changes** | **NO animation** | ⚠️ Items pop in/out |
| **Report grade reveal** | `gradeRevealed` state exists but no visual animation connected | ⚠️ Dead code |

### C8. Platform & Dark Mode

#### iPad issues

| Issue | Severity |
|---|---|
| All 4 camera UIViewRepresentables use `UIScreen.main.bounds` for frame sizing — deprecated and broken for iPad multitasking | HIGH |
| Camera preview `updateUIView` is empty — frame never updates on rotation | HIGH |
| No max-width constraints on card content — very wide on iPad landscape | MEDIUM |
| Forms in sheets take full width on iPad landscape | LOW |

#### Dark mode issues

| Issue | Severity |
|---|---|
| `Constants.secondaryColor` (#1A1A2E) used as button/card background — near-invisible against dark mode system background | HIGH |
| `Constants.accentColor` is hardcoded `Color(red:green:blue:)` — no Asset Catalog dark variant | LOW |
| Shadows (`.shadow(color: .black.opacity(0.04-0.06))`) invisible in dark mode | LOW |
| Most views use `.background` semantic color — adapts correctly | ✅ |

---

## D. Permissions & Device Features

### D1. Camera Permission

| Item | Status |
|---|---|
| Info.plist key (`NSCameraUsageDescription`) | ✅ Present — "Dezenit uses your camera to scan rooms with LiDAR and photograph equipment labels for OCR." |
| Explicit `AVCaptureDevice.requestAccess()` | ❌ Not called anywhere — relies on implicit system prompt |
| Pre-permission explanation screen | ❌ None |
| Post-denial recovery ("Go to Settings") | ❌ No `UIApplication.openSettingsURLString` anywhere |

**Denial behavior per view:**

| View | On camera denial |
|------|-----------------|
| EquipmentCameraView | Alert: "Camera is not available on this device" + black screen |
| ApplianceScanView | **Silent black screen** — no error, no message |
| LightingCloseupView | **Silent black screen** |
| BillUploadView | **Silent black screen** (but PhotosPicker works as workaround) |
| ScanView (RoomPlan) | Handled by RoomPlan framework — shows `.unavailable` or `.failed` |

### D2. Photo Library Permission

| Item | Status |
|---|---|
| Usage | `PhotosPicker` in BillUploadView (iOS 16+ out-of-process picker) |
| Info.plist key | ✅ Present but may not be needed for PhotosPicker |
| Explicit permission request | Not needed — PhotosPicker handles automatically |
| Denial behavior | PhotosPicker shows empty library — acceptable |

### D3. Location Permission

| Item | Status |
|---|---|
| Info.plist key (`NSLocationWhenInUseUsageDescription`) | ✅ Present — "Your approximate location is used to suggest a climate zone for energy calculations." |
| Explicit `requestWhenInUseAuthorization()` | ✅ Called in `ClimateZoneDetector.detectClimateZone()` and `StateDetectionService.detectState()` |
| When triggered | On `.onAppear` of AddHomeSheet, DetailsView, and HomeReportView |
| Pre-permission explanation | ❌ None — system prompt fires cold |
| Post-denial recovery | ❌ None |

**Denial behavior:**

| Consumer | On location denial |
|----------|--------------------|
| ClimateZoneDetector | Silent fallback to `.moderate` climate zone. No user feedback. |
| StateDetectionService | `detectedState` stays nil. Rebate section never appears. No user feedback. |

### D4. RoomPlan / ARKit

| Item | Status |
|---|---|
| Device capability check | ✅ `RoomCaptureSession.isSupported` checked. UI hides LiDAR option when unavailable. |
| Permission | Shares camera permission. No separate Info.plist key needed. |
| Fallback | ✅ "LiDAR Not Available" screen in ScanView (though "Enter Manually" CTA is a dead end) |

### D5. Permission Flow Summary

```
CURRENT STATE:
─────────────

Camera permission:
  First camera use → iOS system prompt (no pre-explanation)
    ├─ Allow → camera works
    └─ Deny → EquipmentCamera: shows alert
              ApplianceScan: SILENT BLACK SCREEN
              LightingCloseup: SILENT BLACK SCREEN
              BillUpload: SILENT BLACK SCREEN
              No "Go to Settings" anywhere

Location permission:
  First AddHomeSheet or DetailsView open → iOS system prompt
    ├─ Allow → climate zone auto-detected
    └─ Deny → silent fallback to "Moderate"
              No feedback, no Settings link

RECOMMENDED STATE:
──────────────────

Camera permission:
  First camera use → Custom explanation screen → iOS prompt
    ├─ Allow → camera works
    └─ Deny → Alert with "Open Settings" button
              All 4 camera views handle denial consistently

Location permission:
  First AddHomeSheet open → Brief explanation → iOS prompt
    ├─ Allow → climate zone auto-detected (with loading indicator)
    └─ Deny → Explicit "Using default: Moderate" message
              Option to manually select or go to Settings
```

---

## E. Master Issue Registry (Phase 3)

### Severity: CRITICAL (Data Loss / Crash Risk)

| # | Issue | Location |
|---|---|---|
| S1 | Room deletion cascade-deletes its appliances (even though they belong to Home) | Room.swift:18 — `.cascade` should be `.nullify` |
| S2 | No VersionedSchema — future schema changes risk data loss | DezenitApp.swift |
| S3 | Ambiguous @Relationship inverse for Appliance (Home and Room both claim `appliances`) | Home.swift:24, Room.swift:18 |

### Severity: STATE BUGS

| # | Issue | Location |
|---|---|---|
| S4 | `home.updatedAt` NOT updated on bill save | BillDetailsView.swift:126-141 |
| S5 | `home.updatedAt` NOT updated on ANY entity deletion | HomeDashboardView.swift:326,390,495,607 |
| S6 | `home.updatedAt` NOT updated on audit step completion | AuditFlowView.swift:664-668 |
| S7 | Competing writes to AuditProgress.currentStep — markComplete vs moveToNextStep | AuditFlowView.swift:666-668, AuditProgress.swift:91-100 |
| S8 | Dual source of truth for currentStep (@State vs persisted) | AuditFlowView.swift:10-11 |
| S9 | Prefill UIImage tuples never cleared after use (memory waste) | HomeDashboardView.swift:17,132-134; AuditFlowView.swift:21-25 |

### Severity: KEYBOARD (Ship Blocker)

| # | Issue | Location |
|---|---|---|
| K1 | `.numberPad` / `.decimalPad` fields have no dismiss mechanism — user is trapped | AddHomeSheet, DetailsView, EquipmentDetailsView, ApplianceDetailsView, BillDetailsView |
| K2 | No `.scrollDismissesKeyboard` on any Form/ScrollView | All form views |

### Severity: PERMISSIONS

| # | Issue | Location |
|---|---|---|
| P1 | 3 of 4 camera views show silent black screen on denial | ApplianceScanView, LightingCloseupView, BillUploadView |
| P2 | No "Go to Settings" prompt for any denied permission | Global |
| P3 | No pre-permission explanation for camera or location | Global |
| P4 | Location denial silently defaults with no user feedback | ClimateZoneDetector, StateDetectionService |

### Severity: UI POLISH

| # | Issue | Location |
|---|---|---|
| U1 | AuditFlowView step transitions have no animation | AuditFlowView.swift |
| U2 | Accent (#E8720C) on white fails WCAG AA contrast (3.3:1) | Constants.swift, used globally |
| U3 | Grade C yellow on white fails contrast (~2:1) | Constants.gradeColor, HomeReportView |
| U4 | `secondaryColor` (#1A1A2E) near-invisible in dark mode | Constants.swift:5, used in report button, onboarding |
| U5 | Window info button touch target ~12pt (should be 44pt) | DetailsView.swift:274 |
| U6 | AuditProgressBar step circles 28pt (should be 44pt) | AuditProgressBar.swift |
| U7 | Camera preview uses deprecated `UIScreen.main.bounds` — broken on iPad | All 4 camera UIViewRepresentables |
| U8 | Camera `updateUIView` is empty — frame never updates on rotation | All 4 camera preview views |
| U9 | 3 async operations (location/state detection) have no loading indicator | AddHomeSheet, DetailsView, HomeReportView |
| U10 | Two font sizes at 9pt won't scale with Dynamic Type | HomeDashboardView:176, HomeReportView:422 |
| U11 | No VoiceOver optimization (no accessibilityHidden on decorative elements) | Global |
| U12 | No animation on dashboard data additions/deletions | HomeDashboardView.swift |
| U13 | Camera→Details 0.3s asyncAfter pattern is fragile (6 instances) | HomeDashboardView, AuditFlowView |

### Severity: DATA VALIDATION

| # | Issue | Location |
|---|---|---|
| V1 | No upper bounds on numeric inputs (sqft, wattage, efficiency, kWh, cost) | All form views |
| V2 | `hoursPerDay` has no max of 24 — typo "240" gives 10x energy estimate | ApplianceDetailsView |
| V3 | Bill dates not validated — start can be after end | BillDetailsView |
| V4 | No duplicate-save guard on BillDetailsView (double-tap risk) | BillDetailsView |
| V5 | Whitespace-only home name passes validation | AddHomeSheet in HomeListView |

### Severity: HARDCODED DATA

| # | Issue | Location |
|---|---|---|
| H1 | 53 rebates have no expiration dates — programs change annually | RebateDatabase.swift |
| H2 | Rebate URLs not verified — may be stale | RebateDatabase.swift |
| H3 | Tax credits reference IRS 25C/25D without noting 2032 expiration | UpgradeEngine.swift |

---

## Phase 3 Totals

| Category | Count |
|---|---|
| Critical (data loss) | 3 |
| State bugs | 6 |
| Keyboard (ship blocker) | 2 |
| Permissions | 4 |
| UI polish | 13 |
| Data validation | 5 |
| Hardcoded data | 3 |
| **Total Phase 3 issues** | **36** |

**Combined with Phase 2 (38 issues), total audit issues: 74**
(Some overlap exists between phases — deduplicated count in Phase 4 prioritization)

---

*Phase 3 complete. No changes made. Ready for Phase 4: Prioritized Fix Plan.*
