import Foundation

enum Format {
    /// "34 min", "1 h 05 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if abs(minutes) < 60 { return "\(minutes) min" }
        return String(format: "%d h %02d min", minutes / 60, abs(minutes % 60))
    }

    /// "+6 min" / "−3 min" relative to typical.
    static func delta(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes == 0 { return "±0 min" }
        return minutes > 0 ? "+\(minutes) min" : "−\(abs(minutes)) min"
    }

    /// Minutes after midnight → "8:15 AM" in the user's locale.
    static func timeOfDay(_ minutes: Int) -> String {
        let normalized = ((minutes % 1440) + 1440) % 1440
        let date = Calendar.current.date(bySettingHour: normalized / 60, minute: normalized % 60, second: 0, of: referenceDay) ?? referenceDay
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    /// A fixed day used to place times of day on a chart axis.
    static let referenceDay: Date = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    static func dateOnReferenceDay(minutes: Double) -> Date {
        referenceDay.addingTimeInterval(minutes * 60)
    }
}
