import Foundation

public struct DefaultRulesProvider: CleanupRuleProviding {
    private let config: AppConfig

    public init(config: AppConfig = .load()) {
        self.config = config
    }

    public func allRules() -> [CleanupRule] {
        let home = NSHomeDirectory()
        let tmpRoot = NSTemporaryDirectory().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var rules: [CleanupRule] = [
            CleanupRule(
                id: "user-cache",
                category: .userCache,
                rootPath: home + "/Library/Caches",
                excludePatterns: ["*com.apple.Safari/SafeBrowsing*"],
                minAgeDays: 2
            ),
            CleanupRule(
                id: "user-logs",
                category: .appLog,
                rootPath: home + "/Library/Logs",
                minAgeDays: 7
            ),
            CleanupRule(
                id: "chrome-cache",
                category: .browserCache,
                rootPath: home + "/Library/Caches/Google/Chrome",
                minAgeDays: 2
            ),
            CleanupRule(
                id: "firefox-cache",
                category: .browserCache,
                rootPath: home + "/Library/Caches/Firefox",
                minAgeDays: 2
            ),
            CleanupRule(
                id: "user-temp",
                category: .tempFile,
                rootPath: "/" + tmpRoot,
                minAgeDays: 2,
                defaultSelection: false
            ),
            CleanupRule(
                id: "trash-old",
                category: .trashOld,
                rootPath: home + "/.Trash",
                minAgeDays: 14
            )
        ]

        let customRules = config.userRules.map {
            CleanupRule(
                id: $0.id,
                category: $0.category,
                rootPath: $0.rootPath,
                includePatterns: $0.includePatterns,
                excludePatterns: $0.excludePatterns,
                minAgeDays: $0.minAgeDays,
                defaultSelection: $0.defaultSelection
            )
        }

        rules.append(contentsOf: customRules)
        return rules
    }
}
