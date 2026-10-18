import SwiftData

/// One store shared by the UI and the background tracker, which may run before any scene exists.
enum Persistence {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Commute.self)
        } catch {
            fatalError("Could not open the commute store: \(error)")
        }
    }()
}
