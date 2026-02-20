import Foundation
import MacCleanerCore

struct CategoryUsageRow: Identifiable {
    let id: String
    let category: JunkCategory
    let bytes: Int64
    let files: Int
    let ratio: Double
}

struct FolderUsageRow: Identifiable {
    let id: String
    let folderPath: String
    let bytes: Int64
    let files: Int
    let ratio: Double
}

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var isFindingDuplicates = false
    @Published var includeReview = false
    @Published var limitText = ""
    @Published var statusMessage = "Ready"
    @Published var lastManifestPath = ""
    @Published var storageTotalBytes: Int64 = 0
    @Published var storageUsedBytes: Int64 = 0
    @Published var storageFreeBytes: Int64 = 0
    @Published var storageUsedRatio: Double = 0
    @Published var duplicateGroups: [DuplicateFileGroup] = []

    private let service = CleanupService()

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalFiles: Int {
        items.count
    }

    var totalDuplicateReclaimableBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var categoryUsageRows: [CategoryUsageRow] {
        let total = max(totalBytes, 1)
        var bytesByCategory: [JunkCategory: Int64] = [:]
        var filesByCategory: [JunkCategory: Int] = [:]

        for item in items {
            bytesByCategory[item.category, default: 0] += item.sizeBytes
            filesByCategory[item.category, default: 0] += 1
        }

        return JunkCategory.allCases.compactMap { category in
            let bytes = bytesByCategory[category] ?? 0
            let files = filesByCategory[category] ?? 0
            guard files > 0 else { return nil }
            return CategoryUsageRow(
                id: category.rawValue,
                category: category,
                bytes: bytes,
                files: files,
                ratio: Double(bytes) / Double(total)
            )
        }
        .sorted { $0.bytes > $1.bytes }
    }

    var topFolderRows: [FolderUsageRow] {
        let total = max(totalBytes, 1)
        var bytesByFolder: [String: Int64] = [:]
        var filesByFolder: [String: Int] = [:]

        for item in items {
            let bucket = folderBucketPath(for: item.path)
            bytesByFolder[bucket, default: 0] += item.sizeBytes
            filesByFolder[bucket, default: 0] += 1
        }

        return bytesByFolder.map { path, bytes in
            FolderUsageRow(
                id: path,
                folderPath: path,
                bytes: bytes,
                files: filesByFolder[path] ?? 0,
                ratio: Double(bytes) / Double(total)
            )
        }
        .sorted { $0.bytes > $1.bytes }
        .prefix(8)
        .map { $0 }
    }

    init() {
        refreshStorage()
    }

    func scan() {
        isScanning = true
        statusMessage = "Scanning..."

        Task {
            let limit = normalizedLimit()
            let scanned = await service.scan(includeReviewItems: includeReview, limit: limit)
            items = scanned
            duplicateGroups = []
            isScanning = false
            statusMessage = "Scan complete: \(scanned.count) files"
            refreshStorage()
        }
    }

    func clean() {
        guard !items.isEmpty else {
            statusMessage = "No files to clean"
            return
        }

        isCleaning = true
        statusMessage = "Cleaning..."

        Task {
            let result = service.clean(items: items)
            let freed = ByteCountFormatter.string(fromByteCount: result.totalFreedBytes, countStyle: .file)
            statusMessage = "Done. Freed \(freed). Success: \(result.succeeded.count), Failed: \(result.failed.count)"
            lastManifestPath = result.manifestPath ?? ""

            // Rescan to refresh remaining candidates
            let limit = normalizedLimit()
            items = await service.scan(includeReviewItems: includeReview, limit: limit)
            duplicateGroups = []
            isCleaning = false
            refreshStorage()
        }
    }

    func findDuplicates() {
        isFindingDuplicates = true
        statusMessage = "Finding duplicates..."

        Task {
            let limit = normalizedLimit()
            let groups = await service.duplicateGroups(
                includeReviewItems: includeReview,
                limit: limit,
                maxGroups: 20
            )
            duplicateGroups = groups
            isFindingDuplicates = false

            let reclaimable = ByteCountFormatter.string(
                fromByteCount: totalDuplicateReclaimableBytes,
                countStyle: .file
            )
            statusMessage = "Duplicate scan complete: \(groups.count) groups, reclaimable \(reclaimable)"
        }
    }

    func refreshStorage() {
        do {
            let usage = try service.storageUsage()
            storageTotalBytes = usage.totalBytes
            storageUsedBytes = usage.usedBytes
            storageFreeBytes = usage.availableBytes
            storageUsedRatio = usage.usedRatio
        } catch {
            statusMessage = "Failed to read storage info"
        }
    }

    private func normalizedLimit() -> Int? {
        let trimmed = limitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private func folderBucketPath(for filePath: String) -> String {
        if filePath.contains("/Library/Caches/Google/Chrome") {
            return "~/Library/Caches/Google/Chrome"
        }
        if filePath.contains("/Library/Caches/Firefox") {
            return "~/Library/Caches/Firefox"
        }
        if filePath.contains("/Library/Caches/") {
            return "~/Library/Caches"
        }
        if filePath.contains("/Library/Logs/") {
            return "~/Library/Logs"
        }
        if filePath.contains("/.Trash/") || filePath.hasSuffix("/.Trash") {
            return "~/.Trash"
        }
        if filePath.contains("/var/folders/") {
            return "/var/folders/.../T"
        }

        let url = URL(fileURLWithPath: filePath)
        return url.deletingLastPathComponent().path
    }
}
