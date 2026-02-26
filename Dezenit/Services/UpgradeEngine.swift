import Foundation

// MARK: - Data Types

enum UpgradeTier: String, Codable, CaseIterable {
    case good = "Good"
    case better = "Better"
    case best = "Best"
}

struct UpgradeRecommendation: Identifiable {
    let id = UUID()
    let tier: UpgradeTier
    let title: String
    let upgradeTarget: String
    let costLow: Double
    let costHigh: Double
    let annualSavings: Double
    let paybackYears: Double?
    let explanation: String
    let taxCreditEligible: Bool
    let taxCreditAmount: Double
    let effectivePaybackYears: Double?
    let technologyNote: String?
    let alreadyMeetsThisTier: Bool
}

struct TaxCreditInfo {
    let irsSection: String // "25C" or "25D"
    let maxAmount: Double
    let description: String
    let disclaimer: String

    static let section25C = TaxCreditInfo(
        irsSection: "25C",
        maxAmount: 3200,
        description: "Energy Efficient Home Improvement Credit",
        disclaimer: "Annual cap of $3,200. Consult a tax professional for eligibility."
    )

    static let section25D = TaxCreditInfo(
        irsSection: "25D",
        maxAmount: .infinity,
        description: "Residential Clean Energy Credit (30%)",
        disclaimer: "No annual cap. Consult a tax professional for eligibility."
    )
}

// MARK: - Engine

enum UpgradeEngine {

    // MARK: - Public API

