import Foundation
import SwiftData

@Model
final class Room {
    var id: UUID
    var name: String
    var squareFootage: Double
    var ceilingHeight: Int        // 8, 9, 10, or 12
    var climateZone: String       // ClimateZone.rawValue
    var insulation: String        // InsulationQuality.rawValue
    var windowsData: Data?        // JSON-encoded [WindowInfo]
    var calculatedBTU: Double
    var calculatedTonnage: Double
    var createdAt: Date
    var scanWasUsed: Bool
    var home: Home?
    @Relationship(deleteRule: .nullify, inverse: \Appliance.room) var appliances: [Appliance]

    init(
        name: String = "",
        squareFootage: Double = 0,
        ceilingHeight: Int = 8,
        climateZone: ClimateZone = .moderate,
        insulation: InsulationQuality = .average,
        windows: [WindowInfo] = [],
        calculatedBTU: Double = 0,
        calculatedTonnage: Double = 0,
        scanWasUsed: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.squareFootage = squareFootage
        self.ceilingHeight = ceilingHeight
        self.climateZone = climateZone.rawValue
        self.insulation = insulation.rawValue
        self.windowsData = try? JSONEncoder().encode(windows)
        self.calculatedBTU = calculatedBTU
        self.calculatedTonnage = calculatedTonnage
        self.createdAt = Date()
        self.scanWasUsed = scanWasUsed
        self.appliances = []
    }

    var windows: [WindowInfo] {
        get {
            guard let data = windowsData else { return [] }
            return (try? JSONDecoder().decode([WindowInfo].self, from: data)) ?? []
        }
        set {
            windowsData = try? JSONEncoder().encode(newValue)
        }
    }

    var climateZoneEnum: ClimateZone {
        ClimateZone(rawValue: climateZone) ?? .moderate
    }

    var insulationEnum: InsulationQuality {
        InsulationQuality(rawValue: insulation) ?? .average
    }

    var ceilingHeightOption: CeilingHeightOption {
        CeilingHeightOption.allCases.first { $0.feet == ceilingHeight } ?? .eight
    }
}

enum CeilingHeightOption: Int, CaseIterable, Identifiable {
    case eight = 8
    case nine = 9
    case ten = 10
    case twelve = 12

    var id: Int { rawValue }
    var feet: Int { rawValue }

    var label: String { "\(rawValue) ft" }

    var factor: Double {
        switch self {
        case .eight: return Constants.CeilingFactors.eight
        case .nine: return Constants.CeilingFactors.nine
        case .ten: return Constants.CeilingFactors.ten
        case .twelve: return Constants.CeilingFactors.twelve
        }
    }
}
