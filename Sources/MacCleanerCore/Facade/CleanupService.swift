import Foundation

public struct CleanupSummary {
    public let totalFiles: Int
    public let totalBytes: Int64
    public let bytesByCategory: [JunkCategory: Int64]
    public let filesByCategory: [JunkCategory: Int]

    public init(items: [FileItem]) {
        self.totalFiles = items.count
        self.totalBytes = items.reduce(0) { $0 + $1.sizeBytes }

        var bytesMap: [JunkCategory: Int64] = [:]
        var filesMap: [JunkCategory: Int] = [:]
        for item in items {
            bytesMap[item.category, default: 0] += item.sizeBytes
            filesMap[item.category, default: 0] += 1
        }
        self.bytesByCategory = bytesMap
        self.filesByCategory = filesMap
    }
}

public struct DuplicateCleanupPlan {
    public let groups: [DuplicateFileGroup]
    public let itemsToDelete: [FileItem]

    public var reclaimableBytes: Int64 {
        itemsToDelete.reduce(0) { $0 + $1.sizeBytes }
    }

    public init(groups: [DuplicateFileGroup], itemsToDelete: [FileItem]) {
        self.groups = groups
        self.itemsToDelete = itemsToDelete
    }
}

public final class CleanupService {
    private let config: AppConfig
    private let rulesProvider: CleanupRuleProviding
    private let scanner: ScannerServiceType
    private let planner: CleanupPlanning
    private let executor: CleanupExecuting
    private let restoreService: RestoreServicing
    private let diskUsageService: DiskUsageProviding
    private let storageBreakdownService: StorageBreakdownProviding
    private let installedSoftwareService: InstalledSoftwareProviding
    private let duplicateFinder: DuplicateFinding
    private let manifestReader: ManifestReading

    public init(
        config: AppConfig = .load(),
        rulesProvider: CleanupRuleProviding? = nil,
        scanner: ScannerServiceType = ScannerService(),
        planner: CleanupPlanning = CleanupPlanner(),
        executor: CleanupExecuting = CleanupExecutor(),
        restoreService: RestoreServicing = RestoreService(),
        diskUsageService: DiskUsageProviding = DiskUsageService(),
        storageBreakdownService: StorageBreakdownProviding = StorageBreakdownService(),
        installedSoftwareService: InstalledSoftwareProviding = InstalledSoftwareService(),
        duplicateFinder: DuplicateFinding = DuplicateFinder(),
        manifestReader: ManifestReading = ManifestReader()
    ) {
        self.config = config
        self.rulesProvider = rulesProvider ?? DefaultRulesProvider(config: config)
        self.scanner = scanner
        self.planner = planner
        self.executor = executor
        self.restoreService = restoreService
        self.diskUsageService = diskUsageService
        self.storageBreakdownService = storageBreakdownService
        self.installedSoftwareService = installedSoftwareService
        self.duplicateFinder = duplicateFinder
        self.manifestReader = manifestReader
    }

    public func rules() -> [CleanupRule] {
        rulesProvider.allRules()
    }

    public func scan(includeReviewItems: Bool, limit: Int?) async -> [FileItem] {
        let options = ScanOptions(
            minFileSizeBytes: config.minFileSizeBytes,
            excludedPathPrefixes: config.excludedPathPrefixes
        )
        let scannedItems = await scanner.scan(rules: rulesProvider.allRules(), options: options)
        let planned = planner.plan(
            from: scannedItems,
            includeReviewItems: includeReviewItems || config.includeReviewByDefault
        )

        guard let limit else { return planned }
        return Array(planned.prefix(max(0, limit)))
    }

    public func clean(items: [FileItem]) -> CleanupExecutionResult {
        executor.execute(items: items)
    }

    public func initConfig() throws -> String {
        try config.save()
        return AppConfig.configURL().path
    }

    public func storageUsage() throws -> DiskUsage {
        try diskUsageService.currentUsage()
    }

    public func storageBreakdown() throws -> StorageBreakdown {
        let usage = try storageUsage()
        return storageBreakdownService.analyze(usage: usage)
    }

    public func installedApps() -> [InstalledAppInfo] {
        installedSoftwareService.listInstalledApps()
    }

    public func uninstallApp(path: String) throws {
        try installedSoftwareService.uninstallApp(at: path)
    }

    public func duplicateGroups(
        includeReviewItems: Bool,
        limit: Int?,
        maxGroups: Int? = nil
    ) async -> [DuplicateFileGroup] {
        let items = await scan(includeReviewItems: includeReviewItems, limit: limit)
        return duplicateFinder.findDuplicateGroups(items: items, maxGroups: maxGroups)
    }

    public func duplicateGroups(from items: [FileItem], maxGroups: Int? = nil) -> [DuplicateFileGroup] {
        duplicateFinder.findDuplicateGroups(items: items, maxGroups: maxGroups)
    }

    public func duplicateCleanupPlan(
        includeReviewItems: Bool,
        limit: Int?,
        maxGroups: Int? = nil
    ) async -> DuplicateCleanupPlan {
        let items = await scan(includeReviewItems: includeReviewItems, limit: limit)
        return duplicateCleanupPlan(from: items, maxGroups: maxGroups)
    }

    public func duplicateCleanupPlan(from items: [FileItem], maxGroups: Int? = nil) -> DuplicateCleanupPlan {
        let groups = duplicateGroups(from: items, maxGroups: maxGroups)
        let itemsByPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })

        var deletionPaths: Set<String> = []
        for group in groups {
            let sorted = group.files.sorted()
            guard sorted.count > 1 else { continue }
            for path in sorted.dropFirst(1) {
                deletionPaths.insert(path)
            }
        }

        let deletionItems = deletionPaths.compactMap { itemsByPath[$0] }.sorted { $0.sizeBytes > $1.sizeBytes }
        return DuplicateCleanupPlan(groups: groups, itemsToDelete: deletionItems)
    }

    public func latestManifestPath() throws -> String? {
        try manifestReader.latestManifestPath()
    }

    public func restoreFromManifest(path: String) throws -> RestoreResult {
        let manifest = try manifestReader.readManifest(path: path)
        return restoreService.restore(entries: manifest.entries)
    }
}
