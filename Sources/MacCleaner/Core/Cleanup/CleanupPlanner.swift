import Foundation

public protocol CleanupPlanning {
    func plan(from scannedItems: [FileItem], includeReviewItems: Bool) -> [FileItem]
}

public struct CleanupPlanner: CleanupPlanning {
    public init() {}

    public func plan(from scannedItems: [FileItem], includeReviewItems: Bool) -> [FileItem] {
        scannedItems
            .filter {
                if includeReviewItems {
                    return $0.selectedByDefault || $0.risk == .review
                }
                return $0.selectedByDefault && $0.risk == .safe
            }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
