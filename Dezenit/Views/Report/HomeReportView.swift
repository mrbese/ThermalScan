import SwiftUI
import UIKit

struct HomeReportView: View {
    let home: Home
    @Environment(\.dismiss) private var dismiss
    @State private var gradeRevealed = false
    @State private var showingPDFShare = false
    @State private var pdfURL: URL?
    @StateObject private var stateDetector = StateDetectionService()

    private var grade: EfficiencyGrade {
        GradingEngine.grade(for: home)
    }

    private var profile: EnergyProfile {
        EnergyProfileService.generateProfile(for: home)
    }

    private var homeRecommendations: [Recommendation] {
        RecommendationEngine.generateHomeRecommendations(for: home)
    }

    private var sqFt: Double {
        home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500
    }

    // All upgrade recommendations grouped by equipment
    private var allUpgradesByEquipment: [(equipment: Equipment, upgrades: [UpgradeRecommendation])] {
        home.equipment.compactMap { eq in
            let ups = UpgradeEngine.generateUpgrades(
                for: eq, climateZone: home.climateZoneEnum, homeSqFt: sqFt
            )
            guard !ups.isEmpty else { return nil }
            // Only include if at least one tier has meaningful savings
            let bestTier = ups.first(where: { $0.tier == .best })
            guard (bestTier?.annualSavings ?? 0) > 10 else { return nil }
            return (equipment: eq, upgrades: ups)
        }.sorted { a, b in
            let aPB = a.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            let bPB = b.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            return aPB < bPB
        }
    }

    // Best-tier recommendations only (for summary stats)
    private var bestTierRecommendations: [UpgradeRecommendation] {
        allUpgradesByEquipment.compactMap { $0.upgrades.first(where: { $0.tier == .best }) }
    }

