import Foundation

public struct CleanupRule {
    public let id: String
    public let category: JunkCategory
    public let rootPath: String
    public let includePatterns: [String]
    public let excludePatterns: [String]
    public let minAgeDays: Int
    public let defaultSelection: Bool

    public init(
        id: String,
        category: JunkCategory,
        rootPath: String,
        includePatterns: [String] = ["*"],
        excludePatterns: [String] = [],
        minAgeDays: Int = 0,
        defaultSelection: Bool = true
    ) {
        self.id = id
        self.category = category
        self.rootPath = rootPath
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
        self.minAgeDays = minAgeDays
        self.defaultSelection = defaultSelection
    }
}

public protocol CleanupRuleProviding {
    func allRules() -> [CleanupRule]
}
