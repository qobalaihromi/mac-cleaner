import Foundation

public protocol RiskClassifying {
    func classify(path: String, category: JunkCategory) -> RiskLevel
}

public struct RiskClassifier: RiskClassifying {
    private let protectedPrefixes: [String] = ["/System", "/Library", "/Applications"]

    public init() {}

    public func classify(path: String, category: JunkCategory) -> RiskLevel {
        if protectedPrefixes.contains(where: { path.hasPrefix($0) }) {
            return .doNotTouch
        }

        switch category {
        case .trashOld:
            return .safe
        case .userCache, .browserCache, .appLog:
            return .safe
        case .tempFile:
            return .review
        }
    }
}
