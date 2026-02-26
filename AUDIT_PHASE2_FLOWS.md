# Dezenit Pre-Launch Audit — Phase 2: Flow Tracing

**Date:** 2026-02-22
**Audited from:** Actual code, not assumptions

---

## Table of Contents

1. [First Launch / Fresh Install](#1-first-launch--fresh-install)
2. [Onboarding Flow](#2-onboarding-flow)
3. [Post-Onboarding Flow](#3-post-onboarding-flow)
4. [Primary Feature Flows](#4-primary-feature-flows)
5. [Settings and Profile Flows](#5-settings-and-profile-flows)
6. [Returning User Flow](#6-returning-user-flow)
7. [Error and Edge Case Flows](#7-error-and-edge-case-flows)
8. [Current State Flow Map](#8-current-state-flow-map)
9. [Expected State Flow Map](#9-expected-state-flow-map)
10. [Master Issue Registry](#10-master-issue-registry)

---

## 1. First Launch / Fresh Install

### Exact Sequence

```
1. App launches → DezenitApp.body evaluates
2. SwiftData model container created for [Home, Room, Equipment, Appliance, EnergyBill, AuditProgress]
3. @AppStorage("hasSeenOnboarding") reads from UserDefaults → false (default)
4. Conditional: hasSeenOnboarding == false → OnboardingView()
5. User sees onboarding (3 pages)
```

### Conditional Branches

| Condition | Path |
|---|---|
| `hasSeenOnboarding == false` (always on fresh install) | OnboardingView |
| `hasSeenOnboarding == true` (never on fresh install) | HomeListView |

### Edge Cases

- **SwiftData schema migration failure:** No custom migration plan exists. If the schema is incompatible with an existing store (e.g., after an app update that adds required properties without defaults), the app crashes on launch with no recovery path.
- **No error handling on model container creation.** No `do/catch`, no fallback UI.
- **No deep link / URL scheme handling** in DezenitApp.
- **No `@ScenePhase` handling** — no actions on backgrounding or foregrounding.

---

## 2. Onboarding Flow

### Exact Sequence

```
Page 0: "Your Home Energy Audit"
  Icon: house.fill
  Body: "Scan rooms with LiDAR, log HVAC equipment..."
  Button: [Next] (amber, slightly dimmed)
  → Advances to page 1

Page 1: "What You'll Need"
  Icon: camera.fill
  Body: "A camera for equipment labels, LiDAR for room scanning (optional)..."
  Button: [Next]
  → Advances to page 2

Page 2: "Your Data, Your Devices"
  Icon: icloud.fill
  Body: "Syncs securely via iCloud across all your Apple devices..."
  Button: [Get Started] (amber, full opacity)
  → Fires success haptic
  → Sets hasSeenOnboarding = true in UserDefaults
  → DezenitApp re-evaluates body → swaps to HomeListView
```

### Conditional Branches

| Condition | Result |
|---|---|
| `currentPage == 2` | Shows "Get Started" button |
| `currentPage != 2` | Shows "Next" button |

### Every Possible Path

1. **Normal forward:** Page 0 → [Next] → Page 1 → [Next] → Page 2 → [Get Started] → HomeListView
2. **Swipe forward:** User can swipe the TabView pages without using buttons. Same final outcome.
3. **Swipe backward from page 2:** Button reverts to "Next". User can swipe back and forth freely.
4. **Rapid swipe past page 2:** TabView `.page` style stops at the last page. No crash.

### Dead Ends: None

### Issues Found

- **Onboarding cannot be replayed.** Once `hasSeenOnboarding = true`, there is no settings toggle to reset it. The user would have to reinstall the app.
- **`didGetStarted` double-tap:** If hypothetically tapped twice, the `.sensoryFeedback` trigger won't re-fire (value stays `true`). The `hasSeenOnboarding` write is idempotent. No issue in practice.
- **No skip option.** User must swipe/tap through all 3 pages. No "Skip" button.

---

## 3. Post-Onboarding Flow

### Exact Sequence

```
HomeListView appears inside NavigationStack
  ↓
homes.isEmpty == true (always true on fresh install)
  ↓
Empty State shows:
  Icon: house.fill (gray)
  Title: "Add Your Home"
  Subtitle: "Start your energy assessment"
  Button: [Add Your Home] (accent color)
  ↓
User taps [Add Your Home] OR [+] toolbar button
  ↓
AddHomeSheet presented as .sheet
  ↓
Form fields:
  - Name (required, placeholder: "Name (e.g. My House)")
  - Address (optional, placeholder: "Address (optional)")
  - Year Built (picker, default: 1990-2005)
  - Total Sq Ft (optional, number pad, placeholder: "optional")
  - Climate Zone (picker, default: Moderate; auto-detects from GPS on appear)
  ↓
[Save] pressed (disabled if name is empty)
  ↓
Home inserted into SwiftData
  ↓
@Query updates → homes not empty → list renders
  ↓
User taps home row → NavigationLink pushes HomeDashboardView
```

### Conditional Branches

| Condition | Result |
|---|---|
| `homes.isEmpty` | Empty state with "Add Your Home" CTA |
| `!homes.isEmpty` | List of homes with NavigationLinks |
| `name.isEmpty` | Save button disabled |
| `address.isEmpty` | Stored as `nil` |
| `Double(sqFt) == nil` | Stored as `nil` (no error shown) |
| Location detection succeeds | Climate zone auto-set |
| Location detection fails | Climate zone stays at `.moderate` default |

### Issues Found

- **Whitespace-only name accepted:** `" ".isEmpty == false`, so Save is enabled for `"   "`. HomeRowView would show `"   "` (not "Unnamed Home" since `" ".isEmpty == false`).
- **No minimum sqFt validation.** 0.001 or 999999999 accepted.
- **No cancel confirmation.** User loses all input silently.
- **No loading indicator for climate zone detection.** Picker may silently change while user is filling the form.
- **Rapid double-tap Save:** Could insert two identical homes before dismiss animation completes.
- **"+" toolbar button only visible when homes exist.** On empty state, only the CTA button works. This is intentional UX.

---

## 4. Primary Feature Flows

### 4A. Room Scan Flow (LiDAR)

```
HomeDashboardView → Rooms "+" Menu → "Scan Room (LiDAR)"
  ↓
ScanView presented as .sheet
  ↓
State machine:
  ┌─ .unavailable (no LiDAR)
  │    Shows: "LiDAR Not Available" + "Enter Measurements Manually"
  │    [Enter Measurements Manually] → dismiss() ← DEAD END (see issues)
  │
  ├─ .idle
  │    Shows: [Start Scan] button
  │    → Starts RoomCaptureSession + compass heading
  │
  ├─ .scanning
  │    Shows: Live AR camera + "Finish Scan" button
  │    [Finish Scan] → stops session → .processing
  │
  ├─ .processing
  │    Shows: Spinner + "Processing..."
  │    → Auto-transitions to .completed or .failed
  │
  ├─ .completed(capturedRoom)
  │    Shows: Floor area (sq ft) + window count
  │    [Continue] → opens DetailsView as nested sheet
  │    [Scan Again] → .idle
  │
  └─ .failed(error)
       Shows: "Scan Failed" + error message
       [Try Again] → .idle
       [Cancel] → dismiss

DetailsView (prefilled from scan):
  Form: Room name, floor area (prefilled), ceiling height, windows (prefilled), climate zone, insulation
  [Calculate] → creates Room + runs EnergyCalculator → pushes ResultsView

ResultsView:
  Shows: BTU, tonnage, breakdown, recommendations
  [Done] → dismisses entire scan flow
  [Share] → system share sheet with text report
```

**Issues:**
- **"Enter Measurements Manually" is a dead end.** Button calls `dismiss()` but does NOT open DetailsView in manual mode. The user is returned to the dashboard with no room added and no guidance to use the manual entry option.
- **No camera permission prompt.** RoomPlan handles permissions internally but there's no fallback if denied.

### 4B. Room Manual Entry Flow

```
HomeDashboardView → Rooms "+" Menu → "Enter Manually"
  ↓
DetailsView presented as .sheet (squareFootage: nil, no scannedWindows)
  ↓
Form: Room name, floor area (empty), ceiling height, windows (empty), climate zone, insulation
  Climate zone auto-detects from GPS on appear
  [Add Window] → adds default WindowInfo to array
  Window info button → WindowQuestionnaireView (4-step assessment)
  [Calculate] → creates Room → pushes ResultsView
  [Cancel] → dismiss
```

**Issues:**
- **Room name can be empty.** Saved as `""`. Shown as "Unnamed Room" in dashboard.
- **Only validation is `squareFootage > 0`.** Everything else has defaults.

### 4C. Window Questionnaire Sub-Flow

```
DetailsView → Window info button (ℹ)
  ↓
WindowQuestionnaireView as .sheet
  ↓
Step 0: Pane Type (single/double/triple) — selection cards
Step 1: Frame Material (aluminum/wood/vinyl/fiberglass/composite)
Step 2: Window Condition (good/fair/poor) + live U-factor preview
Step 3: Direction (N/S/E/W) + Size (small/medium/large) + live BTU preview
  ↓
[Done] → dismiss
[Cancel] → dismiss
```

**CRITICAL ISSUE: Cancel does NOT revert changes.** The view uses `@Binding var window: WindowInfo`, so all changes are live. Cancel and Done have identical effects — whatever the user selected on steps 0-2 is already written to the binding. There is no snapshot/restore mechanism.

### 4D. Equipment Scan Flow

```
HomeDashboardView → Equipment "+" button
  ↓
EquipmentDetailsView as .sheet
  ↓
Form: Equipment type picker, photo section, manufacturer, model, efficiency, age, notes
  [Photograph Equipment Label] → EquipmentCameraView as nested sheet
    Camera captures → OCR processes → auto-fills manufacturer, model, efficiency
  [Retake Photo] → re-opens camera
  [Save] → creates Equipment → pushes EquipmentResultView
  [Cancel] → dismiss

EquipmentResultView:
  Shows: Hero card, efficiency comparison bar, upgrade tiers (Good/Better/Best)
  [Done] → dismisses entire equipment flow
```

**Issues:**
- **Save button has NO validation.** Always enabled. User can save immediately with all defaults (Central AC, estimated efficiency, no photo, no details).
- **Silent OCR failure.** If OCR finds nothing, no error is shown — fields just stay empty.
- **Camera unavailable on EquipmentCameraView:** Shows alert "Camera is not available on this device" but then leaves user on black screen. Must manually tap Cancel.

### 4E. Appliance Scan Flow (Camera Classification)

```
HomeDashboardView → Appliances "+" Menu → "Scan with Camera"
  ↓
ApplianceScanView as .sheet
  Camera captures → VNClassifyImageRequest → classification chips shown
  User taps a classification chip
  ↓
Camera sheet dismisses
  ↓ (0.3s delay for sheet dismiss animation)
ApplianceDetailsView as .sheet (prefilled category + image)
  ↓
Form: Category (prefilled), name, wattage, hours/day, quantity, room
  [Save] → creates Appliance → pushes ApplianceResultView
  [Cancel] → dismiss

ApplianceResultView:
  Shows: Energy breakdown, phantom load, upgrade tips
  [Done] → dismisses flow
```

**Issues:**
- **Classification returns empty:** Alert says "add it manually" but provides no "Enter Manually" button. User must Cancel out and navigate to manual entry separately.
- **Camera unavailable:** Silently fails — black screen with no message (unlike EquipmentCameraView which shows an alert).

### 4F. Lighting Scan Flow (Bulb OCR)

```
HomeDashboardView → Appliances "+" Menu → "Scan Bulb Label"
  ↓
LightingCloseupView as .sheet
  Camera captures → LightingOCRService → OCR results card shown
  [Use This] → accepts OCR result
  [Skip] → QuickWattageSelectView (grid of common wattages by type)
  [Retake] → retry
  ↓
Camera sheet dismisses
  ↓ (0.3s delay)
ApplianceDetailsView as .sheet (prefilled wattage + category)
  ↓
Same flow as appliance details → save → result → done
```

**Issues:**
- **Captured image discarded.** At `HomeDashboardView:84`, the image from the lighting scan is destructured with `_` and never passed to `ApplianceDetailsView`. Unlike the appliance scan flow which passes `prefilledImage`. The lighting appliance is saved without a photo.
- **Camera unavailable:** Same silent failure as ApplianceScanView.
- **QuickWattageSelectView passes `UIImage()`** (empty image) as the captured image when the user skips OCR.

### 4G. Bill Scan Flow

```
HomeDashboardView → Bills "+" Menu → "Scan Bill"
  ↓
BillUploadView as .sheet
  Camera or PhotosPicker → BillParsingService → parsed result card
  [Use This] → accepts parsed result
  Menu: [Photo Library] → PhotosPicker
  Menu: [Enter Manually] → onManual callback
  [Retake] → retry
  ↓
Camera sheet dismisses
  ↓ (0.3s delay)
BillDetailsView as .sheet (prefilled from OCR)
  ↓
Form: Utility name, billing period, kWh, cost, rate, computed stats
  [Save] → creates EnergyBill → dismiss
  [Cancel] → dismiss
```

**BUGS:**
- **Bill manual path state bug:** The `onManual` callback in HomeDashboardView does NOT set `showingBillScan = false`. `BillUploadView` presumably dismisses itself, but the state variable stays `true`. After the 0.3s delay, `showingBillManual` is set to `true`. Two sheet bindings are simultaneously `true`. SwiftUI behavior is undefined — the manual entry sheet may fail to present.
- **BillDetailsView Cancel calls `onComplete()`:** Both Cancel and Save trigger the parent's completion handler. The parent cannot distinguish save vs. cancel.

### 4H. Audit Flow (10-Step Guided)

```
HomeDashboardView → Audit banner ("Start Full Audit" / "Continue Audit")
  ↓
AuditFlowView as .sheet
  Progress bar at top (display-only, NOT tappable)
  ↓
Step 1: Home Basics — READ-ONLY display of home info. Auto-completed on entry.
Step 2: Room Scanning — Room list + [Scan Room] + [Enter Manually]
Step 3: HVAC Equipment — HVAC list + [Add HVAC Equipment]
Step 4: Water Heating — Water heater list + [Add Water Heating]
Step 5: Appliance Inventory — Appliance list + [Scan] + [Manual]
Step 6: Lighting Audit — Lighting list + [Scan Label] + [Manual]
Step 7: Window Assessment — Room list with window counts (NOT tappable)
Step 8: Envelope Assessment — EnvelopeAssessmentView (3-step sub-flow)
Step 9: Bill Upload — Bill list + [Scan Bill] + [Manual]
Step 10: Review — Summary + [View Full Report] NavigationLink + [Finish]
```

**Bottom bar logic:**

| Step | Left | Right |
|---|---|---|
| Step 1 | (hidden) | Skip + Next/Done |
| Steps 2-7, 9 | Back | Skip + Next/Done |
| Step 8 | Back | Skip only (envelope has own Save) |
| Step 10 | Back | Finish |

**"Next" vs "Done" label:** Shows "Next" if `isCurrentStepSatisfied` (data exists), "Done" if not. Both call the same function.

**CRITICAL BUGS:**
1. **Step 2 "Enter Manually" is dead.** The button handler contains only comments and `showingScan = false`. It never sets `showingManualRoom = true`. The state variable and sheet exist but are never triggered.
2. **Step 7 room rows are NOT tappable.** Text says "Tap a room to edit its window assessment" but the rows are plain HStacks with no tap handler. Users cannot assess windows from the audit flow.
3. **Step 10 "Finish" does NOT mark review complete.** The review step is only marked complete if the user taps "View Full Report" (which triggers `completeCurrentStep()` via `.onAppear`). Tapping "Finish" directly just dismisses — audit shows 9/10 next time.
4. **Progress bar is display-only.** Despite looking tappable, the step circles have no tap gesture. Users cannot jump to a specific step.

**Dismissal mid-flow:**
- Progress IS saved. `AuditProgress` is a SwiftData model that persists on every step change.
- Unsaved sub-flow data IS lost (e.g., half-filled EnvelopeAssessmentView).
- On reopen: `setupAudit()` finds existing audit and resumes at the persisted step.

### 4I. Envelope Assessment Sub-Flow (within Audit Step 8)

```
Sub-step 0: Insulation Assessment
  - Attic Insulation: Poor / Average / Good
  - Wall Insulation: Poor / Average / Good

Sub-step 1: Foundation & Air Sealing
  - Basement/Crawlspace: Uninsulated / Partial / Full
  - Air Sealing: Good / Fair / Poor
  - Weatherstripping: Good / Fair / Poor

Sub-step 2: Summary + Notes
  - Read-only review of selections
  - Optional notes text field
  [Save] → writes home.envelope → calls parent's completeCurrentStep()
```

**Issues:**
- Unsaved data lost on dismiss (local `@State`, not persisted until Save).
- Pre-populates from existing `home.envelope` if it exists.

### 4J. Home Report Flow

```
HomeDashboardView → [View Full Report] NavigationLink
  (only visible when rooms.count > 0 OR equipment.count > 0)
  ↓
HomeReportView
  12+ sections, all conditional based on data:
```

| Section | Shows when |
|---|---|
| Summary + grade | Always |
| Cost estimate | `!home.equipment.isEmpty` |
| Energy profile bar | `profile.breakdown.count > 1` |
| Bill reconciliation | `profile.billComparison != nil` |
| Appliance highlights | `!profile.topConsumers.isEmpty` |
| Envelope summary | `profile.envelopeScore != nil` |
| Upgrade stats | `!allUpgradesByEquipment.isEmpty` |
| Upgrade tiers | `!allUpgradesByEquipment.isEmpty` |
| Quick wins | Always (always ≥ 1 recommendation) |
| Tax credits | `taxCredits.grandTotal > 0` |
| Rebates | `stateDetector.detectedState != nil` |
| Battery synergy | Always (even with zero data — **misleading**) |
| Share | Always |

**Issues:**
- **Battery Synergy always renders with fabricated numbers.** Shows "Current estimated base load: 5.0 kW" based on 1500 sqft default even with zero data.
- **`breakdown.count > 1` hides single-category data.** If a home has only HVAC equipment, the energy profile section doesn't show.
- **Force-unwrap crash risk:** `URL(string: rebate.url)!` — if any rebate URL is malformed, app crashes.
- **ReportPDFGenerator is broken.** `pdfData as! CFMutableData` force cast will crash at runtime. The PDF feature is non-functional. Also, it's never called from any UI — it's dead code.
- **Share text inconsistencies:** Empty home name shows "Home: " (no fallback). Battery Synergy section omitted from share text but shown in UI.
- **35 US states have no rebate data.** No explanation shown for users in unsupported states.

---

## 5. Settings and Profile Flows

**There are no settings or profile screens.** The app has zero settings, preferences, accounts, or profile functionality.

- No way to edit a home after creation (name, address, year built, sqft, climate zone are set once in AddHomeSheet and only editable in Audit Flow Step 1 — but Step 1 is read-only)
- No way to edit existing rooms, equipment, appliances, or bills (only delete)
- No way to replay onboarding
- No way to export/import data
- No way to change units (imperial/metric)
- No way to change electricity rate globally
- No dark mode toggle (follows system)

---

## 6. Returning User Flow

### 6A. Returning After Partial Completion

```
App launch → hasSeenOnboarding == true → HomeListView
  ↓
@Query loads existing homes → list renders
  ↓
User taps home → HomeDashboardView
  ↓
Audit banner shows based on home.currentAudit:
  - nil: "Start Full Audit" (10-step guided)
  - exists, !isComplete: "Continue Audit" (shows current step + progress %)
  - exists, isComplete: Static "Audit Complete" badge (non-interactive)
  ↓
All previously added rooms/equipment/appliances/bills visible in their sections
```

### 6B. Returning After Full Completion

```
Same flow → HomeDashboardView
  ↓
Audit banner: "Audit Complete" (static badge, no tap action)
All data visible in sections
Report button visible if rooms or equipment exist
  ↓
User can still add more data via section "+" buttons
But no way to restart audit or re-assess
```

### 6C. App State After Delete and Reinstall

- `hasSeenOnboarding` is in UserDefaults → **survives app delete** on iOS (until UserDefaults are purged)
- SwiftData store is deleted with the app
- **Potential mismatch:** User could skip onboarding (UserDefaults says "seen") but have empty SwiftData. HomeListView handles this correctly with its empty state.

### Issues

- **No way to restart a completed audit.** The banner becomes static. There is no "Reset Audit" or "Start New Audit" option.
- **No way to edit a home's basic info** from the dashboard. The AddHomeSheet only fires for new homes. Audit Flow Step 1 is read-only.
- **No way to edit existing rooms/equipment/appliances/bills.** Only delete + re-add.

---

## 7. Error and Edge Case Flows

### 7A. Camera Permission Denied

| View | Behavior |
|---|---|
| EquipmentCameraView | Shows alert: "Camera is not available on this device." Then black screen — user must tap Cancel. |
| ApplianceScanView | **Silent failure.** Black screen, no message. User discovers error only by trying to capture. |
| LightingCloseupView | **Silent failure.** Same as above. |
| BillUploadView | **Silent failure.** Same as above. |
| ScanView (LiDAR) | RoomPlan handles internally. If denied, likely shows `.failed` or `.unavailable` state. |

**No "Open Settings" prompt anywhere.** If camera is denied, there is no guidance for the user to fix it.

### 7B. Location Permission Denied

| Consumer | Behavior |
|---|---|
| ClimateZoneDetector (AddHomeSheet, DetailsView) | Silent fallback to `.moderate`. No indicator. |
| StateDetectionService (HomeReportView) | `detectedState` stays nil. Rebate section simply never appears. No indicator. |

### 7C. No Internet

The app is entirely offline. No API calls, no network requests. Internet status is irrelevant.

### 7D. LiDAR Unavailable

```
ScanView → .unavailable state
  Icon: iphone.slash
  Title: "LiDAR Not Available"
  Body: "RoomPlan requires an iPhone 12 Pro or later with LiDAR scanner."
  [Enter Measurements Manually] → dismiss() ← DEAD END
```

**The "Enter Measurements Manually" button dismisses ScanView but does NOT open DetailsView.** The user returns to the dashboard with no indication of what to do next. They must independently discover the "Enter Manually" option in the Rooms "+" menu.

### 7E. Empty States Summary

| Screen | Empty state | Content |
|---|---|---|
| HomeListView | No homes | Icon + "Add Your Home" + "Start your energy assessment" + CTA button |
| HomeDashboardView rooms | No rooms | "No rooms scanned yet. Add a room to start your assessment." |
| HomeDashboardView equipment | No equipment | "No equipment logged yet. Add your HVAC, water heater, and more." |
| HomeDashboardView appliances | No appliances | "No appliances tracked yet. Scan or add appliances, lighting, and electronics." |
| HomeDashboardView bills | No bills | "No bills uploaded yet. Add utility bills to improve cost estimates." |
| HomeDashboardView grade | No equipment | Shows "--" with "No Data" label |
| HomeDashboardView report | No rooms AND no equipment | **Report button completely hidden** — no indication it exists |
| AuditFlowView Step 7 | No rooms | "Add rooms first (Step 2) to assess windows." |
| HomeReportView (minimal) | Equipment empty | Cost section hidden, upgrade sections hidden. Only summary (grade C default), quick wins, battery synergy, and share visible. |

### 7F. Data Deletion Edge Cases

**HomeDashboardView:** All swipe-to-delete actions use `.swipeActions` on items inside `ForEach` within `VStack` within `ScrollView`.

**CRITICAL ISSUE:** `.swipeActions` only works inside a `List` context. These are NOT in a List — they are in a ScrollView > VStack. **Swipe-to-delete may be entirely non-functional on the dashboard.** The only confirmed working delete is in HomeListView (which uses a `List`).

If swipe-to-delete is broken, there is **no way to delete rooms, equipment, appliances, or bills** from the dashboard. The only delete path would be deleting the entire home from HomeListView.

### 7G. Concurrency / Race Conditions

1. **Camera-to-details 0.3s delay:** All three camera→details flows use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)`. If the dismiss animation takes longer than 0.3s (slow device, accessibility animations), the new sheet may fail to present.
2. **Multiple sheets simultaneously:** HomeDashboardView has 12 `.sheet` modifiers. SwiftUI presents only one at a time — if two bindings become `true` simultaneously, only one presents. The 0.3s delays mitigate this but it is fragile.
3. **Bill scan manual path:** `showingBillScan` is not set to `false` in the `onManual` callback, so two sheet bindings may be `true` simultaneously.

---

## 8. Current State Flow Map

This is how the app **actually behaves** based on the code:

```
┌─────────────────────────────────────────────────────────────┐
│                        APP LAUNCH                            │
│  hasSeenOnboarding?                                          │
│  ├─ NO → OnboardingView (3 pages) → [Get Started]           │
│  └─ YES → HomeListView                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       HOME LIST VIEW                         │
│  homes.isEmpty?                                              │
│  ├─ YES → Empty state + [Add Your Home]                      │
│  └─ NO → List of homes + [+] toolbar                         │
│          ├─ Tap home → HomeDashboardView                     │
│          └─ Swipe → Delete with confirmation ✅               │
│                                                              │
│  [+] or CTA → AddHomeSheet                                   │
│    Name (required), Address, Year, SqFt, Climate             │
│    GPS auto-detects climate zone (silent)                    │
│    [Save] → insert Home → dismiss                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    HOME DASHBOARD VIEW                        │
│                                                              │
│  ┌─ AUDIT BANNER ──────────────────────────────────────────┐ │
│  │ No audit:     [Start Full Audit] → AuditFlowView        │ │
│  │ In progress:  [Continue Audit] → AuditFlowView          │ │
│  │ Complete:     Static badge (NO action) ← DEAD END       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ SUMMARY CARD ──────────────────────────────────────────┐ │
│  │ Grade (or "--"), rooms, equipment, sqft, appliances,     │ │
│  │ bills (each shown conditionally)                         │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ ROOMS ─────────────────────────────────────────────────┐ │
│  │ Menu: [Scan Room (LiDAR)] → ScanView                    │ │
│  │       [Enter Manually] → DetailsView                     │ │
│  │ Tap room → ResultsView                                   │ │
│  │ Swipe-to-delete ← MAY BE BROKEN (not in List) ⚠️        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ EQUIPMENT ─────────────────────────────────────────────┐ │
│  │ [+] → EquipmentDetailsView                               │ │
│  │ Tap equipment → EquipmentResultView                      │ │
│  │ Swipe-to-delete ← MAY BE BROKEN ⚠️                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ APPLIANCES ────────────────────────────────────────────┐ │
│  │ Menu: [Scan with Camera] → ApplianceScanView             │ │
│  │       [Scan Bulb Label] → LightingCloseupView            │ │
│  │       [Enter Manually] → ApplianceDetailsView            │ │
│  │ Tap appliance → NOTHING ← DEAD END                      │ │
│  │ Swipe-to-delete ← MAY BE BROKEN ⚠️                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ BILLS ─────────────────────────────────────────────────┐ │
│  │ Menu: [Scan Bill] → BillUploadView                       │ │
│  │       [Enter Manually] → BillDetailsView                 │ │
│  │ Tap bill → BillSummaryView                               │ │
│  │ Swipe-to-delete ← MAY BE BROKEN ⚠️                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ REPORT ────────────────────────────────────────────────┐ │
│  │ [View Full Report] → HomeReportView                      │ │
│  │ (HIDDEN when 0 rooms AND 0 equipment)                    │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    AUDIT FLOW (10 STEPS)                      │
│                                                              │
│  Step 1: Home Basics — READ-ONLY display ← NO EDIT          │
│  Step 2: Rooms — [Scan Room] works, [Enter Manually] BROKEN │
│  Step 3: HVAC Equipment — [Add HVAC] works ✅                │
│  Step 4: Water Heating — [Add Water Heating] works ✅        │
│  Step 5: Appliances — [Scan] + [Manual] works ✅             │
│  Step 6: Lighting — [Scan Label] + [Manual] works ✅         │
│  Step 7: Windows — Room rows NOT TAPPABLE ← BROKEN          │
│  Step 8: Envelope — Sub-flow works ✅                        │
│  Step 9: Bills — [Scan] + [Manual] works ✅                  │
│  Step 10: Review — [View Report] marks complete              │
│           [Finish] does NOT mark complete ← BUG             │
│                                                              │
│  Progress bar: DISPLAY ONLY (not tappable) ← GAP            │
│  Skip: available on all steps except Review ✅               │
│  Back: available on all steps except Step 1 ✅               │
│  Dismiss mid-flow: Progress saved to SwiftData ✅            │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Expected State Flow Map

Based on component names, code comments, and architectural intent:

```
EXPECTED BUT MISSING:
━━━━━━━━━━━━━━━━━━━

1. EDIT FLOWS
   - Tap home in list → Edit home details (name, address, year, sqft, climate)
   - Tap room → Edit room details (not just view results)
   - Tap equipment → Edit equipment details (not just view results)
   - Tap appliance → View/Edit appliance (currently no tap action at all)
   - Tap bill → Edit bill (currently view-only in BillSummaryView)

2. AUDIT FLOW COMPLETENESS
   - Step 1: Should be editable (form fields, not read-only display)
   - Step 2: "Enter Manually" should open DetailsView
   - Step 7: Room rows should be tappable to edit window assessments
   - Step 10: "Finish" should mark review as complete
   - Progress bar: Steps should be tappable to jump

3. DELETION
   - Dashboard swipe-to-delete should work (needs List context)
   - Delete should have confirmation dialogs (like HomeListView has)
   - Undo support for accidental deletes

4. CAMERA FLOWS
   - All camera views should proactively detect unavailability (not just EquipmentCameraView)
   - "Enter Manually" fallback from every camera-unavailable state
   - "Open Settings" prompt when camera permission is denied

5. ScanView
   - "Enter Measurements Manually" should open DetailsView, not just dismiss

6. REPORT
   - PDF generation should work (currently crashes)
   - Share should produce same content as visual report
   - Battery Synergy should hide when no data
   - Rebates should explain "not available in your area" for unsupported states

7. SETTINGS
   - Edit home details after creation
   - Reset/replay onboarding
   - Change electricity rate
   - Export data
   - About/version info

8. WINDOW QUESTIONNAIRE
   - Cancel should revert changes (needs snapshot/restore)

9. BILL DETAILS
   - Cancel should NOT call onComplete (parent needs to distinguish)
```

---

## 10. Master Issue Registry

### Severity: CRASH

| # | Issue | Location |
|---|---|---|
| C1 | `pdfData as! CFMutableData` force cast crashes at runtime | ReportPDFGenerator.swift:18 |
| C2 | `URL(string: rebate.url)!` force unwrap on potentially malformed URL | HomeReportView.swift:850 |
| C3 | SwiftData schema migration failure crashes app on launch (no migration plan) | DezenitApp.swift |

### Severity: BROKEN FEATURE

| # | Issue | Location |
|---|---|---|
| B1 | Audit Step 2 "Enter Manually" button does nothing (dead button) | AuditFlowView.swift:236-241 |
| B2 | Audit Step 7 window assessment room rows not tappable (text promises tap) | AuditFlowView.swift:422-440 |
| B3 | ScanView "Enter Measurements Manually" just dismisses (dead end) | ScanView.swift |
| B4 | `.swipeActions` outside `List` context — may be entirely non-functional | HomeDashboardView.swift:324,388,493,605 |
| B5 | Bill scan manual path `showingBillScan` never set to false | HomeDashboardView.swift:103-107 |

### Severity: FUNCTIONAL BUG

| # | Issue | Location |
|---|---|---|
| F1 | WindowQuestionnaireView Cancel does not revert changes (@Binding is live) | WindowQuestionnaireView.swift |
| F2 | BillDetailsView Cancel calls onComplete — parent can't distinguish save/cancel | BillDetailsView.swift |
| F3 | Audit Step 10 "Finish" does not mark review complete | AuditFlowView.swift |
| F4 | Lighting scan discards captured image (unlike appliance scan) | HomeDashboardView.swift:84, AuditFlowView.swift:86 |
| F5 | Three sheets can render blank if prefill optionals are nil at presentation | HomeDashboardView.swift:64,84,116 |
| F6 | Camera unavailable: silent failure on 3 of 4 camera views | ApplianceScanView, LightingCloseupView, BillUploadView |

### Severity: UX GAP

| # | Issue | Location |
|---|---|---|
| U1 | No way to edit home details after creation | Global |
| U2 | No way to edit existing rooms/equipment/appliances/bills | Global |
| U3 | No way to restart a completed audit | HomeDashboardView audit banner |
| U4 | Appliance rows are not tappable (no view/edit) | HomeDashboardView.swift:465-500 |
| U5 | Dashboard swipe-to-delete has no confirmation dialogs | HomeDashboardView.swift |
| U6 | Report button hidden when 0 rooms AND 0 equipment — no indication it exists | HomeDashboardView.swift:621 |
| U7 | Progress bar not tappable (display-only) | AuditProgressBar.swift |
| U8 | Completed audit banner is non-interactive | HomeDashboardView.swift:141-194 |
| U9 | Battery Synergy renders with fabricated numbers when no data | HomeReportView.swift:880-920 |
| U10 | 35 US states have no rebate data, no explanation shown | RebateDatabase.swift |
| U11 | No "Open Settings" prompt for denied camera/location permissions | Global |
| U12 | No loading state for rebate location detection | HomeReportView.swift |
| U13 | Audit Step 1 is read-only (expected to be editable) | AuditFlowView.swift |
| U14 | `breakdown.count > 1` hides single-category energy profile | HomeReportView.swift:81 |
| U15 | Onboarding cannot be replayed | Global |
| U16 | Whitespace-only home name accepted by validation | AddHomeSheet |

### Severity: DEAD CODE

| # | Issue | Location |
|---|---|---|
| D1 | ReportPDFGenerator never called from any UI | ReportPDFGenerator.swift |
| D2 | `Rebate.expirationNote` property never used (always nil) | RebateDatabase.swift:39 |
| D3 | `StateDetectionService.isDetecting` never consumed by any view | StateDetectionService.swift:8 |
| D4 | Prefill UIImages never freed after use (stale optional state) | HomeDashboardView.swift |

### Severity: PERFORMANCE

| # | Issue | Location |
|---|---|---|
| P1 | DateFormatter created per-render per-row inside bill ForEach | HomeDashboardView.swift:583-585 |

### Severity: DATA INTEGRITY

| # | Issue | Location |
|---|---|---|
| I1 | No SwiftData error handling anywhere (insert, delete, save) | Global |
| I2 | No input validation on equipment save (always enabled) | EquipmentDetailsView.swift |
| I3 | No input validation on appliance save (always enabled) | ApplianceDetailsView.swift |
| I4 | Bill date range not validated (start > end allowed) | BillDetailsView.swift |
| I5 | Rapid double-tap Save can insert duplicate entries | AddHomeSheet, all detail views |

---

**Total issues found: 38**
- Crash: 3
- Broken Feature: 5
- Functional Bug: 6
- UX Gap: 16
- Dead Code: 4
- Performance: 1
- Data Integrity: 5

---

*Phase 2 Flow Tracing complete. No changes made. Ready for Phase 3.*
