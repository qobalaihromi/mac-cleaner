import Foundation

public struct ManifestEntry: Codable {
    public let originalPath: String
    public let trashedPath: String
    public let sizeBytes: Int64
    public let movedAt: Date
}

public struct CleanupManifest: Codable {
    public let id: UUID
    public let createdAt: Date
    public let entries: [ManifestEntry]
}

public protocol ManifestWriting {
    func write(entries: [ManifestEntry]) throws -> String
}

public struct ManifestWriter: ManifestWriting {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func write(entries: [ManifestEntry]) throws -> String {
        let manifest = CleanupManifest(id: UUID(), createdAt: Date(), entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(manifest)
        let directory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".mac-cleaner/manifests")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "cleanup-\(formatter.string(from: Date())).json"

        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL.path
    }
}
