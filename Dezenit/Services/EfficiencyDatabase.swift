import Foundation

struct EfficiencySpec {
    let estimated: Double
    let codeMinimum: Double
    let bestInClass: Double
    let upgradeCost: Double
}

enum EfficiencyDatabase {

    // MARK: - Lookup

    static func lookup(type: EquipmentType, age: AgeRange) -> EfficiencySpec {
        switch type {
        case .centralAC:    return centralAC(age: age)
        case .heatPump:     return heatPump(age: age)
        case .furnace:      return furnace(age: age)
        case .waterHeater:  return waterHeaterTank(age: age)
        case .waterHeaterTankless: return waterHeaterTankless(age: age)
        case .windowUnit:   return windowUnit(age: age)
        case .thermostat:   return thermostat(age: age)
        case .insulation:   return insulationSpec(age: age)
        case .windows:      return windowsSpec(age: age)
        case .washer:       return washer(age: age)
        case .dryer:        return dryer(age: age)
        }
    }

    // MARK: - Central AC (SEER)

    private static func centralAC(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 9.0
        case .years15to20:  estimated = 11.0
        case .years10to15:  estimated = 12.5
        case .years5to10:   estimated = 13.5
        case .years0to5:    estimated = 15.0
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 15.2, bestInClass: 24.0, upgradeCost: 6000)
    }

    // MARK: - Heat Pump (SEER)

    private static func heatPump(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 9.0
        case .years15to20:  estimated = 11.5
        case .years10to15:  estimated = 14.0
        case .years5to10:   estimated = 16.5
        case .years0to5:    estimated = 18.0
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 15.2, bestInClass: 25.0, upgradeCost: 7500)
    }

    // MARK: - Furnace (AFUE %)

    private static func furnace(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 65
        case .years15to20:  estimated = 75
        case .years10to15:  estimated = 82
        case .years5to10:   estimated = 88
        case .years0to5:    estimated = 93
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 80, bestInClass: 98.5, upgradeCost: 4500)
    }

    // MARK: - Water Heater Tank (UEF)

    private static func waterHeaterTank(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 0.50
        case .years15to20:  estimated = 0.57
        case .years10to15:  estimated = 0.60
        case .years5to10:   estimated = 0.65
        case .years0to5:    estimated = 0.67
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 0.64, bestInClass: 3.5, upgradeCost: 3500)
    }

    // MARK: - Water Heater Tankless (UEF)

    private static func waterHeaterTankless(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 0.82
        case .years15to20:  estimated = 0.85
        case .years10to15:  estimated = 0.87
        case .years5to10:   estimated = 0.90
        case .years0to5:    estimated = 0.93
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 0.87, bestInClass: 0.97, upgradeCost: 3000)
    }

    // MARK: - Window AC (EER)

    private static func windowUnit(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 8.0
        case .years15to20:  estimated = 9.0
        case .years10to15:  estimated = 9.5
        case .years5to10:   estimated = 10.0
        case .years0to5:    estimated = 11.0
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 10.0, bestInClass: 15.0, upgradeCost: 800)
    }

    // MARK: - Thermostat (savings %)

    private static func thermostat(age: AgeRange) -> EfficiencySpec {
        // Treating as: 0 = manual, 7.5 = programmable, 12.5 = smart
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 0
        case .years15to20:  estimated = 0
        case .years10to15:  estimated = 5.0
        case .years5to10:   estimated = 7.5
        case .years0to5:    estimated = 12.5
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 5.0, bestInClass: 15.0, upgradeCost: 225)
    }

    // MARK: - Insulation (R-value)

    private static func insulationSpec(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 11
        case .years15to20:  estimated = 19
        case .years10to15:  estimated = 30
        case .years5to10:   estimated = 38
        case .years0to5:    estimated = 44
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 38, bestInClass: 60, upgradeCost: 2200)
    }

    // MARK: - Windows (U-factor, lower is better)

    private static func windowsSpec(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 1.1
        case .years15to20:  estimated = 0.55
        case .years10to15:  estimated = 0.40
        case .years5to10:   estimated = 0.30
        case .years0to5:    estimated = 0.27
        }
        // For windows, lower U-factor is better; code minimum and best in class use same direction
        return EfficiencySpec(estimated: estimated, codeMinimum: 0.30, bestInClass: 0.15, upgradeCost: 800)
    }

    // MARK: - Washer (IMEF)

    private static func washer(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 1.0
        case .years15to20:  estimated = 1.4
        case .years10to15:  estimated = 1.8
        case .years5to10:   estimated = 2.0
        case .years0to5:    estimated = 2.2
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 1.84, bestInClass: 2.92, upgradeCost: 1200)
    }

    // MARK: - Dryer (CEF)

    private static func dryer(age: AgeRange) -> EfficiencySpec {
        let estimated: Double
        switch age {
        case .years20plus:  estimated = 2.5
        case .years15to20:  estimated = 2.8
        case .years10to15:  estimated = 3.1
        case .years5to10:   estimated = 3.4
        case .years0to5:    estimated = 3.7
        }
        return EfficiencySpec(estimated: estimated, codeMinimum: 3.01, bestInClass: 5.2, upgradeCost: 1000)
    }

    // MARK: - Annual Cost Calculation

    static func estimateAnnualCost(
        type: EquipmentType,
        efficiency: Double,
        homeSqFt: Double,
        climateZone: ClimateZone,
        electricityRate: Double = Constants.defaultElectricityRate,
        gasRate: Double = Constants.defaultGasRate
    ) -> Double {
        switch type {
        case .centralAC, .heatPump, .windowUnit:
            // correctedFactor = btuPerSqFt * fullLoadHours / 1000
            // Hot:      30 BTU/sqft * 1800 hrs / 1000 = 54
            // Moderate: 25 BTU/sqft * 1100 hrs / 1000 = 27.5
            // Cold:     35 BTU/sqft *  600 hrs / 1000 = 21
            let correctedFactor: Double
            switch climateZone {
            case .hot:      correctedFactor = 54.0
            case .moderate: correctedFactor = 27.5
            case .cold:     correctedFactor = 21.0
            }
            guard efficiency > 0 else { return 0 }
            return (homeSqFt * correctedFactor) / efficiency * electricityRate

        case .furnace:
            let factor: Double
            switch climateZone {
            case .hot: factor = 200
            case .moderate: factor = 600
            case .cold: factor = 1000
            }
            guard efficiency > 0 else { return 0 }
            return (homeSqFt * factor * gasRate) / efficiency

        case .waterHeater, .waterHeaterTankless:
            // Approximate annual water heating cost
            guard efficiency > 0 else { return 0 }
            return 400 / efficiency // ~$400 baseline at UEF 1.0

        default:
            return 0
        }
    }

    static func estimateAnnualSavings(
        type: EquipmentType,
        currentEfficiency: Double,
        targetEfficiency: Double,
        homeSqFt: Double,
        climateZone: ClimateZone
    ) -> Double {
        let currentCost = estimateAnnualCost(type: type, efficiency: currentEfficiency, homeSqFt: homeSqFt, climateZone: climateZone)
        let upgradedCost = estimateAnnualCost(type: type, efficiency: targetEfficiency, homeSqFt: homeSqFt, climateZone: climateZone)
        return max(currentCost - upgradedCost, 0)
    }

    static func paybackYears(upgradeCost: Double, annualSavings: Double) -> Double? {
        guard annualSavings > 0 else { return nil }
        return upgradeCost / annualSavings
    }
}
