import Foundation

enum ClimateZone: String, CaseIterable, Codable, Identifiable {
    case hot = "Hot"
    case moderate = "Moderate"
    case cold = "Cold"

    var id: String { rawValue }

    var btuPerSqFt: Double {
        switch self {
        case .hot: return Constants.ClimateFactors.hot
        case .moderate: return Constants.ClimateFactors.moderate
        case .cold: return Constants.ClimateFactors.cold
        }
    }

    var description: String {
        switch self {
        case .hot: return "Desert Southwest, Gulf Coast, Florida"
        case .moderate: return "Mid-Atlantic, Pacific Coast, Midwest"
        case .cold: return "Northern US, Mountain West, New England"
        }
    }
}
