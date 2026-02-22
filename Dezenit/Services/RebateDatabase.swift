import Foundation

// MARK: - US State

enum USState: String, CaseIterable, Identifiable {
    case california = "California"
    case texas = "Texas"
    case florida = "Florida"
    case newYork = "New York"
    case pennsylvania = "Pennsylvania"
    case illinois = "Illinois"
    case ohio = "Ohio"
    case georgia = "Georgia"
    case northCarolina = "North Carolina"
    case michigan = "Michigan"
    case newJersey = "New Jersey"
    case virginia = "Virginia"
    case washington = "Washington"
    case arizona = "Arizona"
    case massachusetts = "Massachusetts"

    var id: String { rawValue }

    static func from(administrativeArea: String) -> USState? {
        allCases.first { $0.rawValue.lowercased() == administrativeArea.lowercased() }
    }
}

// MARK: - Rebate

struct Rebate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let amountDescription: String
    let equipmentTypes: [EquipmentType]
    let url: String
    let programName: String
    let expirationNote: String?
}

// MARK: - Database

enum RebateDatabase {

    static func rebates(for state: USState) -> [Rebate] {
        stateRebates[state] ?? []
    }

    static func rebates(for state: USState, equipmentTypes: [EquipmentType]) -> [Rebate] {
        rebates(for: state).filter { rebate in
            rebate.equipmentTypes.contains { equipmentTypes.contains($0) }
        }
    }

    // MARK: - Embedded Data

    private static let stateRebates: [USState: [Rebate]] = [

        // MARK: California
        .california: [
            Rebate(
                title: "TECH Clean California Heat Pump Rebate",
                description: "Rebate for replacing gas furnace with qualifying heat pump system.",
                amountDescription: "$3,000–$6,000",
                equipmentTypes: [.heatPump],
                url: "https://www.techcleanca.com",
                programName: "TECH Clean California",
                expirationNote: nil
            ),
            Rebate(
                title: "Self-Generation Incentive Program (SGIP)",
                description: "Incentive for home battery storage systems, with equity adders for low-income households.",
                amountDescription: "$150–$1,000/kWh",
                equipmentTypes: [],
                url: "https://www.selfgenca.com",
                programName: "SGIP",
                expirationNote: nil
            ),
            Rebate(
                title: "PG&E Heat Pump Water Heater Rebate",
                description: "Rebate for installing a qualifying heat pump water heater.",
                amountDescription: "$1,000–$2,500",
                equipmentTypes: [.waterHeater, .waterHeaterTankless],
                url: "https://www.pge.com/en/save-energy-and-money/rebates-and-incentives.html",
                programName: "PG&E",
                expirationNote: nil
            ),
            Rebate(
                title: "SCE Home Energy Efficiency Rebates",
                description: "Rebates for HVAC upgrades, insulation, and weatherization from Southern California Edison.",
                amountDescription: "$200–$2,000",
                equipmentTypes: [.centralAC, .heatPump, .furnace, .insulation],
                url: "https://www.sce.com/residential/rebates-savings",
                programName: "SCE",
                expirationNote: nil
            ),
            Rebate(
                title: "BayREN Home+ Program",
                description: "Whole-home rebates for Bay Area residents completing energy efficiency upgrades.",
                amountDescription: "$1,000–$5,000",
                equipmentTypes: [.heatPump, .insulation, .windows, .waterHeater],
                url: "https://www.bayrenresidential.org",
                programName: "BayREN",
                expirationNote: nil
            ),
        ],

        // MARK: Texas
        .texas: [
            Rebate(
                title: "Oncor Residential AC Rebate",
                description: "Rebate for high-efficiency central air conditioners and heat pumps (16+ SEER).",
                amountDescription: "$200–$495",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.oncoreenergysavings.com",
                programName: "Oncor Take A Load Off Texas",
                expirationNote: nil
            ),
            Rebate(
                title: "CenterPoint Energy Weatherization",
                description: "Rebates for insulation and air sealing improvements.",
                amountDescription: "$200–$600",
                equipmentTypes: [.insulation],
                url: "https://www.centerpointenergy.com/en-us/residential/save-energy-money",
                programName: "CenterPoint Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "Austin Energy Power Saver Program",
                description: "Rebates for HVAC, water heaters, and weatherization for Austin Energy customers.",
                amountDescription: "$300–$1,400",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater, .insulation],
                url: "https://savings.austinenergy.com",
                programName: "Austin Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "CPS Energy HVAC Rebate",
                description: "San Antonio utility rebate for qualifying high-efficiency HVAC systems.",
                amountDescription: "$200–$600",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.cpsenergy.com/en/save-energy-money/rebates.html",
                programName: "CPS Energy",
                expirationNote: nil
            ),
        ],

