# ThermalScan

**Open-source iOS tool for quick residential HVAC load estimation using Apple's RoomPlan spatial computing.**

Scan a room in under 60 seconds. Get BTU requirements, recommended HVAC tonnage, and actionable energy efficiency tips — all calculated on-device with no network calls.

---

## How It Works

1. **Scan** — Walk your iPhone around a room. Apple's RoomPlan API uses LiDAR to detect floor area in real time. No LiDAR? Enter square footage manually.
2. **Configure** — Tag windows (count, direction, size), set ceiling height, climate zone, and insulation quality.
3. **Calculate** — The app runs ACCA Manual J simplified load calculations locally and shows your BTU requirement, tonnage, and a breakdown.
4. **Review** — Get 3–5 energy efficiency recommendations tailored to your specific inputs.
5. **Save & Share** — Results are persisted with SwiftData. Generate a plain-text summary to share with an HVAC contractor.

---

## BTU Calculation Methodology

Based on ACCA Manual J simplified method.

```
Base BTU = sq_ft × ceiling_height_factor × climate_factor

Ceiling height factors:
  8 ft  = 1.00
  9 ft  = 1.12
  10 ft = 1.25
  12 ft = 1.50

Climate factors (BTU/sq ft):
  Hot      = 30  (Desert Southwest, Gulf Coast, Florida)
  Moderate = 25  (Mid-Atlantic, Pacific Coast, Midwest)
  Cold     = 35  (Northern US, Mountain West, New England)

Window solar heat gain (BTU/sq ft of glass):
  South-facing = 150  (peak summer gain)
  West-facing  = 120
  East-facing  = 100
  North-facing =  40

Window sizes:
  Small  = 10 sq ft
  Medium = 20 sq ft
  Large  = 35 sq ft

Insulation multipliers:
  Poor    = 1.30  (+30% load penalty)
  Average = 1.00  (baseline)
  Good    = 0.85  (-15% load credit)

Safety factor = 1.10 (10% buffer — ACCA industry standard)

Final BTU = (Base BTU + Window Heat Gain) × Insulation Multiplier × 1.10
HVAC Tonnage = Final BTU / 12,000
```

References: [ACCA Manual J](https://www.acca.org/bookstore/product/manual-j-residential-load-calculation-8th-edition), ASHRAE Handbook of Fundamentals.

---

## Requirements

- iPhone 12 Pro or later (LiDAR required for room scanning)
- All iPhone 13 Pro, 14 Pro, 15 models support scanning
- Manual input mode works on all iPhones
- iOS 17.0+
- No external dependencies — Apple frameworks only (RoomPlan, ARKit, SwiftData, CoreLocation)

---

## Screenshots

> _Coming soon_

---

## Project Structure

```
ThermalScan/
  ThermalScan/
    App/
      ThermalScanApp.swift        Entry point, SwiftData container
    Models/
      Room.swift                  SwiftData model + CeilingHeightOption enum
      WindowInfo.swift            Window direction + size model
      ClimateZone.swift           Hot / Moderate / Cold
      InsulationQuality.swift     Poor / Average / Good
    Views/
      HomeView.swift              Room list + entry points
      ScanView.swift              RoomPlan capture flow
      DetailsView.swift           Room configuration form
      ResultsView.swift           BTU results + recommendations
    Services/
      EnergyCalculator.swift      BTU calculation engine
      RecommendationEngine.swift  Context-aware efficiency tips
      RoomCaptureService.swift    RoomPlan + ARKit wrapper
    Utils/
      Constants.swift             Accent color + all calculation constants
```

---

## License

MIT License — free to use, modify, and distribute.

---

Built by [Omer Bese](https://omerbese.com) | Energy Systems Engineer | Columbia University MS Sustainability Management
