import Foundation

public protocol CleanupExecuting {
    func execute(items: [FileItem]) -> CleanupExecutionResult
}

public struct CleanupExecutor: CleanupExecuting {
    private let trashService: TrashServicing
    private let auditLogger: AuditLogging
    private let manifestWriter: ManifestWriting

    public init(
        trashService: TrashServicing = TrashService(),
        auditLogger: AuditLogging = AuditLogger(),
        manifestWriter: ManifestWriting = ManifestWriter()
    ) {
        self.trashService = trashService
        self.auditLogger = auditLogger
        self.manifestWriter = manifestWriter
    }

    public func execute(items: [FileItem]) -> CleanupExecutionResult {
        var succeeded: [FileItem] = []
        var failed: [(item: FileItem, error: Error)] = []
        var entries: [ManifestEntry] = []

        for item in items {
            do {
                let trashedPath = try trashService.moveToTrash(path: item.path)
                succeeded.append(item)

                entries.append(
                    ManifestEntry(
                        originalPath: item.path,
                        trashedPath: trashedPath,
                        sizeBytes: item.sizeBytes,
                        movedAt: Date()
                    )
                )

                auditLogger.log("CLEANUP_SUCCESS path=\(item.path) size=\(item.sizeBytes)")
            } catch {
                failed.append((item, error))
                auditLogger.log("CLEANUP_FAILED path=\(item.path) error=\(error.localizedDescription)")
            }
        }

        let manifestPath: String?
        do {
            manifestPath = entries.isEmpty ? nil : try manifestWriter.write(entries: entries)
        } catch {
            auditLogger.log("MANIFEST_WRITE_FAILED error=\(error.localizedDescription)")
            manifestPath = nil
        }

        return CleanupExecutionResult(succeeded: succeeded, failed: failed, manifestPath: manifestPath)
    }
}
