import Foundation
import Testing
import iClipCore

@Test func defaultsAndEmptyCapture() {
    var state = HistoryState()
    #expect(state.entries.isEmpty)
    #expect(state.limit == 1000)
    state.capture("")
    #expect(state.entries.isEmpty)
    state.capture(" \n\t")
    #expect(state.entries.map(\.text) == [" \n\t"])
}

@Test func capturePreservesFormattingAndExactDeduplication() {
    var state = HistoryState()
    state.capture("  hello\nworld\t ")
    state.capture("hello\nworld")
    state.capture("  hello\nworld\t ")
    #expect(state.entries.count == 2)
    #expect(state.entries.first?.text == "  hello\nworld\t ")
}

@Test func duplicateRefreshesDateAndPreservesIdentityAndPin() throws {
    let old = ClipboardEntry(text: "pinned", createdAt: .distantPast, isPinned: true)
    let newer = ClipboardEntry(text: "other", createdAt: Date(timeIntervalSince1970: 1), isPinned: true)
    var state = HistoryState(entries: [old, newer])
    state.capture("pinned")
    let refreshed = try #require(state.entries.first)
    #expect(state.entries.count == 2)
    #expect(refreshed.id == old.id)
    #expect(refreshed.isPinned)
    #expect(refreshed.createdAt > old.createdAt)
}

@Test func pinnedEntriesAreFirstAndDoNotConsumeLimit() {
    let pinned = ClipboardEntry(text: "pin", createdAt: .distantPast, isPinned: true)
    var state = HistoryState(entries: [pinned], limit: 2)
    state.capture("one")
    state.capture("two")
    state.capture("three")
    #expect(state.entries.map(\.text) == ["pin", "three", "two"])
    state.togglePin(pinned.id)
    #expect(state.entries.map(\.text) == ["three", "two"])
}

@Test func toggleRemoveAndClear() throws {
    var state = HistoryState()
    state.capture("first")
    state.capture("second")
    let first = try #require(state.entries.first(where: { $0.text == "first" }))
    let second = try #require(state.entries.first(where: { $0.text == "second" }))
    state.togglePin(first.id)
    #expect(state.entries.map(\.text) == ["first", "second"])
    #expect(state.entries.first?.isPinned == true)
    let before = state
    state.togglePin(UUID())
    state.remove(UUID())
    #expect(state == before)
    state.clearUnpinned()
    #expect(state.entries.map(\.id) == [first.id])
    state.remove(second.id)
    state.remove(first.id)
    #expect(state.entries.isEmpty)
}

@Test func zeroNegativeAndChangedLimits() {
    let pin = ClipboardEntry(text: "pin", isPinned: true)
    var state = HistoryState(entries: [pin], limit: -1)
    #expect(state.limit == 0)
    state.capture("retained")
    #expect(state.entries.map(\.text) == ["pin", "retained"])
    state.limit = 2
    state.capture("one")
    state.capture("two")
    state.limit = 1
    #expect(state.entries.map(\.text) == ["pin", "two"])
    state.limit = -10
    #expect(state.limit == 0)
    #expect(state.entries.map(\.text) == ["pin", "two"])
    state.capture("three")
    #expect(state.entries.count == 3)
}

@Test func initializerNormalizesDuplicatesWithoutLosingPins() {
    let old = ClipboardEntry(text: "same", createdAt: .distantPast, isPinned: true)
    let new = ClipboardEntry(text: "same", createdAt: Date())
    let empty = ClipboardEntry(text: "")
    let state = HistoryState(entries: [old, new, empty])
    #expect(state.entries.count == 1)
    #expect(state.entries.first?.id == new.id)
    #expect(state.entries.first?.isPinned == true)
}

@Test func defaultLimitRetainsThousandUnpinnedEntries() {
    var state = HistoryState()
    for number in 0..<1005 { state.capture(String(number)) }
    #expect(state.entries.count == 1000)
    #expect(state.entries.first?.text == "1004")
    #expect(!state.entries.contains(where: { $0.text == "0" }))
}

@Test func incrementalCaptureMatchesNormalizedOrdering() {
    let future = ClipboardEntry(text: "future", createdAt: .distantFuture)
    let pinned = ClipboardEntry(text: "pin", createdAt: .distantPast, isPinned: true)
    var state = HistoryState(entries: [future, pinned], limit: 20)
    for index in 0..<200 {
        let text = "item-\(index % 37)"
        state.capture(text)
        if index % 11 == 0, let entry = state.entries.last { state.togglePin(entry.id) }
        let normalized = HistoryState(entries: state.entries, limit: state.limit)
        #expect(state == normalized)
        #expect(Set(state.entries.map(\.text)).count == state.entries.count)
    }
}

