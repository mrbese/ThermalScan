import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var didGetStarted = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                page(
                    icon: "house.fill",
                    title: "Your Home Energy Audit",
                    subtitle: "Scan rooms with LiDAR, log HVAC equipment, and get a full efficiency grade with upgrade recommendations — all from your iPhone.",
                    tag: 0
                )
                page(
                    icon: "camera.fill",
                    title: "What You'll Need",
                    subtitle: "A camera for equipment labels, LiDAR for room scanning (optional), and a recent utility bill for cost calibration (also optional).",
                    tag: 1
                )
                page(
                    icon: "icloud.fill",
                    title: "Your Data, Your Devices",
                    subtitle: "Syncs securely via iCloud across all your Apple devices. No third-party servers — your data stays in your Apple account.",
                    tag: 2
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if currentPage == 2 {
                Button {
                    didGetStarted = true
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            } else {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Constants.accentColor.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .background(Constants.secondaryColor.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: didGetStarted)
    }

    private func page(icon: String, title: String, subtitle: String, tag: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(Constants.accentColor)

            Text(title)
                .font(.title.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .tag(tag)
    }
}
