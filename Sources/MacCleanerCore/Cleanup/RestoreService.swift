import Foundation

public struct RestoreResult {
    public let restored: [ManifestEntry]
    public let skipped: [(entry: ManifestEntry, reason: String)]
    public let failed: [(entry: ManifestEntry, error: Error)]

    public init(
        restored: [ManifestEntry],
        skipped: [(entry: ManifestEntry, reason: String)],
        failed: [(entry: ManifestEntry, error: Error)]
    ) {
        self.restored = restored
        self.skipped = skipped
        self.failed = failed
    }
}

public protocol RestoreServicing {
    func restore(entries: [ManifestEntry]) -> RestoreResult
}

public struct RestoreService: RestoreServicing {
    private let fileManager: FileManager
    private let auditLogger: AuditLogging

    public init(fileManager: FileManager = .default, auditLogger: AuditLogging = AuditLogger()) {
        self.fileManager = fileManager
        self.auditLogger = auditLogger
    }

    public func restore(entries: [ManifestEntry]) -> RestoreResult {
        var restored: [ManifestEntry] = []
        var skipped: [(entry: ManifestEntry, reason: String)] = []
        var failed: [(entry: ManifestEntry, error: Error)] = []

        for entry in entries {
            let fromURL = URL(fileURLWithPath: entry.trashedPath)
            let toURL = URL(fileURLWithPath: entry.originalPath)

            guard fileManager.fileExists(atPath: fromURL.path) else {
                skipped.append((entry, "Trashed file not found"))
                continue
            }

            if fileManager.fileExists(atPath: toURL.path) {
                skipped.append((entry, "Original path already exists"))
                continue
            }

            do {
                let parent = toURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                try fileManager.moveItem(at: fromURL, to: toURL)
                restored.append(entry)
                auditLogger.log("RESTORE_SUCCESS from=\(entry.trashedPath) to=\(entry.originalPath)")
            } catch {
                failed.append((entry, error))
                auditLogger.log("RESTORE_FAILED from=\(entry.trashedPath) to=\(entry.originalPath) error=\(error.localizedDescription)")
            }
        }

        return RestoreResult(restored: restored, skipped: skipped, failed: failed)
    }
}
