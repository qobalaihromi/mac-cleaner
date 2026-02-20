import Foundation

public struct UserRule: Codable {
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

public struct AppConfig: Codable {
    public let minFileSizeBytes: Int64
    public let includeReviewByDefault: Bool
    public let excludedPathPrefixes: [String]
    public let userRules: [UserRule]

    public init(
        minFileSizeBytes: Int64 = 64 * 1024,
        includeReviewByDefault: Bool = false,
        excludedPathPrefixes: [String] = [],
        userRules: [UserRule] = []
    ) {
        self.minFileSizeBytes = minFileSizeBytes
        self.includeReviewByDefault = includeReviewByDefault
        self.excludedPathPrefixes = excludedPathPrefixes
        self.userRules = userRules
    }

    public static func configURL() -> URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return home.appendingPathComponent(".mac-cleaner/config.json")
    }

    public static func load() -> AppConfig {
        let url = configURL()
        guard let data = try? Data(contentsOf: url) else {
            return AppConfig()
        }

        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            return AppConfig()
        }
    }

    public func save() throws {
        let url = Self.configURL()
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(self)
        try data.write(to: url)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
