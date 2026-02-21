import SwiftUI

enum Constants {
    static let accentColor = Color(red: 0.910, green: 0.447, blue: 0.047) // #E8720C warm amber
    static let secondaryColor = Color(red: 0.102, green: 0.102, blue: 0.180) // #1A1A2E deep charcoal
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
}
