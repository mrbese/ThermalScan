import Foundation

enum InsulationQuality: String, CaseIterable, Codable, Identifiable {
    case poor = "Poor"
    case average = "Average"
    case good = "Good"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .poor: return Constants.InsulationMultipliers.poor
        case .average: return Constants.InsulationMultipliers.average
        case .good: return Constants.InsulationMultipliers.good
        }
    }

    var description: String {
        switch self {
        case .poor: return "Minimal or degraded insulation, older home"
        case .average: return "Standard builder-grade insulation"
        case .good: return "High-performance insulation, R-49+ attic"
        }
    }
}
