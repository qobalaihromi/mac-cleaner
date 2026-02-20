import Darwin
import Foundation

public struct MemoryUsage: Codable {
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let freeBytes: Int64
    public let activeBytes: Int64
    public let wiredBytes: Int64
    public let compressedBytes: Int64

    public var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public init(
        totalBytes: Int64,
        usedBytes: Int64,
        freeBytes: Int64,
        activeBytes: Int64,
        wiredBytes: Int64,
        compressedBytes: Int64
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.activeBytes = activeBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
    }
}

public protocol MemoryUsageProviding {
    func currentUsage() throws -> MemoryUsage
}

public struct MemoryUsageService: MemoryUsageProviding {
    public init() {}

    public func currentUsage() throws -> MemoryUsage {
        let host = mach_host_self()
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else {
            throw NSError(domain: "MemoryUsageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch page size"])
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw NSError(domain: "MemoryUsageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch memory statistics"])
        }

        let page = Int64(pageSize)
        let freeBytes = Int64(stats.free_count + stats.speculative_count) * page
        let activeBytes = Int64(stats.active_count + stats.inactive_count) * page
        let wiredBytes = Int64(stats.wire_count) * page
        let compressedBytes = Int64(stats.compressor_page_count) * page
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
        let usedBytes = max(0, totalBytes - freeBytes)

        return MemoryUsage(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            activeBytes: activeBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes
        )
    }
}
