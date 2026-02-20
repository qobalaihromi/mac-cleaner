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

public final class CleanupService {
    private let config: AppConfig
    private let rulesProvider: CleanupRuleProviding
    private let scanner: ScannerServiceType
    private let planner: CleanupPlanning
    private let executor: CleanupExecuting
    private let diskUsageService: DiskUsageProviding
    private let duplicateFinder: DuplicateFinding

    public init(
        config: AppConfig = .load(),
        rulesProvider: CleanupRuleProviding? = nil,
        scanner: ScannerServiceType = ScannerService(),
        planner: CleanupPlanning = CleanupPlanner(),
        executor: CleanupExecuting = CleanupExecutor(),
        diskUsageService: DiskUsageProviding = DiskUsageService(),
        duplicateFinder: DuplicateFinding = DuplicateFinder()
    ) {
        self.config = config
        self.rulesProvider = rulesProvider ?? DefaultRulesProvider(config: config)
        self.scanner = scanner
        self.planner = planner
        self.executor = executor
        self.diskUsageService = diskUsageService
        self.duplicateFinder = duplicateFinder
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

    public func duplicateGroups(
        includeReviewItems: Bool,
        limit: Int?,
        maxGroups: Int? = nil
    ) async -> [DuplicateFileGroup] {
        let items = await scan(includeReviewItems: includeReviewItems, limit: limit)
        return duplicateFinder.findDuplicateGroups(items: items, maxGroups: maxGroups)
    }
}
