import Foundation

enum RebateService {

    /// Matches rebates for a home's equipment types in the given state.
    static func matchRebates(for home: Home, state: USState) -> [Rebate] {
        let homeEquipmentTypes = Set(home.equipment.map { $0.typeEnum })
        let allRebates = RebateDatabase.rebates(for: state)

        // Include rebates that match the home's equipment, plus general rebates (empty equipmentTypes)
        return allRebates.filter { rebate in
            rebate.equipmentTypes.isEmpty ||
            rebate.equipmentTypes.contains(where: { homeEquipmentTypes.contains($0) })
        }
    }
}
