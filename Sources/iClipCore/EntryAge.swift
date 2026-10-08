import Foundation

public enum EntryAge: Equatable, Sendable {
    case minutesSeconds(Int, Int)
    case minutes(Int)
    case hoursMinutes(Int, Int)
    case daysHours(Int, Int)

    public init(seconds: TimeInterval) {
        let safe = seconds.isFinite ? max(0, min(seconds, Double(Int.max / 2))) : 0
        let total = Int(safe)
        if total < 300 { self = .minutesSeconds(total / 60, total % 60) }
        else if total < 3600 { self = .minutes(total / 60) }
        else if total < 86400 { self = .hoursMinutes(total / 3600, total % 3600 / 60) }
        else { self = .daysHours(total / 86400, total % 86400 / 3600) }
    }
}
