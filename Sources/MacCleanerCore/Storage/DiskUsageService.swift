import Foundation

public struct DiskUsage: Codable {
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let availableBytes: Int64

    public var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public init(totalBytes: Int64, usedBytes: Int64, availableBytes: Int64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
    }
}

public protocol DiskUsageProviding {
    func currentUsage() throws -> DiskUsage
}

public struct DiskUsageService: DiskUsageProviding {
    public init() {}

    public func currentUsage() throws -> DiskUsage {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        let values = try homeURL.resourceValues(forKeys: keys)

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let availableImportant = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let availableFallback = Int64(values.volumeAvailableCapacity ?? 0)
        let available = max(availableImportant, availableFallback)
        let used = max(0, total - max(0, available))

        return DiskUsage(totalBytes: total, usedBytes: used, availableBytes: max(0, available))
    }
}
