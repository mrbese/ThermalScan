import Foundation

enum InsulationQuality: String, CaseIterable, Codable, Identifiable {
    case unknown = "Select..."
    case poor = "Poor"
    case average = "Average"
    case good = "Good"

    var id: String { rawValue }

    var isSelected: Bool { self != .unknown }

    /// Cases for user selection (excludes unknown)
    static var selectableCases: [InsulationQuality] { [.poor, .average, .good] }

    var multiplier: Double {
        switch self {
        case .unknown: return Constants.InsulationMultipliers.average // fall back to average for calc
        case .poor: return Constants.InsulationMultipliers.poor
        case .average: return Constants.InsulationMultipliers.average
        case .good: return Constants.InsulationMultipliers.good
        }
    }

    var description: String {
        switch self {
        case .unknown: return "How would you rate your insulation? Check your attic or ask your home inspector."
        case .poor: return "Minimal or degraded insulation, older home"
        case .average: return "Standard builder-grade insulation"
        case .good: return "High-performance insulation, R-49+ attic"
        }
    }
}
