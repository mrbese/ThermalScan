import SwiftUI
import UIKit

enum Constants {
    static let accentColor = Color(red: 0.102, green: 0.478, blue: 0.298) // #1A7A4C emerald green
    static let secondaryColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.831, green: 0.831, blue: 0.847, alpha: 1) // #D4D4D8
            : UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1) // #1A1A1A
    })
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

    // Default energy rates
    static let defaultElectricityRate: Double = 0.16 // $/kWh
    static let defaultGasRate: Double = 1.20 // $/therm

    // MARK: - Appliance Wattage Defaults

    /// Common bulb wattages for quick-select in lighting audit
    enum CommonBulbWattages {
        static let led: [Double] = [5, 7, 9, 12, 15, 18]
        static let cfl: [Double] = [9, 13, 18, 23, 26]
        static let incandescent: [Double] = [40, 60, 75, 100, 150]
    }

    // MARK: - Semantic Colors

    static func gradeColor(_ grade: EfficiencyGrade) -> Color {
        switch grade {
        case .a: return .green
        case .b: return .blue
        case .c: return .yellow
        case .d: return .orange
        case .f: return .red
        }
    }

    static let statusSuccess = Color.green
    static let statusWarning = Color.orange

    /// Phantom load (standby) values for common device categories
    enum PhantomLoads {
        static let entertainmentCenter: Double = 25 // TV + soundbar + streaming + game console
        static let homeOffice: Double = 12 // desktop + monitor + router
        static let kitchen: Double = 8 // microwave + coffee maker + toaster
        static let smartPowerStripSavings: Double = 0.75 // 75% phantom reduction
    }
}
