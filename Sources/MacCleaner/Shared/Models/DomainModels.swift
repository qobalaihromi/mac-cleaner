import Foundation

public enum JunkCategory: String, Codable, CaseIterable {
    case userCache
    case appLog
    case browserCache
    case tempFile
    case trashOld
}

public enum RiskLevel: String, Codable {
    case safe
    case review
    case doNotTouch
}

public struct ScanOptions {
    public let minFileSizeBytes: Int64
    public let excludedPathPrefixes: [String]

    public init(minFileSizeBytes: Int64 = 64 * 1024, excludedPathPrefixes: [String] = []) {
        self.minFileSizeBytes = minFileSizeBytes
        self.excludedPathPrefixes = excludedPathPrefixes
    }
}

public struct FileItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let path: String
    public let category: JunkCategory
    public let sizeBytes: Int64
    public let modifiedAt: Date?
    public let lastAccessAt: Date?
    public let ruleId: String
    public let risk: RiskLevel
    public let selectedByDefault: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        category: JunkCategory,
        sizeBytes: Int64,
        modifiedAt: Date?,
        lastAccessAt: Date?,
        ruleId: String,
        risk: RiskLevel,
        selectedByDefault: Bool
    ) {
        self.id = id
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.lastAccessAt = lastAccessAt
        self.ruleId = ruleId
        self.risk = risk
        self.selectedByDefault = selectedByDefault
    }
}

public struct CleanupExecutionResult {
    public let succeeded: [FileItem]
    public let failed: [(item: FileItem, error: Error)]
    public let manifestPath: String?

    public var totalFreedBytes: Int64 {
        succeeded.reduce(0) { $0 + $1.sizeBytes }
    }

    public init(succeeded: [FileItem], failed: [(item: FileItem, error: Error)], manifestPath: String?) {
        self.succeeded = succeeded
        self.failed = failed
        self.manifestPath = manifestPath
    }
}
