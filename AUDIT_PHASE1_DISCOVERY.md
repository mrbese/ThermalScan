# Dezenit Pre-Launch Audit — Phase 1: Discovery

**Date:** 2026-02-22
**Project:** `/Users/mrbese/Coding/Claude_Code_Mr_Bese/ThermalScan/Dezenit/`
**Total Files:** 49 Swift files
**Breakdown:** 2 App/Config, 11 Models, 14 Services, 22 Views

---

## Table of Contents

1. [App Entry & Config](#1-app-entry--config)
2. [Models](#2-models)
3. [Services](#3-services)
4. [Views — Complete Inventory](#4-views--complete-inventory)
5. [Navigation Sitemap](#5-navigation-sitemap)
6. [Data Flow Architecture](#6-data-flow-architecture)
7. [State Management Inventory](#7-state-management-inventory)
8. [Reachability Analysis](#8-reachability-analysis)

---

## 1. App Entry & Config

### 1.1 DezenitApp.swift
**Path:** `App/DezenitApp.swift`

| Field | Value |
|---|---|
| Purpose | App entry point — gates onboarding vs main app |
| State reads | `@AppStorage("hasSeenOnboarding")` |
| State writes | None (downstream views write it) |
| Model container | `[Home.self, Room.self, Equipment.self, Appliance.self, EnergyBill.self, AuditProgress.self]` |
| Root navigation | `OnboardingView()` if !hasSeenOnboarding, else `HomeListView()` |

### 1.2 Constants.swift
**Path:** `Utils/Constants.swift`

| Constant Group | Contents |
|---|---|
| Colors | `accentColor` (#E8720C amber), `secondaryColor` (#1A1A2E charcoal), `statusSuccess`, `statusWarning`, `gradeColor(_:)` |
| HVAC | `safetyFactor` (1.10), `btuPerTon` (12,000) |
| Climate | ClimateFactors: hot 30, moderate 25, cold 35 |
| Ceiling | CeilingFactors: 8ft 1.0, 9ft 1.12, 10ft 1.25, 12ft 1.5 |
| Insulation | InsulationMultipliers: poor 1.30, average 1.00, good 0.85 |
| Windows | WindowBTUPerSqFt (N/S/E/W), WindowSizeSqFt (S/M/L) |
| Energy rates | defaultElectricityRate $0.16/kWh, defaultGasRate $1.20/therm |
| Lighting | CommonBulbWattages (LED/CFL/incandescent arrays) |
| Phantom loads | PhantomLoads (entertainment 25W, office 12W, kitchen 8W, smart strip 75% savings) |

---

## 2. Models

### 2.1 Home.swift — `@Model`
**Path:** `Models/Home.swift`

**Stored Properties:**

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | |
| `address` | `String?` | |
| `yearBuilt` | `String` | `YearRange.rawValue` |
| `totalSqFt` | `Double?` | Manual override; falls back to sum of room areas |
| `climateZone` | `String` | `ClimateZone.rawValue` |
| `envelopeData` | `Data?` | JSON `EnvelopeInfo` |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | |

**Relationships (all cascade delete):**

| Relationship | Type | Inverse |
|---|---|---|
| `rooms` | `[Room]` | `room.home` |
| `equipment` | `[Equipment]` | `equipment.home` |
| `appliances` | `[Appliance]` | `appliance.home` |
| `energyBills` | `[EnergyBill]` | `bill.home` |
| `auditProgress` | `[AuditProgress]` | `audit.home` |

**Computed Properties:** `yearBuiltEnum`, `climateZoneEnum`, `computedTotalSqFt`, `totalBTU`, `totalApplianceAnnualKWh`, `totalPhantomLoadWatts`, `totalPhantomAnnualKWh`, `billBasedAnnualKWh`, `actualElectricityRate`, `currentAudit`, `envelope`

**Nested types:** `YearRange` enum (5 cases), `EnvelopeInfo` Codable struct (atticInsulation, wallInsulation, basementInsulation, airSealing, weatherstripping, notes)

---

### 2.2 Room.swift — `@Model`
**Path:** `Models/Room.swift`

| Property | Type |
|---|---|
| `id` | `UUID` |
| `name` | `String` |
| `squareFootage` | `Double` |
| `ceilingHeight` | `Int` (8/9/10/12) |
| `climateZone` | `String` |
| `insulation` | `String` |
| `windowsData` | `Data?` (JSON `[WindowInfo]`) |
| `calculatedBTU` | `Double` |
| `calculatedTonnage` | `Double` |
| `createdAt` | `Date` |
| `scanWasUsed` | `Bool` |

**Relationships:** `home: Home?`, `appliances: [Appliance]` (cascade)
**Computed:** `windows`, `climateZoneEnum`, `insulationEnum`, `ceilingHeightOption`
**Nested:** `CeilingHeightOption` enum

---

### 2.3 Equipment.swift — `@Model`
**Path:** `Models/Equipment.swift`

| Property | Type |
|---|---|
| `id` | `UUID` |
| `type` | `String` (`EquipmentType.rawValue`) |
| `manufacturer` | `String?` |
| `modelNumber` | `String?` |
| `ageRange` | `String` (`AgeRange.rawValue`) |
| `estimatedEfficiency` | `Double` |
| `currentCodeMinimum` | `Double` |
| `bestInClass` | `Double` |
| `photoData` | `Data?` |
| `notes` | `String?` |
| `createdAt` | `Date` |

**Relationship:** `home: Home?`

---

### 2.4 Appliance.swift — `@Model`
**Path:** `Models/Appliance.swift`

| Property | Type |
|---|---|
| `id` | `UUID` |
| `category` | `String` (`ApplianceCategory.rawValue`) |
| `name` | `String` |
| `estimatedWattage` | `Double` |
| `hoursPerDay` | `Double` |
| `quantity` | `Int` |
| `detectionMethod` | `String` ("manual"/"camera"/"ocr") |
| `photoData` | `Data?` |
| `createdAt` | `Date` |

**Relationships:** `room: Room?`, `home: Home?`
**Computed:** `categoryEnum`, `annualKWh`, `annualCost(rate:)`, `phantomAnnualKWh`, `totalAnnualKWh`
**Nested:** `ApplianceCategory` enum — 25 cases across 5 groups (Entertainment, Computing, Kitchen, Lighting, Other)

---

### 2.5 EnergyBill.swift — `@Model`
**Path:** `Models/EnergyBill.swift`

| Property | Type |
|---|---|
| `id` | `UUID` |
| `billingPeriodStart` | `Date?` |
| `billingPeriodEnd` | `Date?` |
| `totalKWh` | `Double` |
| `totalCost` | `Double` |
| `ratePerKWh` | `Double?` |
| `utilityName` | `String?` |
| `photoData` | `Data?` |
| `rawOCRText` | `String?` |
| `createdAt` | `Date` |

**Relationship:** `home: Home?`
**Computed:** `billingDays`, `dailyAverageKWh`, `annualizedKWh`, `computedRate`

---

### 2.6 AuditProgress.swift — `@Model`
**Path:** `Models/AuditProgress.swift`

| Property | Type |
|---|---|
| `id` | `UUID` |
| `completedStepsData` | `Data?` (JSON `[String]`) |
| `currentStep` | `String` (`AuditStep.rawValue`) |
| `startedAt` | `Date` |
| `lastUpdatedAt` | `Date` |

**Relationship:** `home: Home?`
**Computed:** `completedSteps`, `currentStepEnum`, `progressPercentage`, `isComplete`
**Methods:** `isStepComplete(_:)`, `markComplete(_:)`
**Nested:** `AuditStep` enum — 10 cases: homeBasics, roomScanning, hvacEquipment, waterHeating, applianceInventory, lightingAudit, windowAssessment, envelopeAssessment, billUpload, review

---

### 2.7 WindowInfo.swift — Codable struct (not @Model)
**Path:** `Models/WindowInfo.swift`

Stored as JSON in `Room.windowsData`. Properties: `id`, `direction`, `size`, `paneType`, `frameMaterial`, `condition`.
Computed: `effectiveUFactor`, `heatGainBTU`
**Supporting enums:** `CardinalDirection` (4), `WindowSize` (3), `PaneType` (3), `FrameMaterial` (5), `WindowCondition` (3)

---

### 2.8-2.10 Supporting Enums

| File | Enum | Cases |
|---|---|---|
| `Models/ClimateZone.swift` | `ClimateZone` | hot, moderate, cold |
| `Models/InsulationQuality.swift` | `InsulationQuality` | poor, average, good |
| `Models/EquipmentType.swift` | `EquipmentType` | 11 cases (centralAC, heatPump, furnace, waterHeater, waterHeaterTankless, windowUnit, thermostat, insulation, windows, washer, dryer) |
| `Models/AgeRange.swift` | `AgeRange` | 5 cases (0-5yr through 20+yr) |

---

## 3. Services

### 3.1 EnergyCalculator.swift
**Path:** `Services/EnergyCalculator.swift`

| Method | Purpose |
|---|---|
| `calculate(squareFootage:ceilingHeight:climateZone:insulation:windows:)` | Room BTU/tonnage calculation |

Returns `BTUBreakdown` (baseBTU, windowHeatGain, insulationAdjustment, safetyBuffer, finalBTU, tonnage)

---

### 3.2 RoomCaptureService.swift
**Path:** `Services/RoomCaptureService.swift`

| Method | Purpose |
|---|---|
| `startSession()` | Start RoomPlan LiDAR capture + compass |
| `stopSession()` | Stop capture, trigger processing |
| `reset()` | Return to idle |
| `isLiDARAvailable` | Static check |
| `estimateFloorArea(from:)` | CapturedRoom → sq ft |
| `extractWindows(from:deviceHeading:)` | CapturedRoom → [WindowInfo] |

**Dependencies:** RoomPlan, ARKit, CoreLocation

---

### 3.3 OCRService.swift
**Path:** `Services/OCRService.swift`

| Method | Purpose |
|---|---|
| `recognizeText(from:)` | UIImage → OCRResult (manufacturer, model, efficiency, BTU) |
| `parseOCRText(_:)` | Raw text parsing (38 known brands, 10 efficiency patterns) |

**Dependencies:** Vision

---

### 3.4 EfficiencyDatabase.swift
**Path:** `Services/EfficiencyDatabase.swift`

| Method | Purpose |
|---|---|
| `lookup(type:age:)` | Equipment → EfficiencySpec (estimated/codeMin/bestInClass/upgradeCost) |
| `estimateAnnualCost(...)` | Equipment → annual $ cost |
| `estimateAnnualSavings(...)` | Current vs target efficiency → $ savings |
| `paybackYears(...)` | Upgrade cost / annual savings |

---

### 3.5 UpgradeEngine.swift
**Path:** `Services/UpgradeEngine.swift`

| Method | Purpose |
|---|---|
| `generateUpgrades(for:...)` | Equipment → Good/Better/Best upgrade tiers (11 types × 3 tiers) |
| `aggregateTaxCredits(from:)` | Sum 25C (cap $3,200) + 25D (30% uncapped) |

---

### 3.6 ApplianceClassificationService.swift
**Path:** `Services/ApplianceClassificationService.swift`

| Method | Purpose |
|---|---|
| `classify(image:topK:)` | UIImage → [ClassificationResult] via VNClassifyImageRequest |

Maps 30+ Vision identifiers to ApplianceCategory

---

### 3.7 LightingOCRService.swift
**Path:** `Services/LightingOCRService.swift`

| Method | Purpose |
|---|---|
| `recognizeBulb(from:)` | UIImage → BulbOCRResult (wattage, lumens, colorTemp, bulbType) |
| `parseBulbText(_:)` | Raw text → parsed bulb data |

---

### 3.8 BillParsingService.swift
**Path:** `Services/BillParsingService.swift`

| Method | Purpose |
|---|---|
| `parseBill(from:)` | UIImage → ParsedBillResult (kWh, cost, rate, dates, utility) |
| `parseBillText(_:)` | Raw text → parsed bill data (33 known utilities) |

---

### 3.9 GradingEngine.swift
**Path:** `Services/GradingEngine.swift`

| Method | Purpose |
|---|---|
| `grade(for: [Equipment])` | Equipment-only grade |
| `grade(for: Home)` | Composite grade: equipment 60% + appliances 20% + envelope 20% (adaptive weights) |
| `gradeFromRatio(_:)` | A: ≥0.85, B: ≥0.70, C: ≥0.55, D: ≥0.40, F: <0.40 |

---

### 3.10 RecommendationEngine.swift
**Path:** `Services/RecommendationEngine.swift`

| Method | Purpose |
|---|---|
| `generate(squareFootage:...)` | Room-level tips (low-e film, R-49, ceiling fans, duct sealing) |
| `generateHomeRecommendations(for:)` | Home-level tips (insulation, LED swap, smart strips, off-peak shifting) |

---

### 3.11 EnergyProfileService.swift
**Path:** `Services/EnergyProfileService.swift`

| Method | Purpose |
|---|---|
| `generateProfile(for:)` | Home → EnergyProfile (cost breakdown, top consumers, bill comparison) |
| `scoreEnvelope(for:)` | Home → EnvelopeScore (5 factors × 20 pts = 100 max, grade A-F) |

---

### 3.12 StateDetectionService.swift
**Path:** `Services/StateDetectionService.swift`

| Method | Purpose |
|---|---|
| `detectState()` | GPS → reverse geocode → USState |

ObservableObject (not static enum like others)

---

### 3.13 RebateDatabase.swift
**Path:** `Services/RebateDatabase.swift`

| Method | Purpose |
|---|---|
| `rebates(for: USState)` | All rebates for a state |
| `rebates(for:equipmentTypes:)` | Filtered by equipment type |

**Coverage:** 15 US states, ~60+ rebates. Also defines `USState` enum and `Rebate` struct.

---

### 3.14 RebateService.swift
**Path:** `Services/RebateService.swift`

| Method | Purpose |
|---|---|
| `matchRebates(for:state:)` | Home's equipment types → matching state rebates |

---

## 4. Views — Complete Inventory

### 4.1 OnboardingView
**Path:** `Views/Onboarding/OnboardingView.swift`

| Field | Detail |
|---|---|
| **Displays** | 3-page TabView with feature highlights |
| **Interactive** | Page dots, "Get Started" button (page 3 only) |
| **Reads** | `@AppStorage("hasSeenOnboarding")` |
| **Writes** | `hasSeenOnboarding = true` |
| **Nav out** | None (app root switches to HomeListView) |
| **Nav in** | App root when `!hasSeenOnboarding` |

---

### 4.2 HomeListView (+ HomeRowView, AddHomeSheet)
**Path:** `Views/HomeListView.swift`

| Field | Detail |
|---|---|
| **Displays** | NavigationStack: empty state or list of homes |
| **Interactive** | "+" toolbar, "Add Your Home" CTA, swipe-to-delete, delete confirmation |
| **Reads** | `@Query homes (sorted by updatedAt desc)`, `@Environment(\.modelContext)` |
| **Writes** | `modelContext.insert(home)`, `modelContext.delete(home)` |
| **Nav out** | `NavigationLink` → HomeDashboardView, `.sheet` → AddHomeSheet |
| **Nav in** | App root when `hasSeenOnboarding` |

**AddHomeSheet** (private, presented as .sheet):

| Field | Detail |
|---|---|
| **Displays** | Form: name, address, year built picker, sq ft, climate zone |
| **Interactive** | Cancel/Save toolbar, text fields, pickers |
| **Reads** | `@StateObject ClimateZoneDetector` (auto-detects from GPS) |
| **Writes** | Creates Home via `onSave` closure |

---

### 4.3 HomeDashboardView
**Path:** `Views/HomeDashboardView.swift`

| Field | Detail |
|---|---|
| **Displays** | ScrollView: audit banner, summary card, rooms, equipment, appliances, bills, report button |
| **Interactive** | See detailed list below |
| **Reads** | `@Bindable var home`, `@Environment(\.modelContext)` |
| **Writes** | `modelContext.delete` for rooms/equipment/appliances/bills |
| **State count** | 13+ @State booleans for sheets/nav |
| **Nav in** | NavigationLink from HomeListView |

**Interactive elements & navigation targets:**

| Section | Actions | Target |
|---|---|---|
| Audit banner | "Start/Continue Full Audit" button | `.sheet` → AuditFlowView |
| Rooms | Menu: "Scan Room (LiDAR)" / "Enter Manually" | `.sheet` → ScanView / DetailsView |
| Rooms | Tap existing room row | `NavigationLink` → ResultsView |
| Rooms | Swipe to delete | `modelContext.delete(room)` |
| Equipment | "+" button | `.sheet` → EquipmentDetailsView |
| Equipment | Tap existing equipment row | `NavigationLink` → EquipmentResultView |
| Equipment | Swipe to delete | `modelContext.delete(equipment)` |
| Appliances | Menu: "Scan with Camera" / "Scan Bulb Label" / "Enter Manually" | `.sheet` → ApplianceScanView / LightingCloseupView / ApplianceDetailsView |
| Appliances | Swipe to delete | `modelContext.delete(appliance)` |
| Bills | Menu: "Scan Bill" / "Enter Manually" | `.sheet` → BillUploadView / BillDetailsView |
| Bills | Tap existing bill row | `NavigationLink` → BillSummaryView |
| Bills | Swipe to delete | `modelContext.delete(bill)` |
| Report | "View Full Report" | `NavigationLink` → HomeReportView |

**Camera-to-details flow pattern (used 3 times):**
1. Present camera sheet
2. Camera captures + processes → callback with result
3. Dismiss camera sheet
4. `DispatchQueue.main.asyncAfter(0.3)` delay
5. Set prefill state variables
6. Present details sheet with prefilled data

---

### 4.4 ScanView
**Path:** `Views/RoomScan/ScanView.swift`

| Field | Detail |
|---|---|
| **Displays** | State machine: unavailable → idle → scanning (live camera) → processing → completed → failed |
| **Interactive** | "Start Scan", "Finish Scan", "Continue" (opens DetailsView), "Scan Again", "Cancel", "Enter Manually" |
| **Reads** | `@StateObject RoomCaptureService` |
| **Writes** | None persistent (passes scan data forward) |
| **Nav out** | `.sheet(item:)` → DetailsView (with scanned sq ft + windows) |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView |

---

### 4.5 DetailsView (+ WindowRowView, ClimateZoneDetector)
**Path:** `Views/RoomScan/DetailsView.swift`

| Field | Detail |
|---|---|
| **Displays** | Form: room name, floor area, ceiling height, windows list, climate zone, insulation |
| **Interactive** | TextFields, pickers, window add/delete, info button per window, "Calculate" toolbar |
| **Reads** | `@Environment(\.modelContext)`, `@StateObject ClimateZoneDetector` |
| **Writes** | Creates Room + EnergyCalculator results, inserts into modelContext, sets room.home, updates home.updatedAt |
| **Nav out** | `.navigationDestination` → ResultsView, `.sheet(item:)` → WindowQuestionnaireView |
| **Nav in** | Sheet from HomeDashboardView, ScanView, or AuditFlowView |

---

### 4.6 ResultsView (+ RecommendationCard)
**Path:** `Views/RoomScan/ResultsView.swift`

| Field | Detail |
|---|---|
| **Displays** | ScrollView: hero card (BTU/tonnage), breakdown card, recommendations |
| **Interactive** | "Done" toolbar, ShareLink (text report) |
| **Reads** | `let room: Room` (re-computes BTUBreakdown + recommendations) |
| **Writes** | None |
| **Nav out** | "Done" dismisses or calls onComplete |
| **Nav in** | NavigationDestination from DetailsView, NavigationLink from HomeDashboardView |

---

### 4.7 EquipmentCameraView (+ CameraService, CameraPreviewView)
**Path:** `Views/EquipmentScan/EquipmentCameraView.swift`

| Field | Detail |
|---|---|
| **Displays** | Full-screen camera with guide text + alignment box |
| **Interactive** | Capture button (circle), "Cancel", error alert |
| **Reads** | `@StateObject CameraService`, `let equipmentType` |
| **Writes** | None persistent; passes UIImage via `onCapture` closure |
| **Nav out** | Dismisses with image data |
| **Nav in** | Sheet from EquipmentDetailsView |

---

### 4.8 EquipmentDetailsView
**Path:** `Views/EquipmentScan/EquipmentDetailsView.swift`

| Field | Detail |
|---|---|
| **Displays** | Form: type picker, photo + OCR, manufacturer/model/efficiency fields, age picker, notes |
| **Interactive** | Type picker, "Photograph Equipment Label" button, TextFields, Age picker, Notes, Cancel/Save |
| **Reads** | `@Environment(\.modelContext)`, `let home` |
| **Writes** | Creates Equipment, sets equipment.home, modelContext.insert, updates home.updatedAt |
| **Nav out** | `.sheet` → EquipmentCameraView, `.navigationDestination` → EquipmentResultView |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView |

**OCR flow:** Camera capture → `OCRService.recognizeText` → auto-fills manufacturer, model, efficiency if blank

---

### 4.9 EquipmentResultView
**Path:** `Views/EquipmentScan/EquipmentResultView.swift`

| Field | Detail |
|---|---|
| **Displays** | ScrollView: hero card, efficiency comparison bar, upgrade tiers (Good/Better/Best) |
| **Interactive** | "Done" toolbar, DisclosureGroup for tech details per upgrade |
| **Reads** | `let equipment`, `let home` |
| **Writes** | None |
| **Nav out** | "Done" dismisses |
| **Nav in** | NavigationDestination from EquipmentDetailsView, NavigationLink from HomeDashboardView |

---

### 4.10 WindowQuestionnaireView
**Path:** `Views/WindowAssessment/WindowQuestionnaireView.swift`

| Field | Detail |
|---|---|
| **Displays** | 4-step TabView: pane type → frame material → condition → direction+size |
| **Interactive** | Selection cards, Back/Next, Cancel/Done toolbar |
| **Reads** | `@Binding var window: WindowInfo` |
| **Writes** | Mutates bound WindowInfo (direction, size, paneType, frameMaterial, condition) |
| **Nav out** | Dismiss |
| **Nav in** | Sheet from DetailsView (window info button) |

---

### 4.11 ApplianceScanView (+ ApplianceCameraService)
**Path:** `Views/ApplianceScan/ApplianceScanView.swift`

| Field | Detail |
|---|---|
| **Displays** | Camera with guide box, classification result chips |
| **Interactive** | Capture button, result chips (tappable), "Scan Again", "Cancel", "Enter Manually" |
| **Reads** | `@StateObject ApplianceCameraService` |
| **Writes** | None persistent; passes (ClassificationResult, UIImage) via `onClassified` |
| **Nav out** | Dismisses with classification data |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView |

---

### 4.12 LightingCloseupView (+ QuickWattageSelectView, BulbCameraService)
**Path:** `Views/ApplianceScan/LightingCloseupView.swift`

| Field | Detail |
|---|---|
| **Displays** | Camera with guide box, OCR results card (wattage/lumens/colorTemp/type) |
| **Interactive** | Capture, "Use This", "Retake", "Skip" (opens QuickWattageSelectView) |
| **Reads** | `@StateObject BulbCameraService` |
| **Writes** | None persistent; passes (BulbOCRResult, UIImage) via `onResult` |
| **Nav out** | Dismisses with OCR data |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView |

---

### 4.13 ApplianceDetailsView
**Path:** `Views/ApplianceScan/ApplianceDetailsView.swift`

| Field | Detail |
|---|---|
| **Displays** | Form: category picker (grouped), name, wattage, hours/day stepper, quantity, room assignment, energy preview |
| **Interactive** | Category picker, TextFields, Steppers, optional room picker, Cancel/Save |
| **Reads** | `@Environment(\.modelContext)`, `@Query rooms`, `let home` |
| **Writes** | Creates Appliance, sets home + optional room, modelContext.insert, updates home.updatedAt |
| **Nav out** | `.navigationDestination` → ApplianceResultView |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView (with optional prefill data) |

---

### 4.14 ApplianceResultView
**Path:** `Views/ApplianceScan/ApplianceResultView.swift`

| Field | Detail |
|---|---|
| **Displays** | ScrollView: hero card, energy breakdown (annual/monthly/daily), phantom load card, upgrade tips |
| **Interactive** | "Done" toolbar |
| **Reads** | `let appliance` |
| **Writes** | None |
| **Nav out** | "Done" dismisses |
| **Nav in** | NavigationDestination from ApplianceDetailsView |

---

### 4.15 BillUploadView (+ BillCameraService)
**Path:** `Views/BillScan/BillUploadView.swift`

| Field | Detail |
|---|---|
| **Displays** | Camera + PhotosPicker, parsed result card |
| **Interactive** | Capture, "Use This", "Retake", Menu: "Photo Library" / "Enter Manually", Cancel |
| **Reads** | `@StateObject BillCameraService` |
| **Writes** | None persistent; passes (ParsedBillResult, UIImage) via `onResult`, or calls `onManual` |
| **Nav out** | Dismisses with bill data |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView |

---

### 4.16 BillDetailsView
**Path:** `Views/BillScan/BillDetailsView.swift`

| Field | Detail |
|---|---|
| **Displays** | Form: utility name, billing period (DatePickers), kWh, cost, rate, computed stats |
| **Interactive** | TextFields, DatePickers, Cancel/Save |
| **Reads** | `@Environment(\.modelContext)`, `let home` |
| **Writes** | Creates EnergyBill, sets bill.home, modelContext.insert, updates home.updatedAt |
| **Nav out** | Calls onComplete, dismisses |
| **Nav in** | Sheet from HomeDashboardView or AuditFlowView (with optional prefill from OCR) |

---

### 4.17 BillSummaryView
**Path:** `Views/BillScan/BillSummaryView.swift`

| Field | Detail |
|---|---|
| **Displays** | ScrollView: header (kWh + cost), detail rows, bill photo thumbnail |
| **Interactive** | Photo tap → fullScreenCover (zoomed photo) |
| **Reads** | `@Bindable var bill` |
| **Writes** | None |
| **Nav out** | None (read-only detail view) |
| **Nav in** | NavigationLink from HomeDashboardView |

---

### 4.18 AuditFlowView
**Path:** `Views/AuditFlow/AuditFlowView.swift`

| Field | Detail |
|---|---|
| **Displays** | 10-step guided flow with progress bar, step-specific content, bottom navigation |
| **Interactive** | Progress bar (tappable steps), Back/Skip/Next/Done/Finish, per-step add/scan buttons |
| **Reads** | `@Bindable var home`, `@Environment(\.modelContext)` |
| **Writes** | Creates/manages AuditProgress, marks steps complete, modifies home properties |
| **Nav out** | Many sheets (see below), NavigationLink → HomeReportView |
| **Nav in** | Sheet from HomeDashboardView |

**10 Steps and their sub-navigation:**

| Step | Content | Sheet targets |
|---|---|---|
| 1. homeBasics | Name, address, year, sqft, climate fields | — |
| 2. roomScanning | Room list + add buttons | ScanView, DetailsView |
| 3. hvacEquipment | HVAC equipment list + add | EquipmentDetailsView (filtered: AC, heatPump, furnace) |
| 4. waterHeating | Water heater list + add | EquipmentDetailsView (filtered: waterHeater, tankless) |
| 5. applianceInventory | Appliance list + scan/add | ApplianceScanView, ApplianceDetailsView |
| 6. lightingAudit | Lighting list + scan/add | LightingCloseupView, ApplianceDetailsView |
| 7. windowAssessment | Room window counts, tap to edit | (inline edit or DetailsView) |
| 8. envelopeAssessment | Envelope assessment form | EnvelopeAssessmentView |
| 9. billUpload | Bill list + scan/add | BillUploadView, BillDetailsView |
| 10. review | Summary + report button | NavigationLink → HomeReportView |

---

### 4.19 AuditProgressBar
**Path:** `Views/AuditFlow/AuditProgressBar.swift`

| Field | Detail |
|---|---|
| **Displays** | Horizontal ScrollView of numbered step circles with connecting lines |
| **Interactive** | Tappable step circles |
| **Reads** | `completedSteps: Set<AuditStep>`, `currentStep: AuditStep` |
| **Writes** | None (calls `onStepTapped` callback) |
| **Nav** | Component only — embedded in AuditFlowView |

---

### 4.20 EnvelopeAssessmentView
**Path:** `Views/AuditFlow/EnvelopeAssessmentView.swift`

| Field | Detail |
|---|---|
| **Displays** | 3-step TabView: insulation → foundation+sealing → summary+notes |
| **Interactive** | Selection cards, Back/Next, "Save" button, notes TextField |
| **Reads** | `@Bindable var home` |
| **Writes** | `home.envelope = EnvelopeInfo(...)` on save |
| **Nav out** | Dismiss on save |
| **Nav in** | Sheet from AuditFlowView |

---

### 4.21 HomeReportView
**Path:** `Views/Report/HomeReportView.swift`
**Size:** ~1,060 lines (largest view)

| Field | Detail |
|---|---|
| **Displays** | ScrollView with 12+ sections (see below) |
| **Interactive** | DisclosureGroups for upgrades, Links for rebate URLs, ShareLink |
| **Reads** | `@Bindable var home`, `@StateObject StateDetectionService` |
| **Writes** | None |
| **Nav out** | External URLs (rebate links) |
| **Nav in** | NavigationLink from HomeDashboardView or AuditFlowView |

**Report sections:**
1. Summary — overall A-F grade badge
2. Cost — estimated annual/monthly cost, electricity rate
3. Energy Profile — stacked bar (HVAC/Water/Appliances/Lighting/Standby %), top 5 consumers
4. Bill Reconciliation — bill-based vs estimated kWh, accuracy label
5. Appliance Highlights — total kWh/cost, phantom stats, top 3 appliances
6. Envelope Summary — score/grade, breakdown, weakest area
7. Upgrade Stats — aggregate savings, cost range, average payback, total tax credits
8. Upgrades — per-equipment Good/Better/Best tiers with DisclosureGroups
9. Quick Wins — home-level recommendations
10. Tax Credits — 25C (capped $3,200) + 25D (30% uncapped)
11. Rebates — location-based, with program links
12. Battery Synergy — contextual note
13. Share — ShareLink generating comprehensive text report

**Services consumed:** GradingEngine, EnergyProfileService, UpgradeEngine, RecommendationEngine, RebateService, StateDetectionService

---

### 4.22 ReportPDFGenerator
**Path:** `Views/Report/ReportPDFGenerator.swift`

| Field | Detail |
|---|---|
| **Purpose** | Renders HomeReportView to PDF via ImageRenderer |
| **Methods** | `generatePDF(for:) -> Data?`, `savePDF(for:) -> URL?` |
| **Nav** | N/A (utility, not a view) |

---

## 5. Navigation Sitemap

```
DezenitApp
│
├── [conditional] OnboardingView
│   └── "Get Started" → sets hasSeenOnboarding=true → app switches to HomeListView
│
└── [conditional] HomeListView ─────────────────────── NavigationStack root
    │
    ├── [sheet] AddHomeSheet
    │   └── "Save" → creates Home → dismisses
    │
    └── [NavigationLink per home] HomeDashboardView
        │
        ├── AUDIT FLOW
        │   └── [sheet] AuditFlowView (10 steps)
        │       ├── Step 1: homeBasics (inline form)
        │       ├── Step 2: roomScanning
        │       │   ├── [sheet] ScanView → [sheet] DetailsView → [navDest] ResultsView
        │       │   └── [sheet] DetailsView (manual) → [navDest] ResultsView
        │       ├── Step 3: hvacEquipment
        │       │   └── [sheet] EquipmentDetailsView → [navDest] EquipmentResultView
        │       ├── Step 4: waterHeating
        │       │   └── [sheet] EquipmentDetailsView → [navDest] EquipmentResultView
        │       ├── Step 5: applianceInventory
        │       │   ├── [sheet] ApplianceScanView → [sheet] ApplianceDetailsView → [navDest] ApplianceResultView
        │       │   └── [sheet] ApplianceDetailsView (manual) → [navDest] ApplianceResultView
        │       ├── Step 6: lightingAudit
        │       │   ├── [sheet] LightingCloseupView → [sheet] ApplianceDetailsView → [navDest] ApplianceResultView
        │       │   └── [sheet] ApplianceDetailsView (manual) → [navDest] ApplianceResultView
        │       ├── Step 7: windowAssessment (inline)
        │       ├── Step 8: envelopeAssessment
        │       │   └── [sheet] EnvelopeAssessmentView
        │       ├── Step 9: billUpload
        │       │   ├── [sheet] BillUploadView → [sheet] BillDetailsView
        │       │   └── [sheet] BillDetailsView (manual)
        │       └── Step 10: review
        │           └── [NavigationLink] HomeReportView
        │
        ├── ROOMS (free-form)
        │   ├── [sheet] ScanView (LiDAR)
        │   │   └── [sheet] DetailsView (prefilled) → [navDest] ResultsView
        │   ├── [sheet] DetailsView (manual) → [navDest] ResultsView
        │   └── [NavigationLink per room] ResultsView
        │
        ├── EQUIPMENT (free-form)
        │   ├── [sheet] EquipmentDetailsView
        │   │   ├── [sheet] EquipmentCameraView (OCR)
        │   │   └── [navDest] EquipmentResultView
        │   └── [NavigationLink per equipment] EquipmentResultView
        │
        ├── APPLIANCES (free-form)
        │   ├── [sheet] ApplianceScanView (camera classify)
        │   │   └── callback → [sheet] ApplianceDetailsView → [navDest] ApplianceResultView
        │   ├── [sheet] LightingCloseupView (bulb OCR)
        │   │   └── callback → [sheet] ApplianceDetailsView → [navDest] ApplianceResultView
        │   └── [sheet] ApplianceDetailsView (manual) → [navDest] ApplianceResultView
        │
        ├── BILLS (free-form)
        │   ├── [sheet] BillUploadView (camera/photo OCR)
        │   │   └── callback → [sheet] BillDetailsView (prefilled)
        │   ├── [sheet] BillDetailsView (manual)
        │   └── [NavigationLink per bill] BillSummaryView
        │
        └── REPORT
            └── [NavigationLink] HomeReportView
                └── [external links] Rebate program URLs

Sub-view sheets (used within DetailsView):
    └── [sheet] WindowQuestionnaireView (4-step window assessment)
```

---

## 6. Data Flow Architecture

### SwiftData Model Graph

```
Home (root aggregate)
├── rooms: [Room] ──── cascade delete
│   └── appliances: [Appliance] ──── cascade delete
├── equipment: [Equipment] ──── cascade delete
├── appliances: [Appliance] ──── cascade delete  ← NOTE: appliances link to BOTH home and room
├── energyBills: [EnergyBill] ──── cascade delete
└── auditProgress: [AuditProgress] ──── cascade delete
```

### Data Creation Points

| Data | Created by | Trigger |
|---|---|---|
| Home | AddHomeSheet | "Save" button |
| Room | DetailsView | "Calculate" button |
| Equipment | EquipmentDetailsView | "Save" button |
| Appliance | ApplianceDetailsView | "Save" button |
| EnergyBill | BillDetailsView | "Save" button |
| AuditProgress | AuditFlowView | On appear (lazy create) |
| EnvelopeInfo | EnvelopeAssessmentView | "Save" button |

### Data Deletion Points

| Data | Deleted by | Trigger |
|---|---|---|
| Home | HomeListView | Swipe-to-delete + confirmation dialog |
| Room | HomeDashboardView | Swipe-to-delete |
| Equipment | HomeDashboardView | Swipe-to-delete |
| Appliance | HomeDashboardView | Swipe-to-delete |
| EnergyBill | HomeDashboardView | Swipe-to-delete |

### Camera → Data Pipeline

```
EquipmentCameraView → UIImage → OCRService.recognizeText() → OCRResult
    → prefills EquipmentDetailsView (manufacturer, model, efficiency)

ApplianceScanView → UIImage → ApplianceClassificationService.classify() → ClassificationResult
    → prefills ApplianceDetailsView (category, image)

LightingCloseupView → UIImage → LightingOCRService.recognizeBulb() → BulbOCRResult
    → prefills ApplianceDetailsView (wattage, category=lighting, image)

BillUploadView → UIImage → BillParsingService.parseBill() → ParsedBillResult
    → prefills BillDetailsView (kWh, cost, rate, dates, utility)
```

### Computation Pipeline (read-only, no persistence)

```
Room data ──→ EnergyCalculator.calculate() ──→ BTUBreakdown (displayed in ResultsView)
Room data ──→ RecommendationEngine.generate() ──→ [Recommendation] (displayed in ResultsView)

Equipment[] ──→ GradingEngine.grade() ──→ EfficiencyGrade
Equipment ──→ EfficiencyDatabase.lookup() ──→ EfficiencySpec
Equipment ──→ UpgradeEngine.generateUpgrades() ──→ [UpgradeRecommendation]

Home (all data) ──→ GradingEngine.grade() ──→ EfficiencyGrade (composite)
Home (all data) ──→ EnergyProfileService.generateProfile() ──→ EnergyProfile
Home (all data) ──→ RecommendationEngine.generateHomeRecommendations() ──→ [Recommendation]
Home (all data) ──→ UpgradeEngine (per equipment) ──→ [UpgradeRecommendation]
Home + USState ──→ RebateService.matchRebates() ──→ [Rebate]

Home.envelope ──→ EnergyProfileService.scoreEnvelope() ──→ EnvelopeScore
```

---

## 7. State Management Inventory

### Persistent State

| Key | Storage | Read by | Written by |
|---|---|---|---|
| `hasSeenOnboarding` | `@AppStorage` | DezenitApp, OnboardingView | OnboardingView |
| All SwiftData models | SwiftData (SQLite) | Multiple views via @Query/@Bindable | Detail/form views via modelContext |

### @StateObject (ObservableObject instances)

| Object | Created in | Purpose |
|---|---|---|
| `RoomCaptureService` | ScanView | LiDAR room scanning |
| `CameraService` | EquipmentCameraView | Equipment label photo |
| `ApplianceCameraService` | ApplianceScanView | Appliance photo |
| `BulbCameraService` | LightingCloseupView | Bulb label photo |
| `BillCameraService` | BillUploadView | Bill photo |
| `StateDetectionService` | HomeReportView | GPS → US state for rebates |
| `ClimateZoneDetector` | DetailsView, AddHomeSheet | GPS → climate zone |

### @State Variables (notable counts per view)

| View | @State count | Notable |
|---|---|---|
| HomeDashboardView | 13+ | All sheet presentation booleans + prefill states |
| AuditFlowView | 10+ | Step state + all sub-flow sheet booleans + prefill states |
| DetailsView | 9 | Room form fields + navigation + window questionnaire index |
| EquipmentDetailsView | 10 | Form fields + OCR state + camera + navigation |
| ApplianceDetailsView | 6 | Form fields + room selection |
| BillDetailsView | 7 | Form fields |

---

## 8. Reachability Analysis

### All Views — Reachability Status

| View | Reachable? | Entry points |
|---|---|---|
| OnboardingView | ✅ | App root (first launch) |
| HomeListView | ✅ | App root (after onboarding) |
| AddHomeSheet | ✅ | HomeListView "+" / "Add Your Home" |
| HomeDashboardView | ✅ | HomeListView NavigationLink |
| ScanView | ✅ | HomeDashboardView, AuditFlowView |
| DetailsView | ✅ | HomeDashboardView, ScanView, AuditFlowView |
| ResultsView | ✅ | DetailsView navDest, HomeDashboardView NavLink |
| EquipmentCameraView | ✅ | EquipmentDetailsView sheet |
| EquipmentDetailsView | ✅ | HomeDashboardView, AuditFlowView |
| EquipmentResultView | ✅ | EquipmentDetailsView navDest, HomeDashboardView NavLink |
| WindowQuestionnaireView | ✅ | DetailsView sheet (window info button) |
| ApplianceScanView | ✅ | HomeDashboardView, AuditFlowView |
| LightingCloseupView | ✅ | HomeDashboardView, AuditFlowView |
| ApplianceDetailsView | ✅ | HomeDashboardView, AuditFlowView, ApplianceScanView callback, LightingCloseupView callback |
| ApplianceResultView | ✅ | ApplianceDetailsView navDest |
| BillUploadView | ✅ | HomeDashboardView, AuditFlowView |
| BillDetailsView | ✅ | HomeDashboardView, AuditFlowView, BillUploadView callback |
| BillSummaryView | ✅ | HomeDashboardView NavLink |
| AuditFlowView | ✅ | HomeDashboardView sheet |
| AuditProgressBar | ✅ | Component within AuditFlowView |
| EnvelopeAssessmentView | ✅ | AuditFlowView sheet |
| HomeReportView | ✅ | HomeDashboardView NavLink, AuditFlowView NavLink |
| ReportPDFGenerator | ✅ | Utility (called programmatically, not a screen) |

### Orphaned Views: **NONE**

All 22 view files are reachable through the navigation graph.

---

## Summary Statistics

| Category | Count |
|---|---|
| Total Swift files | 49 |
| Screens/pages | 18 distinct screens |
| Modal sheets | 12 sheet presentations |
| Camera views | 4 (Equipment, Appliance, Lighting, Bill) |
| SwiftData models | 6 (@Model classes) |
| Supporting models | 5 (enums + Codable structs) |
| Services | 14 |
| Navigation depth (max) | 4 levels (HomeList → Dashboard → Camera → Details → Result) |
| @AppStorage keys | 1 (`hasSeenOnboarding`) |
| Unique interactive flows | 5 (Room scan, Equipment scan, Appliance scan, Lighting scan, Bill scan) |

---

*Phase 1 Discovery complete. No changes made. Ready for Phase 2.*
