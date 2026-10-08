import Foundation

/// Clipboard history, newest first within the pinned and unpinned sections.
/// The limit applies only to unpinned entries; pinned entries are never evicted.
/// A limit of zero means unlimited history; negative limits are normalized to zero.
public struct HistoryState: Codable, Sendable, Equatable {
    public private(set) var entries: [ClipboardEntry]
    public var limit: Int {
        didSet {
            limit = max(0, limit)
            trimToLimit()
        }
    }

    public init(entries: [ClipboardEntry] = [], limit: Int = 1000) {
        self.entries = entries
        self.limit = max(0, limit)
        normalize()
    }

    /// Recapturing a value preserves its identity and pin, and refreshes its date.
    /// Only the empty string is ignored; whitespace and formatting are preserved.
    public mutating func capture(_ text: String) {
        captureEntry(ClipboardEntry(text: text))
    }

    /// Paths are preserved in their original order, without basename-only matching.
    public mutating func captureFiles(_ paths: [String]) {
        captureEntry(ClipboardEntry(
            text: paths.joined(separator: "\n"), kind: .files, filePaths: paths
        ))
    }

    public mutating func captureImage(_ data: Data) {
        captureEntry(ClipboardEntry(text: "图片", kind: .image, imageData: data))
    }

    private mutating func captureEntry(_ captured: ClipboardEntry) {
        guard let key = payloadKey(for: captured) else { return }
        var entry: ClipboardEntry
        if let index = entries.firstIndex(where: { payloadKey(for: $0) == key }) {
            entry = entries.remove(at: index)
            entry.text = captured.text
            entry.createdAt = captured.createdAt
        } else {
            entry = captured
        }
        // The remaining array is already normalized. Insert into its sorted
        // section instead of hashing and sorting the entire history on every copy.
        let insertion = entries.firstIndex {
            if $0.isPinned != entry.isPinned { return entry.isPinned }
            return $0.createdAt < entry.createdAt
        } ?? entries.endIndex
        entries.insert(entry, at: insertion)
        trimToLimit()
    }

    public mutating func togglePin(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isPinned.toggle()
        normalize()
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func clearUnpinned() {
        entries.removeAll { !$0.isPinned }
    }

    /// A typed key prevents display text from conflating different payloads.
    private enum PayloadKey: Hashable {
        case text(String)
        case files([String])
        case image(Data)
    }

    private func payloadKey(for entry: ClipboardEntry) -> PayloadKey? {
        switch entry.kind {
        case .text:
            return entry.text.isEmpty ? nil : .text(entry.text)
        case .files:
            guard !entry.filePaths.isEmpty,
                  entry.filePaths.allSatisfy({ !$0.isEmpty }) else { return nil }
            return .files(entry.filePaths)
        case .image:
            guard let data = entry.imageData, !data.isEmpty else { return nil }
            return .image(data)
        }
    }

    private mutating func normalize() {
        // Normalize restored/imported histories as well as newly captured values.
        var unique: [ClipboardEntry] = []
        var indices: [PayloadKey: Int] = [:]
        for entry in entries {
            guard let key = payloadKey(for: entry) else { continue }
            if let index = indices[key] {
                let pinned = unique[index].isPinned || entry.isPinned
                if entry.createdAt > unique[index].createdAt {
                    unique[index] = entry
                }
                unique[index].isPinned = pinned
            } else {
                indices[key] = unique.count
                unique.append(entry)
            }
        }
        // Retain source order for ties rather than relying on sorting stability.
        let sorted = unique.enumerated().sorted { lhs, rhs in
            if lhs.element.isPinned != rhs.element.isPinned {
                return lhs.element.isPinned
            }
            if lhs.element.createdAt != rhs.element.createdAt {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
        entries = sorted
        trimToLimit()
    }

    private mutating func trimToLimit() {
        guard limit > 0 else { return }
        let pinnedCount = entries.firstIndex(where: { !$0.isPinned }) ?? entries.count
        let unpinnedCount = entries.count - pinnedCount
        if unpinnedCount > limit {
            entries.removeLast(unpinnedCount - limit)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case entries, limit
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([ClipboardEntry].self, forKey: .entries)
        let limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 1000
        self.init(entries: entries, limit: limit)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
        try container.encode(limit, forKey: .limit)
    }
}
