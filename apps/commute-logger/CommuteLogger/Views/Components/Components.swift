import SwiftUI

extension Color {
    // Status palette: reserved for delay severity and always paired with an icon and label.
    static let statusGood = Color(red: 12 / 255, green: 163 / 255, blue: 12 / 255)
    static let statusWarning = Color(red: 250 / 255, green: 178 / 255, blue: 25 / 255)
    static let statusCritical = Color(red: 208 / 255, green: 59 / 255, blue: 59 / 255)
}

extension DelayLevel {
    var color: Color {
        switch self {
        case .onTime: .statusGood
        case .minor: .statusWarning
        case .severe: .statusCritical
        }
    }
}

/// Grouped-background card used for every dashboard section.
struct Card<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var caption: String?
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Icon + label badge for a delay level, so severity never relies on color alone.
struct DelayBadge: View {
    var level: DelayLevel
    var delta: TimeInterval

    var body: some View {
        Label(Format.delta(delta), systemImage: level.systemImage)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.18), in: Capsule())
            .overlay(alignment: .leading) {
                Capsule().fill(level.color).frame(width: 3).padding(.vertical, 4).padding(.leading, 2)
            }
            .accessibilityLabel("\(level.title), \(Format.delta(delta)) versus typical")
    }
}

/// Binding helper: minutes after midnight <-> Date, for hour-and-minute DatePickers.
extension Binding where Value == Int {
    var asTimeOfDay: Binding<Date> {
        Binding<Date>(
            get: { Format.dateOnReferenceDay(minutes: Double(wrappedValue)) },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}

