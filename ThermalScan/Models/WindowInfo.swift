import Foundation

enum CardinalDirection: String, CaseIterable, Codable, Identifiable {
    case north = "N"
    case south = "S"
    case east = "E"
    case west = "W"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .north: return "North"
        case .south: return "South"
        case .east: return "East"
        case .west: return "West"
        }
    }

    var btuPerSqFt: Double {
        switch self {
        case .north: return Constants.WindowBTUPerSqFt.north
        case .south: return Constants.WindowBTUPerSqFt.south
        case .east: return Constants.WindowBTUPerSqFt.east
        case .west: return Constants.WindowBTUPerSqFt.west
        }
    }
}

enum WindowSize: String, CaseIterable, Codable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var sqFt: Double {
        switch self {
        case .small: return Constants.WindowSizeSqFt.small
        case .medium: return Constants.WindowSizeSqFt.medium
        case .large: return Constants.WindowSizeSqFt.large
        }
    }

    var description: String {
        switch self {
        case .small: return "Small (~10 sq ft)"
        case .medium: return "Medium (~20 sq ft)"
        case .large: return "Large (~35 sq ft)"
        }
    }
}

struct WindowInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var direction: CardinalDirection = .south
    var size: WindowSize = .medium

    var heatGainBTU: Double {
        direction.btuPerSqFt * size.sqFt
    }
}