    static func generateUpgrades(
        for equipment: Equipment,
        climateZone: ClimateZone,
        homeSqFt: Double,
        electricityRate: Double = Constants.defaultElectricityRate,
        gasRate: Double = Constants.defaultGasRate
    ) -> [UpgradeRecommendation] {
        let sqFt = homeSqFt > 0 ? homeSqFt : 1500
        let type = equipment.typeEnum
        let currentEfficiency = equipment.estimatedEfficiency

        switch type {
        case .centralAC:
            return centralACUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt, electricityRate: electricityRate, gasRate: gasRate, equipment: equipment)
        case .heatPump:
            return heatPumpUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt, electricityRate: electricityRate)
        case .furnace:
            return furnaceUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt, electricityRate: electricityRate, gasRate: gasRate)
        case .waterHeater:
            return waterHeaterTankUpgrades(current: currentEfficiency, sqFt: sqFt)
        case .waterHeaterTankless:
            return waterHeaterTanklessUpgrades(current: currentEfficiency, sqFt: sqFt)
        case .windowUnit:
            return windowUnitUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt, electricityRate: electricityRate)
        case .thermostat:
            return thermostatUpgrades(current: currentEfficiency, sqFt: sqFt)
        case .insulation:
            return insulationUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt)
        case .windows:
            return windowsUpgrades(current: currentEfficiency, climateZone: climateZone, sqFt: sqFt, equipment: equipment)
        case .washer:
            return washerUpgrades(current: currentEfficiency, sqFt: sqFt)
        case .dryer:
            return dryerUpgrades(current: currentEfficiency, sqFt: sqFt)
        }
    }

    static func aggregateTaxCredits(from allUpgrades: [[UpgradeRecommendation]]) -> (total25C: Double, total25D: Double, grandTotal: Double) {
        var sum25C: Double = 0
        var sum25D: Double = 0
        for upgrades in allUpgrades {
            // Take the "best" tier recommendation if available
            if let best = upgrades.first(where: { $0.tier == .best }), best.taxCreditEligible {
                if best.technologyNote?.contains("25D") == true || best.title.lowercased().contains("heat pump") || best.title.lowercased().contains("solar") || best.title.lowercased().contains("geothermal") {
                    sum25D += best.taxCreditAmount
                } else {
                    sum25C += best.taxCreditAmount
                }
            }
        }
        let capped25C = min(sum25C, 3200)
        return (total25C: capped25C, total25D: sum25D, grandTotal: capped25C + sum25D)
    }

    // MARK: - Cost Scaling

    private static func scaleCost(low: Double, high: Double, sqFt: Double) -> (Double, Double) {
        // Under 2000 = low end, over 3000 = high end, linear interpolation
        let t = min(max((sqFt - 2000) / 1000, 0), 1)
        let scaledLow = low + (high - low) * t * 0.3  // low end scales a bit
        let scaledHigh = low + (high - low) * (0.3 + t * 0.7) // high end scales more
        return (scaledLow, scaledHigh)
    }

    private static func avgCost(_ low: Double, _ high: Double) -> Double {
        (low + high) / 2
    }

    private static func makeRecommendation(
        tier: UpgradeTier,
        title: String,
        target: String,
        costLow: Double,
        costHigh: Double,
        annualSavings: Double,
        explanation: String,
        taxCreditEligible: Bool = false,
        taxCreditPercent: Double = 0,
        taxCreditCap: Double = 0,
        technologyNote: String? = nil,
        alreadyMeets: Bool = false
    ) -> UpgradeRecommendation {
        let avg = avgCost(costLow, costHigh)
        let payback = annualSavings > 0 ? avg / annualSavings : nil

        let creditAmount: Double
        if taxCreditEligible {
            let rawCredit = avg * taxCreditPercent
            creditAmount = taxCreditCap > 0 ? min(rawCredit, taxCreditCap) : rawCredit
        } else {
            creditAmount = 0
        }

        let effectivePayback: Double?
        if let _ = payback, creditAmount > 0 {
            let effectiveCost = max(avg - creditAmount, 0)
            effectivePayback = annualSavings > 0 ? effectiveCost / annualSavings : nil
        } else {
            effectivePayback = payback
        }

        return UpgradeRecommendation(
            tier: tier,
            title: title,
            upgradeTarget: target,
            costLow: costLow,
            costHigh: costHigh,
            annualSavings: annualSavings,
            paybackYears: payback,
            explanation: explanation,
            taxCreditEligible: taxCreditEligible,
            taxCreditAmount: creditAmount,
            effectivePaybackYears: effectivePayback,
            technologyNote: technologyNote,
            alreadyMeetsThisTier: alreadyMeets
        )
    }

    private static func savings(type: EquipmentType, current: Double, target: Double, sqFt: Double, climateZone: ClimateZone, electricityRate: Double = Constants.defaultElectricityRate, gasRate: Double = Constants.defaultGasRate) -> Double {
        EfficiencyDatabase.estimateAnnualSavings(
            type: type, currentEfficiency: current, targetEfficiency: target,
            homeSqFt: sqFt, climateZone: climateZone
        )
    }

    // MARK: - Central AC

    private static func centralACUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double, electricityRate: Double, gasRate: Double, equipment: Equipment) -> [UpgradeRecommendation] {
        let goodTarget = 16.0
        let betterTarget = 20.0
        let bestTarget = 24.0 // or cold-climate heat pump replacing AC+furnace

        let (gLow, gHigh) = scaleCost(low: 4000, high: 6500, sqFt: sqFt)
        let (bLow, bHigh) = scaleCost(low: 6000, high: 9000, sqFt: sqFt)
        let (bestLow, bestHigh) = scaleCost(low: 8000, high: 14000, sqFt: sqFt)

        let goodSavings = savings(type: .centralAC, current: current, target: goodTarget, sqFt: sqFt, climateZone: climateZone)
        let betterSavings = savings(type: .centralAC, current: current, target: betterTarget, sqFt: sqFt, climateZone: climateZone)

        // Best tier: heat pump replaces AC + furnace → combined cooling + heating savings
        let coolingSavings = savings(type: .centralAC, current: current, target: bestTarget, sqFt: sqFt, climateZone: climateZone)
        // Heating savings: old furnace cost minus new HP heating cost (uses HSPF 13, not SEER)
        let furnaceCost = EfficiencyDatabase.estimateAnnualCost(type: .furnace, efficiency: 80, homeSqFt: sqFt, climateZone: climateZone, gasRate: gasRate)
        let heatPumpHeatingCost = EfficiencyDatabase.estimateHeatPumpHeatingCost(hspf: 13.0, homeSqFt: sqFt, climateZone: climateZone, electricityRate: electricityRate)
        let heatingSavings = max(furnaceCost - heatPumpHeatingCost, 0)
        let bestSavings = coolingSavings + heatingSavings

        return [
            makeRecommendation(
                tier: .good, title: "High-Efficiency Central AC",
                target: "\(Int(goodTarget)) SEER",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "Replace with a code-compliant 16 SEER unit. Reliable, widely available, and the most cost-effective upgrade.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "Single-stage compressor. Standard refrigerant R-410A or R-454B. IRS 25C eligible up to $600.",
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Variable-Speed Central AC",
                target: "\(Int(betterTarget)) SEER",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "Variable-speed compressor runs at lower capacity most of the time, delivering better humidity control and quieter operation.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "Inverter-driven compressor. Brands: Carrier Infinity, Trane XV, Lennox XC. IRS 25C eligible.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Cold-Climate Heat Pump (replaces AC + Furnace)",
                target: "\(Int(bestTarget)) SEER / 13 HSPF",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Eliminates gas furnace entirely. A ducted heat pump handles both cooling and heating. Combined savings from removing gas bill plus higher cooling efficiency.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% uncapped federal tax credit for heat pumps. Operates efficiently down to -15°F. Brands: Mitsubishi Hyper-Heat, Daikin Fit, Bosch IDS.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Heat Pump

    private static func heatPumpUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double, electricityRate: Double) -> [UpgradeRecommendation] {
        let goodTarget = 16.0
        let betterTarget = 20.0
        let bestTarget = 25.0

        let (gLow, gHigh) = scaleCost(low: 5000, high: 7500, sqFt: sqFt)
        let (bLow, bHigh) = scaleCost(low: 7000, high: 10000, sqFt: sqFt)
        let (bestLow, bestHigh) = scaleCost(low: 10000, high: 16000, sqFt: sqFt)

        return [
            makeRecommendation(
                tier: .good, title: "Standard Heat Pump Upgrade",
                target: "\(Int(goodTarget)) SEER",
                costLow: gLow, costHigh: gHigh,
                annualSavings: savings(type: .heatPump, current: current, target: goodTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Replace with a current-code 16 SEER heat pump. Improved refrigerant and compressor technology.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% federal credit for qualifying heat pumps. Standard single-stage.",
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Variable-Speed Heat Pump",
                target: "\(Int(betterTarget)) SEER",
                costLow: bLow, costHigh: bHigh,
                annualSavings: savings(type: .heatPump, current: current, target: betterTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Inverter-driven compressor adjusts output continuously. Much better comfort and 30-40% lower operating cost vs. single-stage.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D eligible. Brands: Carrier Greenspeed, Trane XV20i, Daikin DZ series.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Premium Cold-Climate Heat Pump",
                target: "\(Int(bestTarget)) SEER / 13 HSPF",
                costLow: bestLow, costHigh: bestHigh,
                annualSavings: savings(type: .heatPump, current: current, target: bestTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Top-tier cold-climate heat pump with enhanced vapor injection. Efficient heating down to -15°F without backup strips.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% uncapped. Mitsubishi Hyper-Heat, Bosch IDS 2.0. ENERGY STAR Cold Climate certified.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Furnace

    private static func furnaceUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double, electricityRate: Double, gasRate: Double) -> [UpgradeRecommendation] {
        let goodTarget = 90.0
        let betterTarget = 96.0
        _ = 22.0 // bestHPSEER — reserved for future heat pump SEER reference

        let (gLow, gHigh) = scaleCost(low: 2500, high: 4500, sqFt: sqFt)
        let (bLow, bHigh) = scaleCost(low: 3500, high: 6000, sqFt: sqFt)
        let (bestLow, bestHigh) = scaleCost(low: 8000, high: 14000, sqFt: sqFt)

        let goodSavings = savings(type: .furnace, current: current, target: goodTarget, sqFt: sqFt, climateZone: climateZone)
        let betterSavings = savings(type: .furnace, current: current, target: betterTarget, sqFt: sqFt, climateZone: climateZone)

        // Best: replace furnace with heat pump, using HSPF 13 for heating cost
        let currentFurnaceCost = EfficiencyDatabase.estimateAnnualCost(type: .furnace, efficiency: current, homeSqFt: sqFt, climateZone: climateZone, gasRate: gasRate)
        let hpHeatingCost = EfficiencyDatabase.estimateHeatPumpHeatingCost(hspf: 13.0, homeSqFt: sqFt, climateZone: climateZone, electricityRate: electricityRate)
        let bestSavings = max(currentFurnaceCost - hpHeatingCost, 0)

        return [
            makeRecommendation(
                tier: .good, title: "High-Efficiency Gas Furnace",
                target: "\(Int(goodTarget))% AFUE",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "90% AFUE condensing furnace. Uses secondary heat exchanger to capture exhaust heat.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Condensing furnace requires PVC venting (no masonry chimney). Standard in most new construction.",
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Ultra-High-Efficiency Furnace",
                target: "\(Int(betterTarget))% AFUE",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "96%+ AFUE modulating furnace with variable-speed blower. Near-zero heat loss from exhaust.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C: up to $600 for 97%+ AFUE furnaces. Brands: Carrier 59MN7, Trane S9V2, Lennox SLP99V.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Electrify: Heat Pump (replace gas furnace)",
                target: "22 SEER / 13 HSPF heat pump",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Fully electrify heating by replacing gas furnace with a ducted heat pump. Eliminates gas bill and qualifies for the largest federal credit.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% uncapped federal tax credit. Also eliminates gas line/meter charges ($10-20/mo).",
                alreadyMeets: false
            ),
        ]
    }

    // MARK: - Water Heater (Tank)

    private static func waterHeaterTankUpgrades(current: Double, sqFt: Double) -> [UpgradeRecommendation] {
        let goodTarget = 0.70
        let betterTarget = 0.95
        let bestTarget = 3.5

        let (gLow, gHigh) = scaleCost(low: 800, high: 1500, sqFt: sqFt)
        let (bLow, bHigh) = scaleCost(low: 1500, high: 2500, sqFt: sqFt)
        let (bestLow, bestHigh) = scaleCost(low: 2500, high: 4500, sqFt: sqFt)

        let baseline: Double = 400 // annual water heating baseline at UEF 1.0
        let currentCost = current > 0 ? baseline / current : baseline
        let goodSavings = max(currentCost - baseline / goodTarget, 0)
        let betterSavings = max(currentCost - baseline / betterTarget, 0)
        let bestSavings = max(currentCost - baseline / bestTarget, 0)

        return [
            makeRecommendation(
                tier: .good, title: "High-Efficiency Tank Water Heater",
                target: "0.70 UEF",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "ENERGY STAR certified tank with improved insulation and burner efficiency.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Standard gas or electric tank. 40-50 gallon capacity typical for most homes.",
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Condensing Tankless Water Heater",
                target: "0.95 UEF",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "On-demand heating with no standby losses. Condensing technology captures exhaust heat for ~95% efficiency.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C: up to $600. Brands: Rinnai RUR, Navien NPE, Rheem RTGH. Requires gas line upgrade in some cases.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Heat Pump Water Heater",
                target: "3.5 UEF",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Uses heat pump technology to move heat from surrounding air into water. 3-4x more efficient than conventional tanks. Also dehumidifies the space.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% uncapped credit. Brands: Rheem ProTerra, A.O. Smith Voltex, Bradford White AeroTherm. Needs ~700 cu ft of air space.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Water Heater (Tankless)

    private static func waterHeaterTanklessUpgrades(current: Double, sqFt: Double) -> [UpgradeRecommendation] {
        let goodTarget = 0.90
        let betterTarget = 0.95
        let bestTarget = 3.5

        let (gLow, gHigh) = scaleCost(low: 1200, high: 2000, sqFt: sqFt)
        let (bLow, bHigh) = scaleCost(low: 2000, high: 3000, sqFt: sqFt)
        let (bestLow, bestHigh) = scaleCost(low: 2500, high: 4500, sqFt: sqFt)

        let baseline: Double = 400
        let currentCost = current > 0 ? baseline / current : baseline
        let goodSavings = max(currentCost - baseline / goodTarget, 0)
        let betterSavings = max(currentCost - baseline / betterTarget, 0)
        let bestSavings = max(currentCost - baseline / bestTarget, 0)

        return [
            makeRecommendation(
                tier: .good, title: "Updated Tankless Water Heater",
                target: "0.90 UEF",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "Newer non-condensing tankless with improved burner. Modest efficiency gain.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Condensing Tankless Water Heater",
                target: "0.95 UEF",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "Condensing unit captures exhaust heat. Top gas efficiency available.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C: up to $600. Rinnai RUR199, Navien NPE-2 series.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Heat Pump Water Heater",
                target: "3.5 UEF",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Switch from gas tankless to heat pump water heater. 3-4x more efficient, eliminates gas usage for water heating.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% uncapped. Fully electric, pairs well with solar panels.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Window AC

    private static func windowUnitUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double, electricityRate: Double) -> [UpgradeRecommendation] {
        let goodTarget = 12.0
        let betterTarget = 15.0
        let bestTarget = 22.0 // mini-split

        let (gLow, gHigh) = (300.0, 600.0)
        let (bLow, bHigh) = (500.0, 900.0)
        let (bestLow, bestHigh) = scaleCost(low: 3000, high: 5000, sqFt: sqFt)

        return [
            makeRecommendation(
                tier: .good, title: "ENERGY STAR Window AC",
                target: "\(Int(goodTarget)) EER",
                costLow: gLow, costHigh: gHigh,
                annualSavings: savings(type: .windowUnit, current: current, target: goodTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Replace with an ENERGY STAR certified unit. Better compressor and fan motor.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Premium Inverter Window AC",
                target: "\(Int(betterTarget)) EER",
                costLow: bLow, costHigh: bHigh,
                annualSavings: savings(type: .windowUnit, current: current, target: betterTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Inverter-driven window units (Midea U-Shape, LG Dual Inverter) are quieter and 30-40% more efficient.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Inverter compressor runs at variable speed. Much quieter and more even temperature.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Ductless Mini-Split Heat Pump",
                target: "\(Int(bestTarget)) SEER",
                costLow: bestLow, costHigh: bestHigh,
                annualSavings: savings(type: .windowUnit, current: current, target: bestTarget, sqFt: sqFt, climateZone: climateZone),
                explanation: "Replace window unit with a ductless mini-split. Provides both heating and cooling with dramatically better efficiency.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 2000,
                technologyNote: "IRS 25D: 30% credit. Wall-mounted indoor unit + outdoor compressor. Brands: Mitsubishi, Fujitsu, Daikin.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Thermostat

    private static func thermostatUpgrades(current: Double, sqFt: Double) -> [UpgradeRecommendation] {
        // current: 0=manual, 5=basic programmable, 7.5=programmable, 12.5=smart
        let annualHVACCost = sqFt * 2.5 // rough estimate of total annual HVAC cost

        return [
            makeRecommendation(
                tier: .good, title: "Programmable Thermostat",
                target: "7-day programmable",
                costLow: 30, costHigh: 80, annualSavings: annualHVACCost * 0.08,
                explanation: "Basic 7-day programmable thermostat. Set schedules for when you're home, away, and sleeping.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Honeywell Home, Emerson Sensi. No WiFi required.",
                alreadyMeets: current >= 7.5
            ),
            makeRecommendation(
                tier: .better, title: "Smart Thermostat",
                target: "WiFi smart thermostat",
                costLow: 120, costHigh: 250, annualSavings: annualHVACCost * 0.12,
                explanation: "WiFi-connected with app control, geofencing, and learning algorithms. Adapts to your schedule automatically.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 150,
                technologyNote: "IRS 25C: up to $150. ecobee, Google Nest, Honeywell T9. Requires WiFi.",
                alreadyMeets: current >= 12.5
            ),
            makeRecommendation(
                tier: .best, title: "Smart Thermostat with Room Sensors",
                target: "Multi-zone smart thermostat",
                costLow: 200, costHigh: 350, annualSavings: annualHVACCost * 0.15,
                explanation: "Smart thermostat plus wireless room sensors. Averages temperature across rooms for true comfort. Eliminates hot/cold spots.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 150,
                technologyNote: "IRS 25C: up to $150. ecobee Premium (includes air quality sensor), Honeywell T10 Pro.",
                alreadyMeets: current >= 15.0
            ),
        ]
    }

    // MARK: - Insulation

    private static func insulationUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double) -> [UpgradeRecommendation] {
        let goodTarget = 38.0
        let betterTarget = 49.0
        let bestTarget = 60.0

        // Per sq ft costs, multiplied by attic area (~= home sq ft)
        let goodPerSqFt = 1.5
        let betterPerSqFt = 2.5
        let bestPerSqFt = 4.0

        let gLow = sqFt * goodPerSqFt * 0.8
        let gHigh = sqFt * goodPerSqFt * 1.2
        let bLow = sqFt * betterPerSqFt * 0.8
        let bHigh = sqFt * betterPerSqFt * 1.2
        let bestLow = sqFt * bestPerSqFt * 0.8
        let bestHigh = sqFt * bestPerSqFt * 1.2

        // Savings: insulation reduces overall HVAC load. Estimate as % of total HVAC cost.
        let annualHVACCost = sqFt * 2.5
        let currentRatio = min(current / 60.0, 1.0)
        let goodRatio = min(goodTarget / 60.0, 1.0)
        let betterRatio = min(betterTarget / 60.0, 1.0)
        let bestRatio = min(bestTarget / 60.0, 1.0)

        let goodSavings = max((goodRatio - currentRatio) * annualHVACCost * 0.3, 0)
        let betterSavings = max((betterRatio - currentRatio) * annualHVACCost * 0.3, 0)
        let bestSavings = max((bestRatio - currentRatio) * annualHVACCost * 0.3, 0)

        return [
            makeRecommendation(
                tier: .good, title: "Blown-In Cellulose (R-38)",
                target: "R-\(Int(goodTarget)) attic insulation",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "Bring attic insulation to current code minimum. Blown-in cellulose is the most cost-effective option.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 1200,
                technologyNote: "IRS 25C: 30% up to $1,200. Recycled newspaper-based material. DIY-friendly with rental blower.",
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Deep Blown-In (R-49)",
                target: "R-\(Int(betterTarget)) attic insulation",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "Exceed code with deeper blown-in insulation. ENERGY STAR recommended for most climate zones.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 1200,
                technologyNote: "IRS 25C: 30% up to $1,200. 16-18 inches of cellulose or fiberglass.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Spray Foam + Blown-In (R-60)",
                target: "R-\(Int(bestTarget)) attic insulation",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Closed-cell spray foam at roof deck plus blown-in on attic floor. Creates a complete air seal and maximum R-value.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 1200,
                technologyNote: "IRS 25C: 30% up to $1,200. Spray foam also acts as vapor barrier and air seal.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Windows

    private static func windowsUpgrades(current: Double, climateZone: ClimateZone, sqFt: Double, equipment: Equipment) -> [UpgradeRecommendation] {
        // Windows: lower U-factor is better
        let goodTarget = 0.30
        let betterTarget = 0.22
        let bestTarget = 0.15

        // Per-window cost, estimate ~10 windows for average home
        let windowCount = max(Double(Int(sqFt / 150)), 5) // rough: 1 window per 150 sq ft
        let goodPerWindow = 600.0
        let betterPerWindow = 900.0
        let bestPerWindow = 1400.0

        let gLow = windowCount * goodPerWindow * 0.8
        let gHigh = windowCount * goodPerWindow * 1.2
        let bLow = windowCount * betterPerWindow * 0.8
        let bHigh = windowCount * betterPerWindow * 1.2
        let bestLow = windowCount * bestPerWindow * 0.8
        let bestHigh = windowCount * bestPerWindow * 1.2

        // Savings estimate based on window heat loss reduction
        let annualHVACCost = sqFt * 2.5
        let windowShareOfLoss = 0.25 // windows typically account for ~25% of envelope loss
        let currentLoss = current // higher U = more loss
        let goodReduction = max((currentLoss - goodTarget) / currentLoss, 0)
        let betterReduction = max((currentLoss - betterTarget) / currentLoss, 0)
        let bestReduction = max((currentLoss - bestTarget) / currentLoss, 0)

        let goodSavings = annualHVACCost * windowShareOfLoss * goodReduction
        let betterSavings = annualHVACCost * windowShareOfLoss * betterReduction
        let bestSavings = annualHVACCost * windowShareOfLoss * bestReduction

        return [
            makeRecommendation(
                tier: .good, title: "Double-Pane Low-E Windows",
                target: "U-\(String(format: "%.2f", goodTarget))",
                costLow: gLow, costHigh: gHigh, annualSavings: goodSavings,
                explanation: "Standard double-pane with Low-E coating and argon fill. Meets current energy code.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C: 30% up to $600 for ENERGY STAR certified windows. Most common upgrade.",
                alreadyMeets: current <= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Triple-Pane Low-E Windows",
                target: "U-\(String(format: "%.2f", betterTarget))",
                costLow: bLow, costHigh: bHigh, annualSavings: betterSavings,
                explanation: "Triple-pane with two Low-E coatings and argon or krypton fill. Dramatically reduces heat transfer and condensation.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C eligible. Brands: Andersen 400, Pella Lifestyle, Marvin Elevate.",
                alreadyMeets: current <= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Vacuum-Insulated or Quad-Pane Windows",
                target: "U-\(String(format: "%.2f", bestTarget))",
                costLow: bestLow, costHigh: bestHigh, annualSavings: bestSavings,
                explanation: "Cutting-edge vacuum-insulated glass or quad-pane configuration. Near-wall insulation performance from a window.",
                taxCreditEligible: true, taxCreditPercent: 0.30, taxCreditCap: 600,
                technologyNote: "IRS 25C eligible. Emerging tech: LandVac, Pilkington Spacia. Limited availability but rapidly expanding.",
                alreadyMeets: current <= bestTarget
            ),
        ]
    }

    // MARK: - Washer

    private static func washerUpgrades(current: Double, sqFt: Double) -> [UpgradeRecommendation] {
        let goodTarget = 2.0
        let betterTarget = 2.5
        let bestTarget = 2.92

        // Washer annual cost estimate (~$50-100/yr for electricity + water)
        let baseline: Double = 80
        let currentCost = current > 0 ? baseline * (2.0 / current) : baseline
        let goodSavings = max(currentCost - baseline * (2.0 / goodTarget), 0)
        let betterSavings = max(currentCost - baseline * (2.0 / betterTarget), 0)
        let bestSavings = max(currentCost - baseline * (2.0 / bestTarget), 0)

        return [
            makeRecommendation(
                tier: .good, title: "ENERGY STAR Washer",
                target: "\(String(format: "%.1f", goodTarget)) IMEF",
                costLow: 600, costHigh: 900, annualSavings: goodSavings,
                explanation: "Standard ENERGY STAR front-load washer. Uses 25% less energy and 33% less water than non-certified.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "ENERGY STAR Most Efficient Washer",
                target: "\(String(format: "%.1f", betterTarget)) IMEF",
                costLow: 900, costHigh: 1300, annualSavings: betterSavings,
                explanation: "Top-tier ENERGY STAR Most Efficient certified. Best water extraction reduces dryer time.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Better spin extraction means clothes enter dryer with less moisture, saving dryer energy too.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Heat Pump Washer-Dryer Combo",
                target: "\(String(format: "%.1f", bestTarget)) IMEF + heat pump dry",
                costLow: 1500, costHigh: 2500, annualSavings: bestSavings + 80, // add dryer savings
                explanation: "All-in-one heat pump washer-dryer. Eliminates separate dryer, uses 50% less total energy for laundry.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "LG WashTower, Samsung Bespoke AI. Single unit saves space and total energy.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }

    // MARK: - Dryer

    private static func dryerUpgrades(current: Double, sqFt: Double) -> [UpgradeRecommendation] {
        let goodTarget = 3.5
        let betterTarget = 4.0
        let bestTarget = 5.2

        let baseline: Double = 100
        let currentCost = current > 0 ? baseline * (3.0 / current) : baseline
        let goodSavings = max(currentCost - baseline * (3.0 / goodTarget), 0)
        let betterSavings = max(currentCost - baseline * (3.0 / betterTarget), 0)
        let bestSavings = max(currentCost - baseline * (3.0 / bestTarget), 0)

        return [
            makeRecommendation(
                tier: .good, title: "ENERGY STAR Electric Dryer",
                target: "\(String(format: "%.1f", goodTarget)) CEF",
                costLow: 500, costHigh: 800, annualSavings: goodSavings,
                explanation: "ENERGY STAR certified with moisture sensors to prevent over-drying.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                alreadyMeets: current >= goodTarget
            ),
            makeRecommendation(
                tier: .better, title: "Ventless Heat Pump Dryer",
                target: "\(String(format: "%.1f", betterTarget)) CEF",
                costLow: 800, costHigh: 1200, annualSavings: betterSavings,
                explanation: "Heat pump dryer uses 50% less energy than conventional. No external vent needed — install anywhere.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Recirculates heated air through a heat exchanger. Gentler on clothes, lower fire risk.",
                alreadyMeets: current >= betterTarget
            ),
            makeRecommendation(
                tier: .best, title: "Premium Heat Pump Dryer",
                target: "\(String(format: "%.1f", bestTarget)) CEF",
                costLow: 1100, costHigh: 1800, annualSavings: bestSavings,
                explanation: "Top-efficiency heat pump dryer with advanced moisture sensing and steam refresh cycles.",
                taxCreditEligible: false, taxCreditPercent: 0, taxCreditCap: 0,
                technologyNote: "Miele T1, LG DLHC5502, Samsung DV-HP. Longest cycle times but lowest operating cost.",
                alreadyMeets: current >= bestTarget
            ),
        ]
    }
}