    private var totalCurrentCost: Double {
        home.equipment.reduce(0) { sum, eq in
            sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: eq.estimatedEfficiency,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
    }

    private var totalUpgradedCost: Double {
        home.equipment.reduce(0) { sum, eq in
            let spec = EfficiencyDatabase.lookup(type: eq.typeEnum, age: eq.ageRangeEnum)
            return sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: spec.bestInClass,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
    }

    private var totalSavings: Double {
        max(totalCurrentCost - totalUpgradedCost, 0)
    }

    private var taxCredits: (total25C: Double, total25D: Double, grandTotal: Double) {
        UpgradeEngine.aggregateTaxCredits(from: allUpgradesByEquipment.map(\.upgrades))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                if !home.equipment.isEmpty {
                    costSection
                }
                if !profile.breakdown.isEmpty {
                    energyProfileSection
                }
                if profile.billComparison != nil {
                    billReconciliationSection
                }
                if !profile.topConsumers.isEmpty {
                    applianceHighlightsSection
                }
                if profile.envelopeScore != nil {
                    envelopeSummarySection
                }
                if !allUpgradesByEquipment.isEmpty {
                    upgradeSummaryStats
                    upgradesSection
                }
                if !homeRecommendations.isEmpty {
                    quickWinsSection
                }
                if taxCredits.grandTotal > 0 {
                    taxCreditSection
                }
                if stateDetector.isDetecting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Detecting your state for rebates...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                if let state = stateDetector.detectedState {
                    rebateSection(state: state)
                }
                if !home.equipment.isEmpty {
                    batterySynergySection
                }
                shareSection
                doneSection
            }
            .padding()
        }
        .navigationTitle("Home Report")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            gradeRevealed = true
            stateDetector.detectState()
        }
        .sensoryFeedback(.success, trigger: gradeRevealed)
        .sheet(isPresented: $showingPDFShare) {
            if let url = pdfURL {
                ShareSheetView(items: [url])
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(home.name.isEmpty ? "Home Assessment" : home.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    if home.computedTotalSqFt > 0 {
                        Text("\(Int(home.computedTotalSqFt)) sq ft")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(grade.rawValue)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Efficiency grade \(grade.rawValue)")
                    Text("Grade")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Divider().background(.white.opacity(0.3))

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(home.rooms.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Rooms")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 2) {
                    Text("\(home.equipment.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Equipment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if home.totalBTU > 0 {
                    VStack(spacing: 2) {
                        Text("\(Int(home.totalBTU / 12000))")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Tons HVAC")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Text(grade.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Cost

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Cost Estimate")
                .font(.headline)

            HStack {
                Text("Current Annual Cost")
                    .font(.subheadline)
                Spacer()
                Text("$\(Int(totalCurrentCost).formatted())/yr")
                    .font(.title3.bold())
            }

            if totalSavings > 0 {
                HStack {
                    Text("After All Upgrades")
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(totalUpgradedCost).formatted())/yr")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Divider()

                HStack {
                    Text("Potential Annual Savings")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("$\(Int(totalSavings).formatted())/yr")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Upgrade Summary Stats

    private var upgradeSummaryStats: some View {
        let totalSav = bestTierRecommendations.reduce(0.0) { $0 + $1.annualSavings }
        let totalCostLow = bestTierRecommendations.reduce(0.0) { $0 + $1.costLow }
        let totalCostHigh = bestTierRecommendations.reduce(0.0) { $0 + $1.costHigh }
        let totalCredits = taxCredits.grandTotal
        let afterCreditsLow = max(totalCostLow - totalCredits, 0)
        let afterCreditsHigh = max(totalCostHigh - totalCredits, 0)
        let avgPayback = totalSav > 0 ? ((totalCostLow + totalCostHigh) / 2) / totalSav : 0
        let afterCreditsPayback = totalSav > 0 ? ((afterCreditsLow + afterCreditsHigh) / 2) / totalSav : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("Upgrade Investment Summary")
                .font(.headline)

            statRow("Total potential savings", "$\(Int(totalSav).formatted())/yr", color: .green)
            statRow("Total investment range", "$\(Int(totalCostLow).formatted()) – $\(Int(totalCostHigh).formatted())", color: .primary)
            statRow("Average payback period", String(format: "%.1f years", avgPayback), color: avgPayback < 5 ? Constants.statusSuccess : Constants.statusWarning)

            if totalCredits > 0 {
                Divider()
                statRow("After tax credits", "$\(Int(afterCreditsLow).formatted()) – $\(Int(afterCreditsHigh).formatted())", color: .blue)
                statRow("Effective payback", String(format: "%.1f years", afterCreditsPayback), color: afterCreditsPayback < 5 ? Constants.statusSuccess : Constants.statusWarning)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func statRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - Upgrades

    private var upgradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prioritized Upgrades")
                .font(.headline)

            Text("Sorted by payback period. Tap to see all tiers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(allUpgradesByEquipment.enumerated()), id: \.offset) { _, item in
                upgradeEquipmentRow(item.equipment, upgrades: item.upgrades)
            }
        }
    }

    private func upgradeEquipmentRow(_ eq: Equipment, upgrades: [UpgradeRecommendation]) -> some View {
        let best = upgrades.first(where: { $0.tier == .best })

        return DisclosureGroup {
            VStack(spacing: 8) {
                ForEach(upgrades) { rec in
                    tierCard(rec)
                }
            }
            .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: eq.typeEnum.icon)
                        .foregroundStyle(Constants.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eq.typeEnum.rawValue)
                            .font(.subheadline.bold())
                        Text("Current: \(String(format: "%.1f", eq.estimatedEfficiency)) \(eq.typeEnum.efficiencyUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let b = best, let pb = b.paybackYears {
                        priorityBadge(payback: pb)
                    }
                }

                if let b = best {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Best Savings")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(Int(b.annualSavings))/yr")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cost Range")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(Int(b.costLow).formatted())–$\(Int(b.costHigh).formatted())")
                                .font(.caption.bold())
                        }
                        if let pb = b.paybackYears {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Payback")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f yr", pb))
                                    .font(.caption.bold())
                            }
                        }
                        if b.taxCreditEligible && b.taxCreditAmount > 0 {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Credit")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("$\(Int(b.taxCreditAmount))")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func tierCard(_ rec: UpgradeRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                tierBadge(rec.tier)
                Text(rec.title)
                    .font(.caption.bold())
                Spacer()
            }

            if rec.alreadyMeetsThisTier {
                Text("Your equipment already meets this tier")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Text(rec.explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Cost")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("$\(Int(rec.costLow).formatted())–$\(Int(rec.costHigh).formatted())")
                        .font(.caption2.bold())
                }
                if rec.annualSavings > 0 {
                    VStack(alignment: .leading) {
                        Text("Savings")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("$\(Int(rec.annualSavings))/yr")
                            .font(.caption2.bold()).foregroundStyle(.green)
                    }
                }
                if let pb = rec.paybackYears {
                    VStack(alignment: .leading) {
                        Text("Payback")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.1f yr", pb))
                            .font(.caption2.bold())
                    }
                }
                if rec.taxCreditEligible && rec.taxCreditAmount > 0 {
                    VStack(alignment: .leading) {
                        Text("Tax Credit")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("$\(Int(rec.taxCreditAmount))")
                            .font(.caption2.bold()).foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(10)
        .background(tierBackgroundColor(rec.tier).opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tierBadge(_ tier: UpgradeTier) -> some View {
        Text(tier.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tierBackgroundColor(tier), in: Capsule())
    }

    private func tierBackgroundColor(_ tier: UpgradeTier) -> Color {
        switch tier {
        case .good: return .blue
        case .better: return .orange
        case .best: return .green
        }
    }

    private func priorityBadge(payback: Double) -> some View {
        let (label, color): (String, Color) = {
            if payback < 3 { return ("Quick Win", .green) }
            if payback < 7 { return ("Strong Investment", .orange) }
            return ("Long Term", .secondary)
        }()

        return Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Energy Profile Breakdown

    @ViewBuilder
    private var energyProfileSection: some View {
        let bp = profile.breakdown
        let total = profile.totalEstimatedAnnualCost

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Constants.accentColor)
                Text("Energy Breakdown")
                    .font(.headline)
            }

            // Stacked bar
            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(bp) { cat in
                            let width = max(geo.size.width * cat.percentage / 100, 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(categoryColor(cat.name))
                                .frame(width: width, height: 20)
                        }
                    }
                }
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Legend
            ForEach(bp) { cat in
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor(cat.name))
                        .frame(width: 10, height: 10)
                    Image(systemName: cat.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(cat.name)
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(cat.annualCost))/yr")
                        .font(.subheadline.bold())
                    Text("(\(Int(cat.percentage))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func categoryColor(_ name: String) -> Color {
        switch name {
        case "HVAC": return .blue
        case "Water Heating": return .cyan
        case "Appliances": return .orange
        case "Lighting": return .yellow
        case "Standby": return .gray
        default: return .secondary
        }
    }

    // MARK: - Bill Reconciliation

    @ViewBuilder
    private var billReconciliationSection: some View {
        if let comparison = profile.billComparison {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(Constants.accentColor)
                    Text("Bill vs. Estimate")
                        .font(.headline)
                }

                HStack {
                    Text("Actual (from bills)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(comparison.billBasedAnnualKWh).formatted()) kWh/yr")
                        .font(.subheadline.bold())
                }
                HStack {
                    Text("Estimated (from audit)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(comparison.estimatedAnnualKWh).formatted()) kWh/yr")
                        .font(.subheadline.bold())
                }

                Divider()

                HStack {
                    Text("Accuracy")
                        .font(.subheadline)
                    Spacer()
                    Text(comparison.accuracyLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(accuracyColor(comparison.accuracyLabel))
                    Text("(\(Int(comparison.gapPercentage))% gap)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if comparison.gapPercentage >= 25 {
                    Text("A large gap may indicate untracked loads (pool pump, workshop, etc.) or seasonal variation. Adding more bills improves accuracy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    private func accuracyColor(_ label: String) -> Color {
        switch label {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .orange
        default: return .red
        }
    }

    // MARK: - Appliance Highlights

    @ViewBuilder
    private var applianceHighlightsSection: some View {
        let consumers = profile.topConsumers
        let phantomKWh = home.totalPhantomAnnualKWh
        let phantomCost = phantomKWh * profile.electricityRate

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Constants.accentColor)
                Text("Top Energy Consumers")
                    .font(.headline)
            }

            ForEach(Array(consumers.enumerated()), id: \.element.id) { index, consumer in
                HStack(spacing: 10) {
                    Text("#\(index + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Constants.accentColor.opacity(0.8), in: Circle())
                    Image(systemName: consumer.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(consumer.name)
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(consumer.annualCost))/yr")
                        .font(.subheadline.bold())
                }
            }

            if phantomKWh > 50 {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Phantom/Standby Waste")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(phantomKWh)) kWh · $\(Int(phantomCost))/yr")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Envelope Summary

    @ViewBuilder
    private var envelopeSummarySection: some View {
        if let envScore = profile.envelopeScore {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Constants.accentColor)
                    Text("Building Envelope")
                        .font(.headline)
                    Spacer()
                    Text(envScore.grade)
                        .font(.title2.bold())
                        .foregroundStyle(envelopeGradeColor(envScore.grade))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(envelopeGradeColor(envScore.grade).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(envScore.details, id: \.self) { detail in
                    let parts = detail.split(separator: ":", maxSplits: 1)
                    HStack {
                        Text(String(parts.first ?? ""))
                            .font(.subheadline)
                        Spacer()
                        Text(String(parts.last ?? "").trimmingCharacters(in: .whitespaces))
                            .font(.subheadline.bold())
                            .foregroundStyle(envelopeDetailColor(String(parts.last ?? "")))
                    }
                }

                if let weakest = envScore.weakestArea {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Priority: \(weakest)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    private func envelopeGradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .yellow
        case "D": return .orange
        default: return .red
        }
    }

    private func envelopeDetailColor(_ value: String) -> Color {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "Good", "Full": return .green
        case "Average", "Fair", "Partial": return .orange
        default: return .red
        }
    }

    // MARK: - Quick Wins

    @ViewBuilder
    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Constants.accentColor)
                Text("Quick Wins & Tips")
                    .font(.headline)
            }

            ForEach(homeRecommendations) { rec in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: rec.icon)
                        .font(.subheadline)
                        .foregroundStyle(Constants.accentColor)
                        .frame(width: 24, alignment: .center)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                        Text(rec.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let savings = rec.estimatedSavings {
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
                if rec.id != homeRecommendations.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Tax Credit Summary

    private var taxCreditSection: some View {
        let credits = taxCredits

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(.blue)
                Text("Federal Tax Credits")
                    .font(.headline)
            }

            if credits.total25C > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRS Section 25C — Energy Efficient Home Improvement")
                        .font(.caption.bold())
                    Text("Eligible credits: $\(Int(credits.total25C))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text("Annual cap: $3,200 per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if credits.total25D > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRS Section 25D — Residential Clean Energy (30%)")
                        .font(.caption.bold())
                    Text("Eligible credits: $\(Int(credits.total25D))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text("No annual cap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Total Potential Credits")
                    .font(.subheadline.bold())
                Spacer()
                Text("$\(Int(credits.grandTotal).formatted())")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }

            Text("Tax credits are subject to eligibility requirements and may change. Consult a qualified tax professional before making purchasing decisions based on tax incentives.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Rebates

    private func rebateSection(state: USState) -> some View {
        let matched = RebateService.matchRebates(for: home, state: state)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .foregroundStyle(.green)
                Text("State & Utility Rebates")
                    .font(.headline)
            }

            Text("Available in \(state.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if matched.isEmpty {
                Text("No matching rebates found for your equipment in \(state.rawValue). Check DSIRE for the latest programs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matched) { rebate in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rebate.title)
                            .font(.subheadline.bold())
                        Text(rebate.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(rebate.amountDescription)
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            Spacer()
                            Text(rebate.programName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let url = URL(string: rebate.url) {
                            Link("View Program Details", destination: url)
                                .font(.caption)
                        }
                        if let expNote = rebate.expirationNote {
                            Text(expNote)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            Divider()

            // dsireusa.org is a known-good URL
            Link(destination: URL(string: "https://www.dsireusa.org")!) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Search All Programs on DSIRE")
                        .font(.subheadline.bold())
                }
            }

            Text("Rebate availability and amounts change frequently. Always verify eligibility directly with the program administrator before making purchasing decisions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Battery Synergy

    private var batterySynergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(Constants.accentColor)
                Text("Battery Synergy")
                    .font(.headline)
            }

            let currentBaseLoad = sqFt * 5.0 / 1500.0
            let savingsRatio = totalSavings > 0 ? totalSavings / max(totalCurrentCost, 1) : 0.15

            // Factor in insulation + HVAC upgrade load reductions from recommendations
            let hasInsulationUpgrade = allUpgradesByEquipment.contains { $0.equipment.typeEnum == .insulation }
            let hasHVACUpgrade = allUpgradesByEquipment.contains { [.centralAC, .heatPump, .furnace].contains($0.equipment.typeEnum) }
            let bonusReduction = (hasInsulationUpgrade ? 0.05 : 0) + (hasHVACUpgrade ? 0.08 : 0)
            let totalReduction = min(savingsRatio * 0.6 + bonusReduction, 0.5)
            let upgradedBaseLoad = currentBaseLoad * (1.0 - totalReduction)
            let exportGain = currentBaseLoad - upgradedBaseLoad

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Current estimated base load", "\(String(format: "%.1f", currentBaseLoad)) kW")
                infoRow("Estimated base load after upgrades", "\(String(format: "%.1f", upgradedBaseLoad)) kW")
                infoRow("Additional battery export capacity", "\(String(format: "%.1f", exportGain)) kW")

                let lowRevenue = Int(exportGain * 50) // ~50 hours at $2/kWh
                let highRevenue = Int(exportGain * 250) // ~50 hours at $5/kWh
                if lowRevenue > 0 {
                    infoRow("Additional grid export revenue", "$\(lowRevenue) to $\(highRevenue)/yr per battery")
                }
            }

            Text("Reducing your home's energy waste frees up more battery capacity for grid export during high-demand events when electricity prices spike to $2,000-$5,000/MWh. This makes home battery systems (Pila Energy, Tesla Powerwall, Base Power) significantly more valuable.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Share

    private var shareSection: some View {
        VStack(spacing: 12) {
            ShareLink(item: generateReportText()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Report")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }

            Button {
                if let url = ReportPDFGenerator.savePDF(for: home) {
                    pdfURL = url
                    showingPDFShare = true
                }
            } label: {
                HStack {
                    Image(systemName: "doc.richtext")
                    Text("Share as PDF")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.primary)
            }
        }
    }

    private var doneSection: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Back to Home")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Constants.accentColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Constants.accentColor, lineWidth: 1.5)
            )
        }
        .padding(.top, 8)
    }

    private func generateReportText() -> String {
        var parts: [String] = []
        parts.append("DEZENIT HOME ENERGY REPORT")
        parts.append("=".repeated(40))
        parts.append("")
        parts.append("Home: \(home.name)")
        if let addr = home.address { parts.append("Address: \(addr)") }
        if home.computedTotalSqFt > 0 { parts.append("Total Area: \(Int(home.computedTotalSqFt)) sq ft") }
        parts.append("Climate Zone: \(home.climateZoneEnum.rawValue)")
        parts.append("Efficiency Grade: \(grade.rawValue)")
        parts.append("")

        if !home.equipment.isEmpty {
            parts.append("ENERGY COST ESTIMATE")
            parts.append("-".repeated(30))
            parts.append("Current Annual Cost: $\(Int(totalCurrentCost))")
            parts.append("After Upgrades: $\(Int(totalUpgradedCost))")
            parts.append("Potential Savings: $\(Int(totalSavings))/yr")
            parts.append("")
        }

        // Energy breakdown
        let bp = profile.breakdown
        if bp.count > 1 {
            parts.append("ENERGY BREAKDOWN")
            parts.append("-".repeated(30))
            for cat in bp {
                parts.append("- \(cat.name): $\(Int(cat.annualCost))/yr (\(Int(cat.percentage))%)")
            }
            parts.append("")
        }

        // Bill comparison
        if let comparison = profile.billComparison {
            parts.append("BILL VS. ESTIMATE")
            parts.append("-".repeated(30))
            parts.append("Actual (from bills): \(Int(comparison.billBasedAnnualKWh)) kWh/yr")
            parts.append("Estimated (from audit): \(Int(comparison.estimatedAnnualKWh)) kWh/yr")
            parts.append("Accuracy: \(comparison.accuracyLabel) (\(Int(comparison.gapPercentage))% gap)")
            parts.append("")
        }

        // Envelope
        if let envScore = profile.envelopeScore {
            parts.append("BUILDING ENVELOPE: \(envScore.grade) (\(Int(envScore.score))/100)")
            parts.append("-".repeated(30))
            for detail in envScore.details {
                parts.append("- \(detail)")
            }
            parts.append("")
        }

        if !allUpgradesByEquipment.isEmpty {
            parts.append("PRIORITIZED UPGRADES (Best Tier)")
            parts.append("-".repeated(30))
            for item in allUpgradesByEquipment {
                if let best = item.upgrades.first(where: { $0.tier == .best }) {
                    let pb = best.paybackYears.map { String(format: "%.1f yr payback", $0) } ?? "N/A"
                    let credit = best.taxCreditEligible ? " (tax credit: $\(Int(best.taxCreditAmount)))" : ""
                    parts.append("- \(item.equipment.typeEnum.rawValue): \(best.title)")
                    parts.append("  $\(Int(best.annualSavings))/yr savings, $\(Int(best.costLow))-$\(Int(best.costHigh)) cost, \(pb)\(credit)")
                }
            }
            parts.append("")
        }

        // Quick wins
        if !homeRecommendations.isEmpty {
            parts.append("QUICK WINS & TIPS")
            parts.append("-".repeated(30))
            for rec in homeRecommendations {
                let savings = rec.estimatedSavings.map { " (\($0))" } ?? ""
                parts.append("- \(rec.title)\(savings)")
            }
            parts.append("")
        }

        let credits = taxCredits
        if credits.grandTotal > 0 {
            parts.append("TAX CREDITS")
            parts.append("-".repeated(30))
            if credits.total25C > 0 { parts.append("Section 25C: $\(Int(credits.total25C))") }
            if credits.total25D > 0 { parts.append("Section 25D: $\(Int(credits.total25D))") }
            parts.append("Total Potential Credits: $\(Int(credits.grandTotal))")
            parts.append("")
        }

        if let state = stateDetector.detectedState {
            let matched = RebateService.matchRebates(for: home, state: state)
            if !matched.isEmpty {
                parts.append("STATE & UTILITY REBATES (\(state.rawValue))")
                parts.append("-".repeated(30))
                for rebate in matched {
                    parts.append("- \(rebate.title): \(rebate.amountDescription)")
                    parts.append("  \(rebate.programName) — \(rebate.url)")
                }
                parts.append("")
            }
        }

        parts.append("Generated by Dezenit | dezenit.com | Built by Omer Bese")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Share Sheet

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - String helper

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