        // MARK: Florida
        .florida: [
            Rebate(
                title: "FPL Residential AC Rebate",
                description: "Rebate for installing a qualifying high-efficiency AC system.",
                amountDescription: "$150–$365",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.fpl.com/save/rebates.html",
                programName: "FPL",
                expirationNote: nil
            ),
            Rebate(
                title: "Duke Energy Florida HVAC Rebate",
                description: "Rebate for high-efficiency central AC or heat pump installations.",
                amountDescription: "$150–$400",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.duke-energy.com/home/products/smart-saver",
                programName: "Duke Energy Florida",
                expirationNote: nil
            ),
            Rebate(
                title: "FPL Ceiling Insulation Rebate",
                description: "Rebate for adding or upgrading attic insulation.",
                amountDescription: "$0.15/sq ft",
                equipmentTypes: [.insulation],
                url: "https://www.fpl.com/save/rebates.html",
                programName: "FPL",
                expirationNote: nil
            ),
            Rebate(
                title: "JEA Heat Pump Water Heater Rebate",
                description: "Jacksonville utility rebate for heat pump water heaters.",
                amountDescription: "$300–$500",
                equipmentTypes: [.waterHeater],
                url: "https://www.jea.com/save-money-and-energy/rebates",
                programName: "JEA",
                expirationNote: nil
            ),
        ],

        // MARK: New York
        .newYork: [
            Rebate(
                title: "EmPower+ Heat Pump Rebate",
                description: "NYSERDA incentive for whole-home heat pump installations.",
                amountDescription: "$1,000–$14,000",
                equipmentTypes: [.heatPump],
                url: "https://www.nyserda.ny.gov/All-Programs/EmPower-New-York",
                programName: "NYSERDA EmPower+",
                expirationNote: nil
            ),
            Rebate(
                title: "Con Edison Residential Rebates",
                description: "Rebates for heat pumps, smart thermostats, and weatherization.",
                amountDescription: "$50–$1,000",
                equipmentTypes: [.heatPump, .thermostat, .insulation],
                url: "https://www.coned.com/en/save-money/rebates-incentives-tax-credits",
                programName: "Con Edison",
                expirationNote: nil
            ),
            Rebate(
                title: "NYS Clean Heat Program",
                description: "Statewide incentive for switching from fossil fuel to heat pump heating.",
                amountDescription: "$500–$2,500/ton",
                equipmentTypes: [.heatPump, .waterHeater, .waterHeaterTankless],
                url: "https://cleanheat.ny.gov",
                programName: "NYS Clean Heat",
                expirationNote: nil
            ),
            Rebate(
                title: "NYSERDA Home Performance with ENERGY STAR",
                description: "Whole-home energy assessment with rebates for insulation and air sealing.",
                amountDescription: "Up to $4,000",
                equipmentTypes: [.insulation, .windows],
                url: "https://www.nyserda.ny.gov/All-Programs/Residential",
                programName: "NYSERDA HPwES",
                expirationNote: nil
            ),
        ],

        // MARK: Pennsylvania
        .pennsylvania: [
            Rebate(
                title: "PECO Smart Equipment Rewards",
                description: "Rebates for energy-efficient HVAC equipment.",
                amountDescription: "$200–$500",
                equipmentTypes: [.centralAC, .heatPump, .furnace],
                url: "https://www.peco.com/ways-to-save/for-your-home/rebates-and-offers",
                programName: "PECO",
                expirationNote: nil
            ),
            Rebate(
                title: "PPL Electric Home Comfort Program",
                description: "Rebates on heat pumps and heat pump water heaters.",
                amountDescription: "$300–$750",
                equipmentTypes: [.heatPump, .waterHeater],
                url: "https://www.pplelectric.com/save-energy-and-money",
                programName: "PPL Electric",
                expirationNote: nil
            ),
            Rebate(
                title: "Duquesne Light Watt Choices Rebates",
                description: "Rebates for insulation, HVAC, and water heating upgrades.",
                amountDescription: "$100–$500",
                equipmentTypes: [.insulation, .centralAC, .waterHeater],
                url: "https://www.duquesnelight.com/energy-money-savings/residential-rebates",
                programName: "Duquesne Light",
                expirationNote: nil
            ),
        ],

