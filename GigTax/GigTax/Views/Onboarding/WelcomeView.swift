import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(minHeight: geo.size.height)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "car.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 12) {
                    Text("Welcome to GigTax")
                        .font(.largeTitle).fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Built for Uber, Lyft, DoorDash, and delivery drivers.\nTrack every mile, maximize every deduction.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                featureRow(icon: "location.fill", color: .blue,
                           title: "Tracks all your miles",
                           subtitle: "Including deadhead miles Uber and Lyft don't count")
                featureRow(icon: "chart.bar.fill", color: .green,
                           title: "Live tax estimate",
                           subtitle: "Know what you owe before April — not after")
                featureRow(icon: "shield.fill", color: .orange,
                           title: "Audit Shield",
                           subtitle: "IRS-compliant mileage log, ready when you need it")
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 24)

            Button(action: onNext) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(onNext: {})
}
