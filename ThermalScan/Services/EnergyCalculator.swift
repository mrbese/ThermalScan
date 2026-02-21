import Foundation

struct BTUBreakdown {
    let baseBTU: Double
    let windowHeatGain: Double
    let subtotal: Double
    let insulationAdjustment: Double
    let afterInsulation: Double
    let safetyBuffer: Double
    let finalBTU: Double
    let tonnage: Double

    var windowHeatGainPercentage: Double {
        guard finalBTU > 0 else { return 0 }
        return windowHeatGain / finalBTU * 100
    }
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
            baseBTU: baseBTU,
            windowHeatGain: windowHeatGain,
            subtotal: subtotal,
            insulationAdjustment: insulationAdjustment,
            afterInsulation: afterInsulation,
            safetyBuffer: safetyBuffer,
            finalBTU: finalBTU,
            tonnage: tonnage
        )
    }
}