        // MARK: Illinois
        .illinois: [
            Rebate(
                title: "ComEd Energy Efficiency Rebates",
                description: "Rebates for HVAC, water heating, and insulation upgrades.",
                amountDescription: "$200–$1,200",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater, .insulation],
                url: "https://www.comed.com/ways-to-save/for-your-home/rebates-and-offers",
                programName: "ComEd",
                expirationNote: nil
            ),
            Rebate(
                title: "Ameren Illinois Residential Rebates",
                description: "Rebates for high-efficiency furnaces, heat pumps, and insulation.",
                amountDescription: "$200–$800",
                equipmentTypes: [.furnace, .heatPump, .insulation],
                url: "https://www.amerenillinoissavings.com",
                programName: "Ameren Illinois",
                expirationNote: nil
            ),
            Rebate(
                title: "Nicor Gas Residential Rebates",
                description: "Rebates for high-efficiency furnaces and water heaters.",
                amountDescription: "$100–$500",
                equipmentTypes: [.furnace, .waterHeater],
                url: "https://www.nicorgasrebates.com",
                programName: "Nicor Gas",
                expirationNote: nil
            ),
        ],

        // MARK: Ohio
        .ohio: [
            Rebate(
                title: "Ohio FirstEnergy Products Program",
                description: "Rebates for HVAC and water heating equipment.",
                amountDescription: "$50–$400",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater],
                url: "https://www.energysaveohio.com",
                programName: "FirstEnergy",
                expirationNote: nil
            ),
            Rebate(
                title: "AEP Ohio Energy Efficiency Rebates",
                description: "Rebates for heat pumps, central AC, and insulation.",
                amountDescription: "$100–$500",
                equipmentTypes: [.centralAC, .heatPump, .insulation],
                url: "https://www.aepohio.com/save",
                programName: "AEP Ohio",
                expirationNote: nil
            ),
            Rebate(
                title: "Columbia Gas Weatherization Rebate",
                description: "Rebates for insulation, air sealing, and furnace upgrades.",
                amountDescription: "$100–$600",
                equipmentTypes: [.furnace, .insulation],
                url: "https://www.columbiagasohio.com/save-energy-money",
                programName: "Columbia Gas",
                expirationNote: nil
            ),
        ],

        // MARK: Georgia
        .georgia: [
            Rebate(
                title: "Georgia Power Residential Rebates",
                description: "Rebates for high-efficiency heat pumps, AC, and water heaters.",
                amountDescription: "$200–$700",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater],
                url: "https://www.georgiapower.com/residential/save-money-and-energy/rebates-and-offers.html",
                programName: "Georgia Power",
                expirationNote: nil
            ),
            Rebate(
                title: "Georgia Power Weatherization Rebates",
                description: "Rebates for insulation and duct sealing.",
                amountDescription: "$100–$400",
                equipmentTypes: [.insulation],
                url: "https://www.georgiapower.com/residential/save-money-and-energy/rebates-and-offers.html",
                programName: "Georgia Power",
                expirationNote: nil
            ),
            Rebate(
                title: "Atlanta Gas Light Efficient Equipment",
                description: "Rebates for gas furnaces and water heaters meeting efficiency criteria.",
                amountDescription: "$100–$300",
                equipmentTypes: [.furnace, .waterHeater],
                url: "https://atlantagaslight.com/residential/save-energy-money",
                programName: "Atlanta Gas Light",
                expirationNote: nil
            ),
        ],

        // MARK: North Carolina
        .northCarolina: [
            Rebate(
                title: "Duke Energy NC Smart Saver",
                description: "Rebates for high-efficiency HVAC and heat pump water heaters.",
                amountDescription: "$200–$600",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater],
                url: "https://www.duke-energy.com/home/products/smart-saver",
                programName: "Duke Energy Carolinas",
                expirationNote: nil
            ),
            Rebate(
                title: "Piedmont Natural Gas Rebates",
                description: "Rebates for high-efficiency gas furnaces and water heaters.",
                amountDescription: "$100–$400",
                equipmentTypes: [.furnace, .waterHeater],
                url: "https://www.piedmontng.com/save-energy-money",
                programName: "Piedmont Natural Gas",
                expirationNote: nil
            ),
            Rebate(
                title: "NC Weatherization Assistance",
                description: "State-funded weatherization for eligible homeowners including insulation and air sealing.",
                amountDescription: "Up to $8,009 average",
                equipmentTypes: [.insulation, .windows],
                url: "https://www.ncdhhs.gov/weatherization-assistance-program",
                programName: "NC DHHS",
                expirationNote: nil
            ),
        ],

        // MARK: Michigan
        .michigan: [
            Rebate(
                title: "DTE Energy Rebates",
                description: "Rebates for high-efficiency furnaces, heat pumps, and insulation.",
                amountDescription: "$100–$500",
                equipmentTypes: [.furnace, .heatPump, .insulation],
                url: "https://www.dteenergy.com/us/en/residential/save-money-energy/rebates.html",
                programName: "DTE Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "Consumers Energy Rebates",
                description: "Rebates for HVAC, water heaters, and weatherization.",
                amountDescription: "$200–$800",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater, .insulation],
                url: "https://www.consumersenergy.com/residential/save-money-and-energy/rebates",
                programName: "Consumers Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "Michigan Saves Home Energy Loan",
                description: "Low-interest financing for whole-home energy improvements.",
                amountDescription: "2.5%–5.5% APR financing",
                equipmentTypes: [.heatPump, .insulation, .windows, .furnace],
                url: "https://michigansaves.org/residential",
                programName: "Michigan Saves",
                expirationNote: nil
            ),
        ],

        // MARK: New Jersey
        .newJersey: [
            Rebate(
                title: "NJ Clean Energy HVAC Rebates",
                description: "Rebates for high-efficiency heating and cooling equipment.",
                amountDescription: "$300–$1,000",
                equipmentTypes: [.centralAC, .heatPump, .furnace],
                url: "https://njcleanenergy.com/residential/programs/home-programs",
                programName: "NJ Clean Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "NJ HPwES Whole-Home",
                description: "Home Performance with ENERGY STAR — rebates for comprehensive upgrades.",
                amountDescription: "Up to $4,000",
                equipmentTypes: [.insulation, .windows, .heatPump],
                url: "https://njcleanenergy.com/residential/programs/home-performance-energy-star",
                programName: "NJ Clean Energy HPwES",
                expirationNote: nil
            ),
            Rebate(
                title: "PSE&G Residential Rebates",
                description: "Rebates for water heaters and HVAC from PSE&G.",
                amountDescription: "$100–$500",
                equipmentTypes: [.waterHeater, .centralAC],
                url: "https://www.pseg.com/saveenergy/home",
                programName: "PSE&G",
                expirationNote: nil
            ),
        ],

        // MARK: Virginia
        .virginia: [
            Rebate(
                title: "Dominion Energy Residential Rebates",
                description: "Rebates for heat pumps, AC, and weatherization improvements.",
                amountDescription: "$100–$500",
                equipmentTypes: [.centralAC, .heatPump, .insulation],
                url: "https://www.dominionenergy.com/virginia/save-energy/rebates-and-incentives",
                programName: "Dominion Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "Appalachian Power Take Charge Rebates",
                description: "Rebates for HVAC, water heaters, and insulation.",
                amountDescription: "$100–$500",
                equipmentTypes: [.heatPump, .waterHeater, .insulation],
                url: "https://www.appalachianpower.com/save-money-energy",
                programName: "Appalachian Power",
                expirationNote: nil
            ),
            Rebate(
                title: "Virginia Natural Gas Rebates",
                description: "Rebates for high-efficiency gas furnaces and water heaters.",
                amountDescription: "$100–$300",
                equipmentTypes: [.furnace, .waterHeater],
                url: "https://www.virginianaturalgas.com/save-energy",
                programName: "Virginia Natural Gas",
                expirationNote: nil
            ),
        ],

        // MARK: Washington
        .washington: [
            Rebate(
                title: "PSE Residential Rebates",
                description: "Puget Sound Energy rebates for heat pumps, water heaters, and insulation.",
                amountDescription: "$200–$1,500",
                equipmentTypes: [.heatPump, .waterHeater, .insulation],
                url: "https://www.pse.com/rebates",
                programName: "Puget Sound Energy",
                expirationNote: nil
            ),
            Rebate(
                title: "Seattle City Light Rebates",
                description: "Rebates for heat pumps, ductless mini-splits, and insulation.",
                amountDescription: "$200–$2,000",
                equipmentTypes: [.heatPump, .insulation],
                url: "https://www.seattle.gov/city-light/residential-services/rebates-and-programs",
                programName: "Seattle City Light",
                expirationNote: nil
            ),
            Rebate(
                title: "Snohomish PUD Heat Pump Rebate",
                description: "Rebate for qualifying air-source and ductless heat pumps.",
                amountDescription: "$400–$1,200",
                equipmentTypes: [.heatPump],
                url: "https://www.snopud.com/rebates",
                programName: "Snohomish PUD",
                expirationNote: nil
            ),
            Rebate(
                title: "WA Weatherization Assistance",
                description: "State weatherization program for qualifying homeowners.",
                amountDescription: "Varies by income",
                equipmentTypes: [.insulation, .windows],
                url: "https://www.commerce.wa.gov/growing-the-economy/energy/weatherization",
                programName: "WA Dept. of Commerce",
                expirationNote: nil
            ),
        ],

        // MARK: Arizona
        .arizona: [
            Rebate(
                title: "APS Cool Rewards AC Rebate",
                description: "Rebate for high-efficiency central air conditioner or heat pump.",
                amountDescription: "$200–$500",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.aps.com/en/residential/save-money-and-energy/rebates-and-offers",
                programName: "APS",
                expirationNote: nil
            ),
            Rebate(
                title: "SRP Residential Rebates",
                description: "Salt River Project rebates for HVAC and water heater upgrades.",
                amountDescription: "$150–$600",
                equipmentTypes: [.centralAC, .heatPump, .waterHeater],
                url: "https://www.srpnet.com/save-energy/rebates.aspx",
                programName: "SRP",
                expirationNote: nil
            ),
            Rebate(
                title: "APS Shade Screen Rebate",
                description: "Rebate for installing qualifying window shade screens.",
                amountDescription: "$1.25/sq ft",
                equipmentTypes: [.windows],
                url: "https://www.aps.com/en/residential/save-money-and-energy/rebates-and-offers",
                programName: "APS",
                expirationNote: nil
            ),
            Rebate(
                title: "TEP HVAC Rebate",
                description: "Tucson Electric Power rebates for high-efficiency AC and heat pumps.",
                amountDescription: "$200–$450",
                equipmentTypes: [.centralAC, .heatPump],
                url: "https://www.tep.com/rebates",
                programName: "TEP",
                expirationNote: nil
            ),
        ],

        // MARK: Massachusetts
        .massachusetts: [
            Rebate(
                title: "Mass Save Heat Pump Rebate",
                description: "Whole-home heat pump incentives through Mass Save program.",
                amountDescription: "$1,250–$10,000",
                equipmentTypes: [.heatPump],
                url: "https://www.masssave.com/residential/rebates-and-incentives/heat-pumps",
                programName: "Mass Save",
                expirationNote: nil
            ),
            Rebate(
                title: "Mass Save Insulation Rebate",
                description: "75–100% off insulation costs through home energy assessment.",
                amountDescription: "75%–100% of cost",
                equipmentTypes: [.insulation],
                url: "https://www.masssave.com/residential/rebates-and-incentives/insulation",
                programName: "Mass Save",
                expirationNote: nil
            ),
            Rebate(
                title: "Mass Save Water Heater Rebate",
                description: "Rebate for heat pump water heaters.",
                amountDescription: "$600–$1,250",
                equipmentTypes: [.waterHeater, .waterHeaterTankless],
                url: "https://www.masssave.com/residential/rebates-and-incentives/water-heating",
                programName: "Mass Save",
                expirationNote: nil
            ),
            Rebate(
                title: "Mass Save Weatherization",
                description: "Free home energy assessment with air sealing included.",
                amountDescription: "Free assessment + air sealing",
                equipmentTypes: [.insulation, .windows],
                url: "https://www.masssave.com/residential/programs-and-services/home-energy-assessments",
                programName: "Mass Save",
                expirationNote: nil
            ),
        ],
    ]
}
