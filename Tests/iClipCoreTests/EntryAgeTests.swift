import Foundation
import Testing
import iClipCore

@Test func ageThresholds() {
    #expect(EntryAge(seconds: -1) == .minutesSeconds(0, 0))
    #expect(EntryAge(seconds: 0) == .minutesSeconds(0, 0))
    #expect(EntryAge(seconds: 299) == .minutesSeconds(4, 59))
    #expect(EntryAge(seconds: 300) == .minutes(5))
    #expect(EntryAge(seconds: 3599) == .minutes(59))
    #expect(EntryAge(seconds: 3600) == .hoursMinutes(1, 0))
    #expect(EntryAge(seconds: 3661) == .hoursMinutes(1, 1))
    #expect(EntryAge(seconds: 86399) == .hoursMinutes(23, 59))
    #expect(EntryAge(seconds: 86400) == .daysHours(1, 0))
    #expect(EntryAge(seconds: 90000) == .daysHours(1, 1))
}

@Test func initialSamplingPreservesExistingTimestampAcrossTypes() {
    let entries = [
        ClipboardEntry(text: "pin", createdAt: .distantPast, isPinned: true),
        ClipboardEntry(text: "/tmp/test", createdAt: .distantPast, kind: .files, filePaths: ["/tmp/test"]),
        ClipboardEntry(text: "图片", createdAt: .distantPast, kind: .image, imageData: Data([1, 2]))
    ]
    var state = HistoryState(entries: entries)
    let restored = state
    state.captureInitial(ClipboardEntry(text: "pin"))
    state.captureInitial(ClipboardEntry(text: "/tmp/test", kind: .files, filePaths: ["/tmp/test"]))
    state.captureInitial(ClipboardEntry(text: "图片", kind: .image, imageData: Data([1, 2])))
    #expect(state == restored)
    state.captureInitial(ClipboardEntry(text: "new"))
    #expect(state.entries.count == 4)
}