@Test func typedCaptureKeepsDistinctPayloadsAndKinds() {
    var state = HistoryState()
    state.captureFiles(["/a/same", "/b/same"])
    state.captureFiles(["/b/same", "/a/same"])
    state.captureFiles(["/a/same\n/b/same"])
    state.capture("/a/same\n/b/same")
    state.capture("图片")
    state.captureImage(Data([1, 2, 3]))
    state.captureImage(Data([1, 2, 4]))
    state.captureFiles(["/a/same", "/b/same"])
    state.captureImage(Data([1, 2, 3]))
    #expect(state.entries.count == 7)
    #expect(state.entries.filter { $0.kind == .text }.count == 2)
    #expect(state.entries.filter { $0.kind == .files }.count == 3)
    #expect(state.entries.filter { $0.kind == .image }.count == 2)
    #expect(state.entries.first?.text == "图片")
    #expect(state.entries.first?.imageData == Data([1, 2, 3]))
    #expect(state.entries.first { $0.kind == .files }?.text == "/a/same\n/b/same")
}

@Test func typedRecapturePreservesIdentityPinAndRefreshesDate() throws {
    let files = ClipboardEntry(text: "/a\n/b", createdAt: .distantPast,
                               isPinned: true, kind: .files, filePaths: ["/a", "/b"])
    let image = ClipboardEntry(text: "图片", createdAt: .distantPast,
                               isPinned: true, kind: .image, imageData: Data([1, 2]))
    var state = HistoryState(entries: [files, image], limit: 1)
    state.captureFiles(["/a", "/b"])
    state.captureImage(Data([1, 2]))
    state.capture("one")
    state.captureImage(Data([3]))
    let refreshedFiles = try #require(state.entries.first { $0.id == files.id })
    let refreshedImage = try #require(state.entries.first { $0.id == image.id })
    #expect(refreshedFiles.isPinned)
    #expect(refreshedImage.isPinned)
    #expect(refreshedFiles.createdAt > files.createdAt)
    #expect(refreshedImage.createdAt > image.createdAt)
    #expect(state.entries.count == 3)
    #expect(state.entries.prefix(2).allSatisfy { $0.isPinned })
    #expect(state.entries.last?.imageData == Data([3]))
    state.clearUnpinned()
    #expect(Set(state.entries.map(\.id)) == Set([files.id, image.id]))
}

@Test func typedNormalizationUsesPayloadAndRetainsPins() {
    let oldFiles = ClipboardEntry(text: "old", createdAt: .distantPast,
                                  isPinned: true, kind: .files, filePaths: ["/a"])
    let newFiles = ClipboardEntry(text: "/a", kind: .files, filePaths: ["/a"])
    let oldImage = ClipboardEntry(text: "图片", createdAt: .distantPast,
                                  isPinned: true, kind: .image, imageData: Data([1]))
    let newImage = ClipboardEntry(text: "", kind: .image, imageData: Data([1]))
    let text = ClipboardEntry(text: "/a")
    let state = HistoryState(entries: [oldFiles, newFiles, oldImage, newImage, text,
        ClipboardEntry(text: "invalid", kind: .files),
        ClipboardEntry(text: "invalid", kind: .image),
        ClipboardEntry(text: "invalid", kind: .image, imageData: Data())])
    #expect(state.entries.count == 3)
    #expect(state.entries.first { $0.kind == .files }?.id == newFiles.id)
    #expect(state.entries.first { $0.kind == .image }?.id == newImage.id)
    #expect(state.entries.prefix(2).allSatisfy { $0.isPinned })
    #expect(state.entries.last?.id == text.id)
}

@Test func emptyTypedCapturesAreIgnoredAndZeroLimitRemainsUnlimited() {
    var state = HistoryState(limit: 0)
    state.captureFiles([])
    state.captureFiles([""])
    state.captureImage(Data())
    #expect(state.entries.isEmpty)
    for index in 0..<1005 { state.captureFiles(["/file-\(index)"]) }
    state.captureImage(Data([1]))
    #expect(state.entries.count == 1006)
    #expect(state.limit == 0)
}

@Test func clipboardEntryDefaultsAndLegacyJSON() throws {
    let id = UUID()
    let json = """
    {"id":"\(id.uuidString)","text":"legacy","createdAt":123,"isPinned":true}
    """
    let entry = try JSONDecoder().decode(ClipboardEntry.self, from: Data(json.utf8))
    #expect(entry.id == id)
    #expect(entry.kind == .text)
    #expect(entry.filePaths.isEmpty)
    #expect(entry.imageData == nil)
    #expect(entry.isPinned)
    #expect(entry.createdAt == Date(timeIntervalSinceReferenceDate: 123))
    let defaults = ClipboardEntry(text: "text")
    #expect(defaults.kind == .text)
    #expect(defaults.filePaths.isEmpty)
    #expect(defaults.imageData == nil)
}

@Test func typedClipboardEntryCodableRoundTrip() throws {
    let entries = [
        ClipboardEntry(text: "/a\n/b", kind: .files, filePaths: ["/a", "/b"]),
        ClipboardEntry(text: "图片", isPinned: true, kind: .image, imageData: Data([0, 255, 1]))
    ]
    let data = try JSONEncoder().encode(entries)
    #expect(try JSONDecoder().decode([ClipboardEntry].self, from: data) == entries)
}

@Test func clipboardEntryCodableRoundTrip() throws {
    let entry = ClipboardEntry(text: "formatted\n text", createdAt: Date(timeIntervalSince1970: 123), isPinned: true)
    let data = try JSONEncoder().encode(entry)
    #expect(try JSONDecoder().decode(ClipboardEntry.self, from: data) == entry)
}
