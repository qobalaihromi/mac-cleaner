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
    @Published var isCleaningDuplicates = false
    @Published var isRestoring = false
    @Published var isAnalyzingStorage = false
    @Published var isLoadingInstalledApps = false
    @Published var isUninstallingApp = false
    @Published var includeReview = false
    @Published var limitText = ""
    @Published var statusMessage = "Ready"
    @Published var lastManifestPath = ""
    @Published var storageTotalBytes: Int64 = 0
    @Published var storageUsedBytes: Int64 = 0
    @Published var storageFreeBytes: Int64 = 0
    @Published var storageUsedRatio: Double = 0
    @Published var storageBreakdownCategories: [StorageCategoryUsage] = []
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var showRecommendedAppsOnly = true
    @Published var duplicateGroups: [DuplicateFileGroup] = []
    @Published var duplicateItemsToDelete: [FileItem] = []

    private let service = CleanupService()

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalFiles: Int {
        items.count
    }

    var totalDuplicateReclaimableBytes: Int64 {
        duplicateItemsToDelete.reduce(0) { $0 + $1.sizeBytes }
    }

    var visibleInstalledApps: [InstalledAppInfo] {
        if showRecommendedAppsOnly {
            return installedApps.filter { $0.recommendation == .uninstallCandidate }
        }
        return installedApps
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
        analyzeStorageBreakdown()
        loadInstalledApps()
    }

    func scan() {
        isScanning = true
        statusMessage = "Scanning..."

        Task {
            let limit = normalizedLimit()
            let scanned = await service.scan(includeReviewItems: includeReview, limit: limit)
            items = scanned
            duplicateGroups = []
            duplicateItemsToDelete = []
            isScanning = false
            statusMessage = "Scan complete: \(scanned.count) files"
            refreshStorage()
            analyzeStorageBreakdown()
            loadInstalledApps()
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
            duplicateItemsToDelete = []
            isCleaning = false
            refreshStorage()
            analyzeStorageBreakdown()
        }
    }

    func findDuplicates() {
        isFindingDuplicates = true
        statusMessage = "Finding duplicates..."

        Task {
            let plan = service.duplicateCleanupPlan(from: items, maxGroups: 20)
            duplicateGroups = plan.groups
            duplicateItemsToDelete = plan.itemsToDelete
            isFindingDuplicates = false

            let reclaimable = ByteCountFormatter.string(
                fromByteCount: totalDuplicateReclaimableBytes,
                countStyle: .file
            )
            statusMessage = "Duplicate scan complete: \(plan.groups.count) groups, reclaimable \(reclaimable)"
        }
    }

    func cleanDuplicateCopies() {
        guard !duplicateItemsToDelete.isEmpty else {
            statusMessage = "No duplicate cleanup candidates"
            return
        }

        isCleaningDuplicates = true
        statusMessage = "Cleaning duplicate copies..."

        Task {
            let result = service.clean(items: duplicateItemsToDelete)
            let freed = ByteCountFormatter.string(fromByteCount: result.totalFreedBytes, countStyle: .file)
            statusMessage = "Duplicate cleanup done. Freed \(freed). Success: \(result.succeeded.count), Failed: \(result.failed.count)"
            lastManifestPath = result.manifestPath ?? lastManifestPath

            let limit = normalizedLimit()
            items = await service.scan(includeReviewItems: includeReview, limit: limit)
            let refreshedPlan = service.duplicateCleanupPlan(from: items, maxGroups: 20)
            duplicateGroups = refreshedPlan.groups
            duplicateItemsToDelete = refreshedPlan.itemsToDelete
            refreshStorage()
            analyzeStorageBreakdown()
            loadInstalledApps()
            isCleaningDuplicates = false
        }
    }

    func restoreLatestCleanup() {
        isRestoring = true
        statusMessage = "Restoring..."

        Task {
            do {
                guard let manifestPath = try service.latestManifestPath() else {
                    statusMessage = "No cleanup manifest found"
                    isRestoring = false
                    return
                }

                let result = try service.restoreFromManifest(path: manifestPath)
                lastManifestPath = manifestPath
                statusMessage = "Restore done. Success: \(result.restored.count), Skipped: \(result.skipped.count), Failed: \(result.failed.count)"

                let limit = normalizedLimit()
                items = await service.scan(includeReviewItems: includeReview, limit: limit)
                duplicateGroups = []
                duplicateItemsToDelete = []
                refreshStorage()
                analyzeStorageBreakdown()
                loadInstalledApps()
            } catch {
                statusMessage = "Restore failed: \(error.localizedDescription)"
            }

            isRestoring = false
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

    func analyzeStorageBreakdown() {
        guard !isAnalyzingStorage else { return }
        isAnalyzingStorage = true
        Task {
            let result = try? service.storageBreakdown()
            if let result {
                storageBreakdownCategories = result.categories
            }
            isAnalyzingStorage = false
        }
    }

    func loadInstalledApps() {
        guard !isLoadingInstalledApps else { return }
        isLoadingInstalledApps = true

        Task {
            let apps = service.installedApps()
            installedApps = apps
            isLoadingInstalledApps = false
        }
    }

    func uninstallApp(_ app: InstalledAppInfo) {
        guard !isUninstallingApp else { return }
        isUninstallingApp = true
        statusMessage = "Uninstalling \(app.name)..."

        Task {
            do {
                try service.uninstallApp(path: app.path)
                statusMessage = "Moved \(app.name) to Trash"
                refreshStorage()
                analyzeStorageBreakdown()
                loadInstalledApps()
            } catch {
                statusMessage = "Failed to uninstall \(app.name): \(error.localizedDescription)"
            }
            isUninstallingApp = false
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
