import Foundation

/// Synchronous, atomic JSON storage. Call from a background queue in a UI app.
/// Each invocation uses its own encoder/decoder, so the value is Sendable.
/// Concurrent writes to the same URL are last-writer-wins; callers should serialize
/// saves when they need ordering guarantees.
public struct Persistence: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func save(_ state: HistoryState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// A missing file is an empty history; malformed JSON and other I/O errors
    /// are thrown so callers can report them without silently discarding data.
    public func load() throws -> HistoryState {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain,
               error.code == NSFileReadNoSuchFileError {
                return HistoryState()
            }
            throw error
        }
        return try JSONDecoder().decode(HistoryState.self, from: data)
    }

    public func save(_ entries: [ClipboardEntry]) throws {
        try save(HistoryState(entries: entries))
    }

    public func loadEntries() throws -> [ClipboardEntry] {
        try load().entries
    }
}
