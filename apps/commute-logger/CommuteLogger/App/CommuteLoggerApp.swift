import SwiftData
import SwiftUI

@main
struct CommuteLoggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppSettings.shared)
                .environment(CommuteTracker.shared)
        }
        .modelContainer(Persistence.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// iOS relaunches the app in the background for geofence and visit events, with no scene. Creating the
    /// tracker here gives Core Location a delegate to deliver those events to.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated {
            CommuteTracker.shared.refreshMonitoring()
        }
        return true
    }
}
