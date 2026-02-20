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

public protocol ManifestReading {
    func readManifest(path: String) throws -> CleanupManifest
    func latestManifestPath() throws -> String?
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

public struct ManifestReader: ManifestReading {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func readManifest(path: String) throws -> CleanupManifest {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CleanupManifest.self, from: data)
    }

    public func latestManifestPath() throws -> String? {
        let directory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".mac-cleaner/manifests")

        guard fileManager.fileExists(atPath: directory.path) else {
            return nil
        }

        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }

        guard !files.isEmpty else { return nil }

        let sorted = files.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate > rDate
        }

        return sorted.first?.path
    }
}
