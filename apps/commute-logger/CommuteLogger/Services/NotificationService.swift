import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// "Morning commute logged — 38 min, 6 min slower than usual."
    static func notifyLogged(direction: CommuteDirection, duration: TimeInterval, typical: TimeInterval?) {
        let content = UNMutableNotificationContent()
        content.title = direction == .toWork ? "Commute to work logged" : "Commute home logged"
        var body = "Door to door: \(Format.duration(duration))."
        if let typical {
            let diff = duration - typical
            if abs(diff) < 60 {
                body += " Right on your usual time."
            } else {
                body += " \(Format.duration(abs(diff))) \(diff > 0 ? "slower" : "faster") than usual."
            }
        }
        body += " Open the trip to tag what slowed you down."
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: "logged-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static let leaveByPrefix = "leave-by-"

    /// Repeating weekday reminders ten minutes before the recommended departure.
    static func scheduleLeaveBy(minutes: Int?, workdays: Set<Int>, arriveBy: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "\(leaveByPrefix)\($0)" })
        guard let minutes else { return }
        let remindAt = max(0, minutes - 10)
        for weekday in workdays {
            let content = UNMutableNotificationContent()
            content.title = "Leave by \(Format.timeOfDay(minutes))"
            content.body = "That gets you to work by \(Format.timeOfDay(arriveBy)) on most days."
            var components = DateComponents()
            components.weekday = weekday
            components.hour = remindAt / 60
            components.minute = remindAt % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: "\(leaveByPrefix)\(weekday)", content: content, trigger: trigger))
        }
    }
}
