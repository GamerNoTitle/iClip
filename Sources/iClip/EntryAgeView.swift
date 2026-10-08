import SwiftUI
import iClipCore

struct EntryAgeView: View {
    let date: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(format(EntryAge(seconds: context.date.timeIntervalSince(date))))
        }
    }

    private func format(_ age: EntryAge) -> String {
        let key: String
        let values: [CVarArg]
        switch age {
        case .minutesSeconds(let minutes, let seconds):
            key = "age.minutes_seconds"; values = [minutes, seconds]
        case .minutes(let minutes):
            key = "age.minutes"; values = [minutes]
        case .hoursMinutes(let hours, let minutes):
            key = "age.hours_minutes"; values = [hours, minutes]
        case .daysHours(let days, let hours):
            key = "age.days_hours"; values = [days, hours]
        }
        let pattern = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        return String(format: pattern, locale: Locale.current, arguments: values)
    }
}
