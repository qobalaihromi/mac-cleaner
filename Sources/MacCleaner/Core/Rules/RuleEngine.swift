import Foundation

public protocol RuleEngineType {
    func matchingRule(for fileURL: URL, rules: [CleanupRule]) -> CleanupRule?
}

public struct RuleEngine: RuleEngineType {
    public init() {}

    public func matchingRule(for fileURL: URL, rules: [CleanupRule]) -> CleanupRule? {
        let path = fileURL.path

        return rules.first { rule in
            path.hasPrefix(rule.rootPath) &&
            !containsAny(path: path, patterns: rule.excludePatterns) &&
            matchesAny(path: path, patterns: rule.includePatterns)
        }
    }

    private func matchesAny(path: String, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return true }
        return patterns.contains { wildcard($0, matches: path) }
    }

    private func containsAny(path: String, patterns: [String]) -> Bool {
        patterns.contains { wildcard($0, matches: path) }
    }

    private func wildcard(_ pattern: String, matches value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        let regex = "^" + escaped + "$"
        return value.range(of: regex, options: .regularExpression) != nil
    }
}
