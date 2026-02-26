import SwiftUI

struct WindowQuestionnaireView: View {
    @Binding var window: WindowInfo
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var snapshot: WindowInfo?
    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                TabView(selection: $step) {
                    paneTypeStep.tag(0)
                    frameMaterialStep.tag(1)
                    conditionStep.tag(2)
                    directionSizeStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Window Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if snapshot == nil { snapshot = window }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if let snapshot { window = snapshot }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step == totalSteps - 1 {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Constants.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Constants.accentColor : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Step 1: Pane Type

    private var paneTypeStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    title: "How many panes of glass?",
                    subtitle: PaneType.single.tip
                )

                ForEach(PaneType.selectableCases) { pane in
                    selectionCard(
                        selected: window.paneType == pane,
                        icon: paneIcon(pane),
                        title: pane.label,
                        detail: pane.description
                    ) {
                        window.paneType = pane
                    }
                }
            }
            .padding(20)
        }
    }

    private func paneIcon(_ pane: PaneType) -> String {
        switch pane {
        case .notAssessed: return "questionmark.square"
        case .single: return "1.square"
        case .double: return "2.square"
        case .triple: return "3.square"
        }
    }

    // MARK: - Step 2: Frame Material

    private var frameMaterialStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    title: "What's the frame made of?",
                    subtitle: "Metal frames feel cold in winter. Vinyl and fiberglass are warmer to the touch."
                )

                ForEach(FrameMaterial.selectableCases) { material in
                    selectionCard(
                        selected: window.frameMaterial == material,
                        icon: material.icon,
                        title: material.rawValue,
                        detail: material.description
                    ) {
                        window.frameMaterial = material
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 3: Condition

    private var conditionStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    title: "What condition is the window in?",
                    subtitle: "Check for drafts, fog between panes, and whether it closes tight."
                )

                ForEach(WindowCondition.selectableCases) { condition in
                    selectionCard(
                        selected: window.condition == condition,
                        icon: conditionIcon(condition),
                        title: condition.rawValue,
                        detail: condition.description
                    ) {
                        window.condition = condition
                    }
                }

                // U-factor preview
                uFactorPreview
            }
            .padding(20)
        }
    }

    private func conditionIcon(_ condition: WindowCondition) -> String {
        switch condition {
        case .notAssessed: return "questionmark.circle"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }

    // MARK: - Step 4: Direction + Size

    private var directionSizeStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    title: "Direction and size",
                    subtitle: "Which way does this window face, and how big is it?"
                )

                // Direction picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Direction")
                        .font(.subheadline.bold())

                    HStack(spacing: 10) {
                        ForEach(CardinalDirection.allCases) { dir in
                            Button {
                                window.direction = dir
                            } label: {
                                VStack(spacing: 4) {
                                    Text(dir.rawValue)
                                        .font(.title3.bold())
                                    Text(dir.fullName)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    window.direction == dir
                                        ? Constants.accentColor
                                        : Color.gray.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(window.direction == dir ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Size picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Size")
                        .font(.subheadline.bold())

                    ForEach(WindowSize.allCases) { size in
                        Button {
                            window.size = size
                        } label: {
                            HStack {
                                Image(systemName: sizeIcon(size))
                                    .font(.title2)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(size.rawValue)
                                        .font(.subheadline.bold())
                                    Text(size.description)
                                        .font(.caption)
                                }
                                Spacer()
                                if window.size == size {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Constants.accentColor)
                                }
                            }
                            .padding(12)
                            .background(
                                window.size == size
                                    ? Constants.accentColor.opacity(0.1)
                                    : Color.gray.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // BTU impact preview
                btuPreview
            }
            .padding(20)
        }
    }

    private func sizeIcon(_ size: WindowSize) -> String {
        switch size {
        case .small: return "rectangle"
        case .medium: return "rectangle.fill"
        case .large: return "rectangle.inset.filled"
        }
    }

    // MARK: - Previews

    private var uFactorPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(Constants.accentColor)
                Text("Effective U-Factor")
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "%.2f", window.effectiveUFactor))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(uFactorColor)
            }
            Text("Lower is better. Single pane aluminum: ~1.43. Triple pane composite: ~0.20.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(uFactorColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var uFactorColor: Color {
        let u = window.effectiveUFactor
        if u < 0.35 { return Constants.statusSuccess }
        if u < 0.60 { return Constants.statusWarning }
        return .red
    }

    private var btuPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flame")
                    .foregroundStyle(Constants.accentColor)
                Text("Estimated Heat Gain")
                    .font(.subheadline.bold())
                Spacer()
                Text("+\(Int(window.heatGainBTU).formatted()) BTU")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Constants.accentColor)
            }
        }
        .padding(14)
        .background(Constants.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if step < totalSteps - 1 {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Constants.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Shared Components

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionCard(selected: Bool, icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(selected ? .white : Constants.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        selected ? Constants.accentColor : Constants.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Constants.accentColor)
                }
            }
            .padding(14)
            .background(
                selected ? Constants.accentColor.opacity(0.08) : Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Constants.accentColor : Color.gray.opacity(0.2), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
