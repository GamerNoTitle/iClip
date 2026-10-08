import Foundation
import Testing
import iClipCore

private func withStorage(_ body: (URL) throws -> Void) throws {
    let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent(".persistence-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory.appendingPathComponent("nested/history.json"))
}

@Test func missingFileLoadsEmptyHistory() throws {
    try withStorage { url in
        let state = try Persistence(url: url).load()
        #expect(state.entries.isEmpty)
        #expect(state.limit == 1000)
    }
}

@Test func persistenceRoundTripAndAtomicReplacement() throws {
    try withStorage { url in
        let persistence = Persistence(url: url)
        let pinned = ClipboardEntry(text: "keep\n whitespace  ", createdAt: Date(timeIntervalSince1970: 456), isPinned: true)
        var state = HistoryState(entries: [pinned], limit: 7)
        state.capture("other")
        try persistence.save(state)
        #expect(try persistence.load() == state)
        state.clearUnpinned()
        try persistence.save(state)
        #expect(try persistence.load() == state)
        #expect(try persistence.loadEntries() == [pinned])
        let contents = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        #expect(contents.map(\.lastPathComponent) == ["history.json"])
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(object?["entries"] != nil)
    }
}

@Test func malformedJSONIsReported() throws {
    try withStorage { url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not valid json".utf8).write(to: url)
        #expect(throws: (any Error).self) { try Persistence(url: url).load() }
    }
}

@Test func unlimitedLimitAndPinsSurviveRestart() throws {
    try withStorage { url in
        let pin = ClipboardEntry(text: "permanent", isPinned: true)
        let ordinary = (0..<1200).map { ClipboardEntry(text: "entry-\($0)") }
        let state = HistoryState(entries: ordinary + [pin], limit: 0)
        try Persistence(url: url).save(state)
        var restored = try Persistence(url: url).load()
        #expect(restored.limit == 0)
        #expect(restored.entries.count == 1201)
        #expect(restored.entries.first?.id == pin.id)
        restored.limit = 10
        try Persistence(url: url).save(restored)
        let secondRestart = try Persistence(url: url).load()
        #expect(secondRestart.limit == 10)
        #expect(secondRestart.entries.count == 11)
        #expect(secondRestart.entries.first?.id == pin.id)
    }
}

@Test func typedPayloadsPinsAndDeduplicationSurviveRestart() throws {
    try withStorage { url in
        let persistence = Persistence(url: url)
        var state = HistoryState(limit: 0)
        state.capture("图片")
        state.capture("/a\n/b")
        state.captureFiles(["/a", "/b"])
        state.captureImage(Data([0, 1, 255]))
        let files = try #require(state.entries.first { $0.kind == .files })
        let image = try #require(state.entries.first { $0.kind == .image })
        state.togglePin(files.id)
        state.togglePin(image.id)
        try persistence.save(state)
        var restored = try persistence.load()
        #expect(restored == state)
        restored.captureFiles(["/a", "/b"])
        restored.captureImage(Data([0, 1, 255]))
        #expect(restored.entries.count == 4)
        #expect(restored.entries.first { $0.kind == .files }?.id == files.id)
        #expect(restored.entries.first { $0.kind == .image }?.id == image.id)
        #expect(restored.entries.prefix(2).allSatisfy { $0.isPinned })
        try persistence.save(restored)
        #expect(try persistence.load() == restored)
        #expect(try persistence.loadEntries() == restored.entries)
    }
}

@Test func legacyHistoryJSONLoadsWithTextAndDefaultLimit() throws {
    try withStorage { url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let id = UUID()
        let json = """
        {"entries":[{"id":"\(id.uuidString)","text":"legacy","createdAt":0,"isPinned":true}]}
        """
        try Data(json.utf8).write(to: url)
        let persistence = Persistence(url: url)
        let state = try persistence.load()
        #expect(state.limit == 1000)
        let entry = try #require(state.entries.first)
        #expect(entry.id == id)
        #expect(entry.kind == .text)
        #expect(entry.filePaths.isEmpty)
        #expect(entry.imageData == nil)
        #expect(entry.isPinned)
        try persistence.save(state)
        #expect(try persistence.load() == state)
    }
}

@Test func typedJSONNormalizationPreservesImageWithEmptyDisplayText() throws {
    let old = ClipboardEntry(text: "图片", createdAt: .distantPast, isPinned: true,
                             kind: .image, imageData: Data([7]))
    let new = ClipboardEntry(text: "", kind: .image, imageData: Data([7]))
    let text = ClipboardEntry(text: "图片")
    let data = try JSONEncoder().encode(["entries": [old, new, text]])
    let state = try JSONDecoder().decode(HistoryState.self, from: data)
    #expect(state.entries.count == 2)
    #expect(state.entries.first?.id == new.id)
    #expect(state.entries.first?.isPinned == true)
    #expect(state.entries.first?.imageData == Data([7]))
    #expect(state.entries.last?.kind == .text)
}

@Test func entryConvenienceMethodsRoundTrip() throws {
    try withStorage { url in
        let entries = [ClipboardEntry(text: "one", isPinned: true)]
        let persistence = Persistence(url: url)
        try persistence.save(entries)
        #expect(try persistence.loadEntries() == entries)
    }
}
