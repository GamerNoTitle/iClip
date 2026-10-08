import Foundation

public enum ClipboardKind: String, Codable, Sendable {
    case text, files, image
}

/// A captured clipboard value. Text is kept exactly as copied for text entries.
public struct ClipboardEntry: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var isPinned: Bool
    public var kind: ClipboardKind
    public var filePaths: [String]
    public var imageData: Data?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        kind: ClipboardKind = .text,
        filePaths: [String] = [],
        imageData: Data? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.kind = kind
        self.filePaths = filePaths
        self.imageData = imageData
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, createdAt, isPinned, kind, filePaths, imageData
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            text: try container.decode(String.self, forKey: .text),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            isPinned: try container.decode(Bool.self, forKey: .isPinned),
            kind: try container.decodeIfPresent(ClipboardKind.self, forKey: .kind) ?? .text,
            filePaths: try container.decodeIfPresent([String].self, forKey: .filePaths) ?? [],
            imageData: try container.decodeIfPresent(Data.self, forKey: .imageData)
        )
    }
}
