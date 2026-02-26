import Foundation
import SwiftData

enum AuditStep: String, CaseIterable, Codable, Identifiable {
    case homeBasics = "Home Basics"
    case roomScanning = "Room Scanning"
    case hvacEquipment = "HVAC Equipment"
    case waterHeating = "Water Heating"
    case applianceInventory = "Appliance Inventory"
    case lightingAudit = "Lighting Audit"
    case windowAssessment = "Window Assessment"
    case envelopeAssessment = "Envelope Assessment"
    case billUpload = "Bill Upload"
    case review = "Review"

    var id: String { rawValue }

    var stepNumber: Int {
        Self.allCases.firstIndex(of: self)! + 1
    }

    var icon: String {
        switch self {
        case .homeBasics: return "house"
        case .roomScanning: return "camera.viewfinder"
        case .hvacEquipment: return "snowflake"
        case .waterHeating: return "drop.fill"
        case .applianceInventory: return "tv"
        case .lightingAudit: return "lightbulb"
        case .windowAssessment: return "window.casement"
        case .envelopeAssessment: return "house.and.flag"
        case .billUpload: return "doc.text"
        case .review: return "checkmark.seal"
        }
    }

    var shortLabel: String {
        switch self {
        case .homeBasics: return "Basics"
        case .roomScanning: return "Rooms"
        case .hvacEquipment: return "HVAC"
        case .waterHeating: return "Water"
        case .applianceInventory: return "Appliances"
        case .lightingAudit: return "Lighting"
        case .windowAssessment: return "Windows"
        case .envelopeAssessment: return "Envelope"
        case .billUpload: return "Bills"
        case .review: return "Review"
        }
    }
}

@Model
final class AuditProgress {
    var id: UUID
    var completedStepsData: Data? // JSON-encoded [String] of AuditStep rawValues
    var currentStep: String // AuditStep.rawValue
    var home: Home?
    var startedAt: Date
    var lastUpdatedAt: Date

    init(home: Home? = nil) {
        self.id = UUID()
        self.completedStepsData = try? JSONEncoder().encode([String]())
        self.currentStep = AuditStep.homeBasics.rawValue
        self.home = home
        self.startedAt = Date()
        self.lastUpdatedAt = Date()
    }

    var completedSteps: [AuditStep] {
        get {
            guard let data = completedStepsData,
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return rawValues.compactMap { AuditStep(rawValue: $0) }
        }
        set {
            completedStepsData = try? JSONEncoder().encode(newValue.map(\.rawValue))
            lastUpdatedAt = Date()
        }
    }

    var currentStepEnum: AuditStep {
        AuditStep(rawValue: currentStep) ?? .homeBasics
    }

    func isStepComplete(_ step: AuditStep) -> Bool {
        completedSteps.contains(step)
    }

    func markComplete(_ step: AuditStep) {
        var steps = completedSteps
        if !steps.contains(step) {
            steps.append(step)
            completedSteps = steps
        }
    }

    var progressPercentage: Double {
        let total = Double(AuditStep.allCases.count)
        return total > 0 ? Double(completedSteps.count) / total * 100.0 : 0
    }

    var isComplete: Bool {
        completedSteps.count == AuditStep.allCases.count
    }
}
