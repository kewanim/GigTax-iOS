import SwiftUI
import CoreLocation

/// CLLocationManager isn't Observable, so SwiftUI's `.onChange` can't detect when the
/// system permission prompt is answered — this delegate bridges that callback into @State.
private final class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
    var onChange: ((CLAuthorizationStatus) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onChange?(manager.authorizationStatus)
    }
}

struct PermissionsView: View {
    let onFinish: () -> Void
    let onBack: () -> Void

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var locationManager = CLLocationManager()
    @State private var delegate = LocationPermissionDelegate()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    content
                        .frame(minHeight: geo.size.height)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Back", action: onBack) }
            }
        }
        .onAppear {
            locationStatus = locationManager.authorizationStatus
            delegate.onChange = { status in locationStatus = status }
            locationManager.delegate = delegate
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "location.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 12) {
                    Text("Step 4 of 4")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Text("Enable Trip Tracking")
                        .font(.title2).fontWeight(.bold)
                    Text("GigTax needs location access to automatically track your trips — including the deadhead miles Uber and Lyft don't count.")
                        .font(.body).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    permissionRow(icon: "car.fill", color: .blue,
                                  title: "Auto trip detection",
                                  detail: "Starts when you drive, stops when you park")
                    permissionRow(icon: "dollarsign.circle.fill", color: .green,
                                  title: "Real fuel cost per trip",
                                  detail: "GPS speed data → city vs. highway MPG")
                    permissionRow(icon: "shield.fill", color: .orange,
                                  title: "IRS mileage log",
                                  detail: "Every mile documented for your protection")
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                if locationStatus == .authorizedAlways {
                    Label("Location access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else if locationStatus == .denied || locationStatus == .restricted {
                    VStack(spacing: 8) {
                        Text("Location access denied. Enable it in Settings to use trip tracking.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button(action: requestLocation) {
                        Text("Allow Location Access")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }

                Button(action: onFinish) {
                    Text(locationStatus == .authorizedAlways ? "Finish Setup" : "Skip for Now")
                        .font(.subheadline)
                        .foregroundStyle(locationStatus == .authorizedAlways ? Color.accentColor : .secondary)
                }
            }
            .padding(.bottom, 48)
        }
    }

    private func requestLocation() {
        locationManager.requestAlwaysAuthorization()
    }

    private func permissionRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PermissionsView(onFinish: {}, onBack: {})
}
