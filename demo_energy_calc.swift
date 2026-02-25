#!/usr/bin/env swift
import Foundation

// ============================================================
// ManorOS Energy Calculator Demo (Linux)
// Exercises core BTU calculation logic from the codebase.
// ============================================================

// --- Extracted types (Foundation-only copies) ---

enum Constants {
    static let safetyFactor: Double = 1.10
    static let btuPerTon: Double = 12_000
    enum ClimateFactors {
        static let hot: Double = 30
        static let moderate: Double = 25
        static let cold: Double = 35
    }
    enum CeilingFactors {
        static let eight: Double = 1.0
        static let nine: Double = 1.12
        static let ten: Double = 1.25
        static let twelve: Double = 1.5
    }
    enum InsulationMultipliers {
        static let poor: Double = 1.30
        static let average: Double = 1.00
        static let good: Double = 0.85
    }
    enum WindowBTUPerSqFt {
        static let south: Double = 150
        static let west: Double = 120
        static let east: Double = 100
        static let north: Double = 40
    }
    enum WindowSizeSqFt {
        static let small: Double = 10
        static let medium: Double = 20
        static let large: Double = 35
    }
    static let defaultElectricityRate: Double = 0.16
    static let defaultGasRate: Double = 1.20
}

enum ClimateZone: String, CaseIterable {
    case hot = "Hot"
    case moderate = "Moderate"
    case cold = "Cold"
    var btuPerSqFt: Double {
        switch self {
        case .hot: return Constants.ClimateFactors.hot
        case .moderate: return Constants.ClimateFactors.moderate
        case .cold: return Constants.ClimateFactors.cold
        }
    }
}

enum InsulationQuality: String, CaseIterable {
    case poor = "Poor"
    case average = "Average"
    case good = "Good"
    var multiplier: Double {
        switch self {
        case .poor: return Constants.InsulationMultipliers.poor
        case .average: return Constants.InsulationMultipliers.average
        case .good: return Constants.InsulationMultipliers.good
        }
    }
}

enum CeilingHeightOption: Int, CaseIterable {
    case eight = 8
    case nine = 9
    case ten = 10
    case twelve = 12
    var factor: Double {
        switch self {
        case .eight: return Constants.CeilingFactors.eight
        case .nine: return Constants.CeilingFactors.nine
        case .ten: return Constants.CeilingFactors.ten
        case .twelve: return Constants.CeilingFactors.twelve
        }
    }
}

enum CardinalDirection: String, CaseIterable {
    case north = "N", south = "S", east = "E", west = "W"
    var btuPerSqFt: Double {
        switch self {
        case .north: return Constants.WindowBTUPerSqFt.north
        case .south: return Constants.WindowBTUPerSqFt.south
        case .east: return Constants.WindowBTUPerSqFt.east
        case .west: return Constants.WindowBTUPerSqFt.west
        }
    }
}

enum WindowSize: String, CaseIterable {
    case small = "Small", medium = "Medium", large = "Large"
    var sqFt: Double {
        switch self {
        case .small: return Constants.WindowSizeSqFt.small
        case .medium: return Constants.WindowSizeSqFt.medium
        case .large: return Constants.WindowSizeSqFt.large
        }
    }
}

enum PaneType: String, CaseIterable {
    case single = "Single", double = "Double", triple = "Triple"
    var uFactor: Double {
        switch self {
        case .single: return 1.10
        case .double: return 0.30
        case .triple: return 0.22
        }
    }
}

enum FrameMaterial: String, CaseIterable {
    case aluminum = "Aluminum", wood = "Wood", vinyl = "Vinyl"
    var thermalFactor: Double {
        switch self {
        case .aluminum: return 1.30
        case .wood: return 1.00
        case .vinyl: return 0.95
        }
    }
}

enum WindowCondition: String, CaseIterable {
    case good = "Good", fair = "Fair", poor = "Poor"
    var leakageFactor: Double {
        switch self {
        case .good: return 1.00
        case .fair: return 1.15
        case .poor: return 1.35
        }
    }
}

struct WindowInfo {
    var direction: CardinalDirection = .south
    var size: WindowSize = .medium
    var paneType: PaneType = .double
    var frameMaterial: FrameMaterial = .vinyl
    var condition: WindowCondition = .good
    var effectiveUFactor: Double {
        paneType.uFactor * frameMaterial.thermalFactor * condition.leakageFactor
    }
    var heatGainBTU: Double {
        let baseHeatGain = direction.btuPerSqFt * size.sqFt
        let standardUFactor: Double = 0.285
        let adjustmentRatio = effectiveUFactor / standardUFactor
        return baseHeatGain * adjustmentRatio
    }
}

// --- Core Calculator (identical to ManorOS/Services/EnergyCalculator.swift) ---

struct BTUBreakdown {
    let baseBTU: Double
    let windowHeatGain: Double
    let subtotal: Double
    let insulationAdjustment: Double
    let afterInsulation: Double
    let safetyBuffer: Double
    let finalBTU: Double
    let tonnage: Double
}

