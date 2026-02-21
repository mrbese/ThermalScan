# Dezenit

**Open-source iOS home energy assessment tool. Scan rooms with LiDAR, photograph equipment for OCR efficiency analysis, get prioritized upgrade recommendations with payback periods and battery synergy insights. Built on ACCA Manual J and ASHRAE standards.**

[dezenit.com](https://dezenit.com)

---

## What It Does

Dezenit turns your iPhone into a residential energy auditor. Walk through your home, scan each room with LiDAR, photograph your HVAC equipment labels, and get a comprehensive efficiency report with prioritized upgrades ranked by return on investment.

### Room Scanning
- Apple RoomPlan API detects floor area via LiDAR
- Configure windows (count, direction, size), ceiling height, insulation quality
- ACCA Manual J simplified BTU load calculation
- Manual input fallback for non-LiDAR devices

### Equipment Assessment
- Photograph equipment rating plates (AC units, furnaces, water heaters, windows)
- On-device OCR extracts model numbers and efficiency ratings via Apple Vision
- Age-based efficiency estimation when labels are unreadable
- Compares current efficiency against code minimums and best-in-class

### Home Energy Report
- Overall efficiency grade (A through F)
- Estimated annual energy costs
- Prioritized upgrade list sorted by payback period
- Battery synergy analysis: how much additional export capacity efficiency upgrades unlock for home battery systems (Pila Energy, Tesla Powerwall, Base Power, Enphase)

---

## The Battery Synergy Thesis

An inefficient building envelope directly cannibalizes the value of home battery systems. A poorly insulated home draws 5-6 kW on a summer afternoon, leaving a battery inverter exporting barely half its rated output during peak grid events when electricity prices spike to $2,000-$5,000/MWh.

Dezenit quantifies this: for each home, it calculates how much additional battery export capacity passive efficiency upgrades would unlock. Upgrading attic insulation to R-49 and sealing ducts to <4% leakage can liberate 1.5-2 kW of additional export capacity from the same battery hardware, translating to 30-40% more grid revenue with zero additional battery cost.

This insight is based on ASHRAE standards, ACCA Manual J methodology, and field audit data from LADWP Commercial Lighting Incentive Program (CLIP) assessments.

---

## BTU Calculation Methodology

Based on ACCA Manual J simplified method.

| Parameter | Values |
|---|---|
| Climate factors | Hot: 30 BTU/sq ft, Moderate: 25, Cold: 35 |
| Ceiling height | 8ft: 1.0x, 9ft: 1.12x, 10ft: 1.25x, 12ft: 1.5x |
| Window solar gain | South: 150 BTU/sq ft, West: 120, East: 100, North: 40 |
| Insulation adjustment | Poor: +30%, Average: baseline, Good: -15% |
| Safety factor | 1.10 (10% ACCA standard) |

References: [ACCA Manual J](https://www.acca.org/bookstore/product/manual-j-residential-load-calculation-8th-edition), ASHRAE Handbook of Fundamentals, DOE 2023 efficiency standards.

---

## Equipment Efficiency Benchmarks

| Equipment | 20+ yr old | Current Code Min | Best in Class |
|---|---|---|---|
| Central AC | SEER 9 | SEER2 15.2 | SEER 24 |
| Heat Pump | SEER 9 / HSPF 6.5 | SEER2 15.2 / HSPF2 7.8 | SEER 25+ / HSPF 13+ |
| Furnace | 65% AFUE | 80-90% AFUE | 98.5% AFUE |
| Water Heater (tank) | UEF 0.50 | UEF 0.64 | HPWH UEF 3.5+ |
| Windows (single pane) | U-factor 1.1 | U-factor 0.30 | U-factor 0.15 |

---

## Requirements

- iPhone 12 Pro or later (LiDAR for room scanning)
- Manual input mode works on all iPhones
- iOS 17.0+
- No external dependencies. Apple frameworks only (RoomPlan, ARKit, Vision, SwiftData, CoreLocation, AVFoundation)
- No network calls. Everything runs on-device.

---

## Tech Stack

Swift, SwiftUI, SwiftData, RoomPlan, ARKit, AVFoundation, Vision (OCR), CoreLocation, PDFKit

---

## Project Structure

```
Dezenit/
  Dezenit/
    App/
      DezenitApp.swift
    Models/
      Home.swift                    SwiftData model, contains rooms + equipment
      Room.swift                    Room model, linked to Home
      Equipment.swift               Equipment model with efficiency data
      EquipmentType.swift           Enum: AC, heat pump, furnace, water heater, etc.
      AgeRange.swift                Enum: 0-5, 5-10, 10-15, 15-20, 20+ years
      WindowInfo.swift              Window direction + size
      ClimateZone.swift             Hot / Moderate / Cold
      InsulationQuality.swift       Poor / Average / Good
    Views/
      HomeListView.swift            List of homes
      HomeDashboardView.swift       Single home overview
      RoomScan/
        ScanView.swift              RoomPlan capture flow
        DetailsView.swift           Room configuration form
        ResultsView.swift           BTU results + recommendations
      EquipmentScan/
        EquipmentCameraView.swift   Camera + OCR capture
        EquipmentDetailsView.swift  Manual/OCR entry form
        EquipmentResultView.swift   Single equipment analysis
      Report/
        HomeReportView.swift        Full home assessment report
        ReportPDFGenerator.swift    PDF export
    Services/
      EnergyCalculator.swift        BTU calculation engine
      RecommendationEngine.swift    Context-aware efficiency tips
      RoomCaptureService.swift      RoomPlan + ARKit wrapper
      EfficiencyDatabase.swift      Equipment lookup tables
      GradingEngine.swift           A-F weighted efficiency grading
      OCRService.swift              Apple Vision text recognition
    Utils/
      Constants.swift               Colors, calculation constants, rates
```

---

## License

MIT License

---

Built by [Omer Bese](https://linkedin.com/in/omerbese) | Energy Systems Engineer | Columbia University MS Sustainability Management

Methodology informed by professional energy audit experience with the LADWP CLIP program, ASHRAE standards, and DOE residential efficiency guidelines.
