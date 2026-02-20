import Foundation

public struct CleanupUseCase {
    private let rulesProvider: CleanupRuleProviding
    private let scanner: ScannerServiceType
    private let planner: CleanupPlanning
    private let executor: CleanupExecuting
    private let config: AppConfig

    public init(
        config: AppConfig = .load(),
        rulesProvider: CleanupRuleProviding? = nil,
        scanner: ScannerServiceType = ScannerService(),
        planner: CleanupPlanning = CleanupPlanner(),
        executor: CleanupExecuting = CleanupExecutor()
    ) {
        self.config = config
        self.rulesProvider = rulesProvider ?? DefaultRulesProvider(config: config)
        self.scanner = scanner
        self.planner = planner
        self.executor = executor
    }

    public func listRules() {
        let rules = rulesProvider.allRules()
        print("Active rules: \(rules.count)")
        for rule in rules {
            print("- [\(rule.category.rawValue)] \(rule.id) -> \(rule.rootPath) (minAgeDays: \(rule.minAgeDays))")
        }
    }

    public func scan(includeReviewItems: Bool, limit: Int?) async -> [FileItem] {
        let options = ScanOptions(
            minFileSizeBytes: config.minFileSizeBytes,
            excludedPathPrefixes: config.excludedPathPrefixes
        )
        let rules = rulesProvider.allRules()
        let scannedItems = await scanner.scan(rules: rules, options: options)
        let planned = planner.plan(from: scannedItems, includeReviewItems: includeReviewItems || config.includeReviewByDefault)

        if let limit {
            return Array(planned.prefix(max(0, limit)))
        }

        return planned
    }

    public func clean(includeReviewItems: Bool, assumeYes: Bool, limit: Int?) async -> Int32 {
        let plan = await scan(includeReviewItems: includeReviewItems, limit: limit)
        guard !plan.isEmpty else {
            print("No files selected for cleanup.")
            return 0
        }

        printSummary(items: plan)

        guard assumeYes || confirm(prompt: "Continue and move selected files to Trash? [y/N]: ") else {
            print("Cancelled.")
            return 0
        }

        let result = executor.execute(items: plan)
        print("Cleanup success: \(result.succeeded.count)")
        print("Cleanup failed: \(result.failed.count)")
        print("Freed space: \(ByteCountFormatter.string(fromByteCount: result.totalFreedBytes, countStyle: .file))")

        if let manifestPath = result.manifestPath {
            print("Manifest: \(manifestPath)")
        }

        if !result.failed.isEmpty {
            for failure in result.failed.prefix(10) {
                print("FAILED: \(failure.item.path) -> \(failure.error.localizedDescription)")
            }
            return 1
        }

        return 0
    }

    public func printScan(items: [FileItem], asJSON: Bool) {
        if asJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) {
                print(json)
            }
            return
        }

        printSummary(items: items)
        for item in items.prefix(50) {
            let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
            print("[\(item.category.rawValue)] [\(item.risk.rawValue)] \(size) - \(item.path)")
        }

        if items.count > 50 {
            print("... and \(items.count - 50) more files")
        }
    }

    public func initConfig() -> Int32 {
        do {
            try config.save()
            print("Config initialized at: \(AppConfig.configURL().path)")
            return 0
        } catch {
            print("Failed to write config: \(error.localizedDescription)")
            return 1
        }
    }

    private func printSummary(items: [FileItem]) {
        let totalBytes = items.reduce(0) { $0 + $1.sizeBytes }
        print("Candidates: \(items.count) files")
        print("Potential savings: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")

        let grouped = Dictionary(grouping: items, by: { $0.category })
        for category in JunkCategory.allCases {
            let entries = grouped[category] ?? []
            guard !entries.isEmpty else { continue }
            let bytes = entries.reduce(0) { $0 + $1.sizeBytes }
            print("- \(category.rawValue): \(entries.count) files, \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))")
        }
    }

    private func confirm(prompt: String) -> Bool {
        print(prompt, terminator: "")
        guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return response == "y" || response == "yes"
    }
}
