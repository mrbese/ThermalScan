import Foundation

struct Recommendation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let estimatedSavings: String?
}

enum RecommendationEngine {
    static func generate(
        squareFootage: Double,
        ceilingHeight: CeilingHeightOption,
        insulation: InsulationQuality,
        windows: [WindowInfo],
        breakdown: BTUBreakdown
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // South/west window solar gain + not good insulation → low-e film
        let highGainWindows = windows.filter { $0.direction == .south || $0.direction == .west }
        if !highGainWindows.isEmpty && insulation != .good {
            let highGainBTU = highGainWindows.reduce(0) { $0 + $1.heatGainBTU }
            let savingsBTU = Int(highGainBTU * 0.275) // midpoint of 25-30%
            recommendations.append(Recommendation(
                icon: "sun.max",
                title: "Low-E Window Film",
                detail: "Your \(highGainWindows.count) south/west-facing window(s) contribute ~\(Int(highGainBTU).formatted()) BTU of solar heat gain. Low-emissivity window film can reduce this by 25–30%.",
                estimatedSavings: "Save ~\(savingsBTU.formatted()) BTU/hr peak load"
            ))
        }

        // Poor insulation → attic upgrade
        if insulation == .poor {
            recommendations.append(Recommendation(
                icon: "house.and.flag",
                title: "Upgrade to R-49 Attic Insulation",
                detail: "Poor insulation adds a 30% BTU penalty to your load. Upgrading attic insulation to R-49 can reduce peak HVAC load by 1.0–1.5 kW and dramatically improve envelope efficiency.",
                estimatedSavings: "1.0–1.5 kW peak load reduction"
            ))
        }

        // Excessive glazing (total window area > 30% of floor)
        let totalWindowArea = windows.reduce(0) { $0 + $1.size.sqFt }
        if totalWindowArea > squareFootage * 0.30 {
            recommendations.append(Recommendation(
                icon: "window.casement",
                title: "Reduce Thermal Glazing Exposure",
                detail: "Your window area (\(Int(totalWindowArea)) sq ft) exceeds 30% of your floor area (\(Int(squareFootage)) sq ft). Thermal cellular shades or insulated curtains can significantly cut heat gain/loss at the glass.",
                estimatedSavings: "10–20% reduction in window-related load"
            ))
        }

        // Ceiling height > 10ft → ceiling fans
        if ceilingHeight.feet > 10 {
            recommendations.append(Recommendation(
                icon: "fan",
                title: "Install Ceiling Fans for Destratification",
                detail: "At \(ceilingHeight.feet) ft ceiling height, hot air stratifies heavily. Ceiling fans in winter (reverse/clockwise at low speed) push warm air back down, reducing thermostat demand by 2–3°F.",
                estimatedSavings: "5–10% heating season savings"
            ))
        }

        // Always include duct sealing
        recommendations.append(Recommendation(
            icon: "arrow.triangle.branch",
            title: "Aerosol Duct Sealing",
            detail: "Leaky ductwork (industry average: 20–30% loss) undermines HVAC efficiency. Aerosol duct sealing to <4% leakage rate can recover 15–20% of lost conditioned air.",
            estimatedSavings: "15–20% conditioned air recovered"
        ))

        return recommendations
    }
}
