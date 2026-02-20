import Foundation

public protocol ScannerServiceType {
    func scan(rules: [CleanupRule], options: ScanOptions) async -> [FileItem]
}

public struct ScannerService: ScannerServiceType {
    private let fileManager: FileManager
    private let ruleEngine: RuleEngineType
    private let riskClassifier: RiskClassifying

    public init(
        fileManager: FileManager = .default,
        ruleEngine: RuleEngineType = RuleEngine(),
        riskClassifier: RiskClassifying = RiskClassifier()
    ) {
        self.fileManager = fileManager
        self.ruleEngine = ruleEngine
        self.riskClassifier = riskClassifier
    }

    public func scan(rules: [CleanupRule], options: ScanOptions) async -> [FileItem] {
        var result: [FileItem] = []

        for rule in rules {
            let rootURL = URL(fileURLWithPath: rule.rootPath)
            guard fileManager.fileExists(atPath: rootURL.path) else { continue }

            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey
                ],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            )

            while let next = enumerator?.nextObject() as? URL {
                guard let values = try? next.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey
                ]) else {
                    continue
                }

                guard values.isRegularFile == true else { continue }
                guard values.isSymbolicLink != true else { continue }

                let path = next.path

                guard !options.excludedPathPrefixes.contains(where: { path.hasPrefix($0) }) else {
                    continue
                }

                guard let matchedRule = ruleEngine.matchingRule(for: next, rules: [rule]) else {
                    continue
                }

                guard isOlderThanMinimumAge(values.contentModificationDate, minDays: matchedRule.minAgeDays) else {
                    continue
                }

                let fileSize = Int64(values.fileSize ?? 0)
                guard fileSize >= options.minFileSizeBytes else { continue }

                let risk = riskClassifier.classify(path: path, category: matchedRule.category)
                if risk == .doNotTouch { continue }

                let item = FileItem(
                    path: path,
                    category: matchedRule.category,
                    sizeBytes: fileSize,
                    modifiedAt: values.contentModificationDate,
                    lastAccessAt: values.creationDate,
                    ruleId: matchedRule.id,
                    risk: risk,
                    selectedByDefault: matchedRule.defaultSelection && risk == .safe
                )

                result.append(item)
            }
        }

        return result.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func isOlderThanMinimumAge(_ date: Date?, minDays: Int) -> Bool {
        guard minDays > 0, let date else { return true }
        let cutoff = Calendar.current.date(byAdding: .day, value: -minDays, to: Date()) ?? Date()
        return date < cutoff
    }
}
