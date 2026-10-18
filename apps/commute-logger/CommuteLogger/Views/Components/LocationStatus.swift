import CoreLocation
import SwiftUI

/// Explains the current location permission and offers the one action that moves it forward.
struct LocationPermissionRow: View {
    @Environment(CommuteTracker.self) private var tracker
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Location: \(statusTitle)").font(.subheadline.weight(.semibold))
                Text(explanation).font(.caption).foregroundStyle(.secondary)
                if let action = actionTitle {
                    Button(action) { performAction() }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusTitle: String {
        switch tracker.authorization {
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "While Using"
        case .denied: "Off"
        case .restricted: "Restricted"
        default: "Not set"
        }
    }

    private var explanation: String {
        switch tracker.authorization {
        case .authorizedAlways:
            "Trips to and from work are detected and logged automatically, even when the app is closed."
        case .authorizedWhenInUse:
            "Automatic logging needs \"Always\" so iOS can tell the app when you leave home or arrive at work."
        case .denied, .restricted:
            "Location is off, so trips can only be added by hand. Turn it on in Settings."
        default:
            "Allow location so the app can notice when you leave home and arrive at work."
        }
    }

    private var actionTitle: String? {
        switch tracker.authorization {
        case .authorizedAlways: nil
        case .notDetermined: "Allow location"
        case .authorizedWhenInUse: "Change to Always"
        default: "Open Settings"
        }
    }

    private var icon: String {
        tracker.authorization == .authorizedAlways ? "location.fill" : "location.slash"
    }

    private var tint: Color {
        tracker.authorization == .authorizedAlways ? .statusGood : .secondary
    }

    private func performAction() {
        switch tracker.authorization {
        case .notDetermined:
            tracker.requestAuthorization()
        case .authorizedWhenInUse:
            // iOS shows the upgrade prompt once; after that the only route is Settings.
            if UserDefaults.standard.bool(forKey: "askedForAlways") {
                openSettings()
            } else {
                UserDefaults.standard.set(true, forKey: "askedForAlways")
                tracker.requestAuthorization()
            }
        default:
            openSettings()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
