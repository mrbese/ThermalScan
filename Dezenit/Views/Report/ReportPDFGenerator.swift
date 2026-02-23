import SwiftUI
import UIKit

enum ReportPDFGenerator {

    // US Letter size in points
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 50
    private static let contentWidth: CGFloat = 612 - 100 // pageWidth - 2 * margin

    @MainActor
    static func generatePDF(for home: Home) -> Data? {
        let text = buildReportText(for: home)
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            drawPages(context: context, text: text, pageRect: pageRect)
        }

        return data.isEmpty ? nil : data
    }

    @MainActor
    static func savePDF(for home: Home) -> URL? {
        guard let data = generatePDF(for: home) else { return nil }

        let fileName = "\(home.name.isEmpty ? "Home" : home.name)_Report.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Text Building

    @MainActor
    private static func buildReportText(for home: Home) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let grade = GradingEngine.grade(for: home)
        let profile = EnergyProfileService.generateProfile(for: home)
        let homeRecs = RecommendationEngine.generateHomeRecommendations(for: home)
        let sqFt = home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500

        let allUpgradesByEquipment: [(equipment: Equipment, upgrades: [UpgradeRecommendation])] = home.equipment.compactMap { eq in
            let ups = UpgradeEngine.generateUpgrades(for: eq, climateZone: home.climateZoneEnum, homeSqFt: sqFt)
            guard !ups.isEmpty else { return nil }
            let bestTier = ups.first(where: { $0.tier == .best })
            guard (bestTier?.annualSavings ?? 0) > 10 else { return nil }
            return (equipment: eq, upgrades: ups)
        }.sorted { a, b in
            let aPB = a.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            let bPB = b.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            return aPB < bPB
        }

        let totalCurrentCost = home.equipment.reduce(0) { sum, eq in
            sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: eq.estimatedEfficiency,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
        let totalUpgradedCost = home.equipment.reduce(0) { sum, eq in
            let spec = EfficiencyDatabase.lookup(type: eq.typeEnum, age: eq.ageRangeEnum)
            return sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: spec.bestInClass,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
        let totalSavings = max(totalCurrentCost - totalUpgradedCost, 0)
        let taxCredits = UpgradeEngine.aggregateTaxCredits(from: allUpgradesByEquipment.map(\.upgrades))

        // Header
        result.append(styled("DEZENIT HOME ENERGY REPORT\n", style: .title))
        result.append(styled("\n", style: .body))

        // Summary
        result.append(styled("Home: ", style: .label))
        result.append(styled("\(home.name.isEmpty ? "Unnamed Home" : home.name)\n", style: .body))
        if let addr = home.address {
            result.append(styled("Address: ", style: .label))
            result.append(styled("\(addr)\n", style: .body))
        }
        if home.computedTotalSqFt > 0 {
            result.append(styled("Total Area: ", style: .label))
            result.append(styled("\(Int(home.computedTotalSqFt)) sq ft\n", style: .body))
        }
        result.append(styled("Climate Zone: ", style: .label))
        result.append(styled("\(home.climateZoneEnum.rawValue)\n", style: .body))
        result.append(styled("Rooms: ", style: .label))
        result.append(styled("\(home.rooms.count)    ", style: .body))
        result.append(styled("Equipment: ", style: .label))
        result.append(styled("\(home.equipment.count)\n", style: .body))
        result.append(styled("Efficiency Grade: ", style: .label))
        result.append(styled("\(grade.rawValue)\n", style: .gradeValue))
        result.append(styled("\(grade.summary)\n\n", style: .caption))

        // Energy Cost
        if !home.equipment.isEmpty {
            result.append(styled("ENERGY COST ESTIMATE\n", style: .heading))
            result.append(styled("Current Annual Cost: $\(Int(totalCurrentCost))/yr\n", style: .body))
            if totalSavings > 0 {
                result.append(styled("After All Upgrades: $\(Int(totalUpgradedCost))/yr\n", style: .body))
                result.append(styled("Potential Annual Savings: $\(Int(totalSavings))/yr\n", style: .highlight))
            }
            result.append(styled("\n", style: .body))
        }

        // Energy Breakdown
        let bp = profile.breakdown
        if bp.count > 1 {
            result.append(styled("ENERGY BREAKDOWN\n", style: .heading))
            for cat in bp {
                result.append(styled("  \(cat.name): $\(Int(cat.annualCost))/yr (\(Int(cat.percentage))%)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Bill Comparison
        if let comparison = profile.billComparison {
            result.append(styled("BILL VS. ESTIMATE\n", style: .heading))
            result.append(styled("Actual (from bills): \(Int(comparison.billBasedAnnualKWh)) kWh/yr\n", style: .body))
            result.append(styled("Estimated (from audit): \(Int(comparison.estimatedAnnualKWh)) kWh/yr\n", style: .body))
            result.append(styled("Accuracy: \(comparison.accuracyLabel) (\(Int(comparison.gapPercentage))% gap)\n\n", style: .body))
        }

        // Envelope
        if let envScore = profile.envelopeScore {
            result.append(styled("BUILDING ENVELOPE: \(envScore.grade) (\(Int(envScore.score))/100)\n", style: .heading))
            for detail in envScore.details {
                result.append(styled("  \(detail)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Appliance highlights
        if !profile.topConsumers.isEmpty {
            result.append(styled("TOP ENERGY CONSUMERS\n", style: .heading))
            for (i, consumer) in profile.topConsumers.enumerated() {
                result.append(styled("  #\(i + 1) \(consumer.name): $\(Int(consumer.annualCost))/yr\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Upgrades
        if !allUpgradesByEquipment.isEmpty {
            result.append(styled("PRIORITIZED UPGRADES\n", style: .heading))
            for item in allUpgradesByEquipment {
                if let best = item.upgrades.first(where: { $0.tier == .best }) {
                    let pb = best.paybackYears.map { String(format: "%.1f yr payback", $0) } ?? "N/A"
                    let credit = best.taxCreditEligible ? " (tax credit: $\(Int(best.taxCreditAmount)))" : ""
                    result.append(styled("  \(item.equipment.typeEnum.rawValue): \(best.title)\n", style: .label))
                    result.append(styled("    $\(Int(best.annualSavings))/yr savings, $\(Int(best.costLow))-$\(Int(best.costHigh)) cost, \(pb)\(credit)\n", style: .body))
                }
            }
            result.append(styled("\n", style: .body))
        }

        // Quick Wins
        if !homeRecs.isEmpty {
            result.append(styled("QUICK WINS & TIPS\n", style: .heading))
            for rec in homeRecs {
                let savings = rec.estimatedSavings.map { " (\($0))" } ?? ""
                result.append(styled("  \(rec.title)\(savings)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Tax Credits
        if taxCredits.grandTotal > 0 {
            result.append(styled("TAX CREDITS\n", style: .heading))
            if taxCredits.total25C > 0 { result.append(styled("  Section 25C: $\(Int(taxCredits.total25C))\n", style: .body)) }
            if taxCredits.total25D > 0 { result.append(styled("  Section 25D: $\(Int(taxCredits.total25D))\n", style: .body)) }
            result.append(styled("  Total Potential Credits: $\(Int(taxCredits.grandTotal))\n\n", style: .highlight))
        }

        // Footer
        result.append(styled("\nGenerated by Dezenit | Built by Omer Bese\n", style: .caption))

        return result
    }

    // MARK: - Drawing

    private static func drawPages(context: UIGraphicsPDFRendererContext, text: NSAttributedString, pageRect: CGRect) {
        let textRect = CGRect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: pageHeight - 2 * margin
        )

        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        var currentRange = CFRange(location: 0, length: 0)
        var pageNumber = 1

        while currentRange.location < text.length {
            context.beginPage()

            // Draw header line on each page
            let headerY: CGFloat = 30
            let headerFont = UIFont.systemFont(ofSize: 8, weight: .regular)
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.gray
            ]
            let headerText = "Dezenit Home Energy Report — Page \(pageNumber)"
            (headerText as NSString).draw(at: CGPoint(x: margin, y: headerY), withAttributes: headerAttrs)

            // Draw content
            let path = CGPath(rect: textRect, transform: nil)
            _ = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            let ctx = context.cgContext
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageRect.height)
            ctx.scaleBy(x: 1.0, y: -1.0)

            let flippedRect = CGRect(
                x: textRect.origin.x,
                y: pageRect.height - textRect.origin.y - textRect.height,
                width: textRect.width,
                height: textRect.height
            )
            let flippedPath = CGPath(rect: flippedRect, transform: nil)
            let flippedFrame = CTFramesetterCreateFrame(framesetter, currentRange, flippedPath, nil)
            CTFrameDraw(flippedFrame, ctx)

            ctx.restoreGState()

            let visibleRange = CTFrameGetVisibleStringRange(flippedFrame)
            currentRange = CFRange(location: visibleRange.location + visibleRange.length, length: 0)
            pageNumber += 1
        }
    }

    // MARK: - Styles

    private enum TextStyle {
        case title, heading, label, body, caption, highlight, gradeValue
    }

    private static func styled(_ string: String, style: TextStyle) -> NSAttributedString {
        let font: UIFont
        let color: UIColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2

        switch style {
        case .title:
            font = UIFont.systemFont(ofSize: 22, weight: .bold)
            color = UIColor(red: 0.102, green: 0.478, blue: 0.298, alpha: 1) // accent
            paragraphStyle.lineSpacing = 6
        case .heading:
            font = UIFont.systemFont(ofSize: 14, weight: .bold)
            color = UIColor(red: 0.102, green: 0.478, blue: 0.298, alpha: 1) // accent
            paragraphStyle.paragraphSpacingBefore = 8
        case .label:
            font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            color = .darkGray
        case .body:
            font = UIFont.systemFont(ofSize: 11, weight: .regular)
            color = .black
        case .caption:
            font = UIFont.systemFont(ofSize: 9, weight: .regular)
            color = .gray
        case .highlight:
            font = UIFont.systemFont(ofSize: 11, weight: .bold)
            color = UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1) // green
        case .gradeValue:
            font = UIFont.systemFont(ofSize: 18, weight: .bold)
            color = UIColor(red: 0.102, green: 0.478, blue: 0.298, alpha: 1)
        }

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
    }
}