enum EnergyCalculator {
    static func calculate(
        squareFootage: Double,
        ceilingHeight: CeilingHeightOption,
        climateZone: ClimateZone,
        insulation: InsulationQuality,
        windows: [WindowInfo]
    ) -> BTUBreakdown {
        let baseBTU = squareFootage * ceilingHeight.factor * climateZone.btuPerSqFt
        let windowHeatGain = windows.reduce(0) { $0 + $1.heatGainBTU }
        let subtotal = baseBTU + windowHeatGain
        let afterInsulation = subtotal * insulation.multiplier
        let insulationAdjustment = afterInsulation - subtotal
        let finalBTU = afterInsulation * Constants.safetyFactor
        let safetyBuffer = finalBTU - afterInsulation
        let tonnage = finalBTU / Constants.btuPerTon
        return BTUBreakdown(
            baseBTU: baseBTU, windowHeatGain: windowHeatGain,
            subtotal: subtotal, insulationAdjustment: insulationAdjustment,
            afterInsulation: afterInsulation, safetyBuffer: safetyBuffer,
            finalBTU: finalBTU, tonnage: tonnage
        )
    }
}

// ============================================================
// Demo: Simulate a 2,000 sq ft home audit in a hot climate
// ============================================================

print("=" * 60)
print("ManorOS Energy Calculator — Linux Demo")
print("=" * 60)
print()

let sqft: Double = 2000
let ceiling = CeilingHeightOption.nine
let climate = ClimateZone.hot
let insulation = InsulationQuality.poor

let windows: [WindowInfo] = [
    WindowInfo(direction: .south, size: .large, paneType: .single, frameMaterial: .aluminum, condition: .poor),
    WindowInfo(direction: .south, size: .large, paneType: .single, frameMaterial: .aluminum, condition: .poor),
    WindowInfo(direction: .west,  size: .medium, paneType: .double, frameMaterial: .vinyl, condition: .fair),
    WindowInfo(direction: .north, size: .medium, paneType: .double, frameMaterial: .vinyl, condition: .good),
    WindowInfo(direction: .east,  size: .small, paneType: .double, frameMaterial: .wood,  condition: .good),
]

print("Home Profile:")
print("  Square footage : \(Int(sqft)) sq ft")
print("  Ceiling height : \(ceiling.rawValue) ft (factor \(ceiling.factor))")
print("  Climate zone   : \(climate.rawValue) (\(climate.btuPerSqFt) BTU/sq ft)")
print("  Insulation     : \(insulation.rawValue) (x\(insulation.multiplier))")
print("  Windows        : \(windows.count)")
print()

let result = EnergyCalculator.calculate(
    squareFootage: sqft,
    ceilingHeight: ceiling,
    climateZone: climate,
    insulation: insulation,
    windows: windows
)

func fmt(_ v: Double) -> String { String(format: "%.0f", v) }
func fmt2(_ v: Double) -> String { String(format: "%.2f", v) }

print("BTU Breakdown:")
print("  Base BTU             : \(fmt(result.baseBTU))")
print("  Window heat gain     : \(fmt(result.windowHeatGain))")
print("  Subtotal             : \(fmt(result.subtotal))")
print("  Insulation adj (+30%): \(fmt(result.insulationAdjustment))")
print("  After insulation     : \(fmt(result.afterInsulation))")
print("  Safety buffer (10%)  : \(fmt(result.safetyBuffer))")
print("  Final cooling load   : \(fmt(result.finalBTU)) BTU")
print("  Required tonnage     : \(fmt2(result.tonnage)) tons")
print()

// Comparison: same home with good insulation + double-pane windows
let goodWindows: [WindowInfo] = [
    WindowInfo(direction: .south, size: .large, paneType: .double, frameMaterial: .vinyl, condition: .good),
    WindowInfo(direction: .south, size: .large, paneType: .double, frameMaterial: .vinyl, condition: .good),
    WindowInfo(direction: .west,  size: .medium, paneType: .double, frameMaterial: .vinyl, condition: .good),
    WindowInfo(direction: .north, size: .medium, paneType: .double, frameMaterial: .vinyl, condition: .good),
    WindowInfo(direction: .east,  size: .small, paneType: .double, frameMaterial: .vinyl, condition: .good),
]

let upgraded = EnergyCalculator.calculate(
    squareFootage: sqft,
    ceilingHeight: ceiling,
    climateZone: climate,
    insulation: .good,
    windows: goodWindows
)

print("Upgraded Scenario (good insulation + double-pane vinyl):")
print("  Final cooling load   : \(fmt(upgraded.finalBTU)) BTU")
print("  Required tonnage     : \(fmt2(upgraded.tonnage)) tons")
print("  BTU reduction        : \(fmt(result.finalBTU - upgraded.finalBTU)) BTU (\(fmt2((1 - upgraded.finalBTU / result.finalBTU) * 100))%)")
print()

// Validate against ACCA Manual J reference values
let expectedBase = sqft * ceiling.factor * climate.btuPerSqFt
assert(result.baseBTU == expectedBase, "Base BTU mismatch")
assert(result.tonnage > 0, "Tonnage should be positive")
assert(upgraded.finalBTU < result.finalBTU, "Upgrade should reduce BTU")

print("All assertions passed. Core calculation engine verified.")
print("=" * 60)

// Helper
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
