import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if settings.hasCompletedOnboarding {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                HistoryView()
                    .tabItem { Label("Trips", systemImage: "list.bullet") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        } else {
            OnboardingView()
        }
    }
}
