import Foundation

public struct StorageCategoryUsage: Identifiable, Codable {
    public let id: String
    public let name: String
    public let bytes: Int64
    public let colorHex: String

    public init(id: String, name: String, bytes: Int64, colorHex: String) {
        self.id = id
        self.name = name
        self.bytes = bytes
        self.colorHex = colorHex
    }
}

public struct StorageBreakdown: Codable {
    public let categories: [StorageCategoryUsage]
    public let accountedBytes: Int64
    public let usedBytes: Int64
    public let totalBytes: Int64

    public init(categories: [StorageCategoryUsage], accountedBytes: Int64, usedBytes: Int64, totalBytes: Int64) {
        self.categories = categories
        self.accountedBytes = accountedBytes
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }
}

public protocol StorageBreakdownProviding {
    func analyze(usage: DiskUsage) -> StorageBreakdown
}

public struct StorageBreakdownService: StorageBreakdownProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func analyze(usage: DiskUsage) -> StorageBreakdown {
        let home = NSHomeDirectory()

        let specs: [(id: String, name: String, roots: [String], colorHex: String)] = [
            ("applications", "Applications", ["/Applications", "/System/Applications"], "#FF4D57"),
            ("documents", "Documents", [home + "/Documents"], "#FF9F31"),
            ("developer", "Developer", [home + "/Developer", home + "/Library/Developer"], "#F2D024"),
            ("downloads", "Downloads", [home + "/Downloads"], "#4DA3FF"),
            ("desktop", "Desktop", [home + "/Desktop"], "#2DD4BF"),
            ("media", "Media", [home + "/Music", home + "/Movies", home + "/Pictures"], "#48D96D"),
            ("icloud", "iCloud Drive", [home + "/Library/Mobile Documents"], "#8B9CF6"),
            ("mail", "Mail", [home + "/Library/Mail"], "#60A5FA")
        ]

        var categories: [StorageCategoryUsage] = []

        for spec in specs {
            let bytes = spec.roots.reduce(Int64(0)) { partial, path in
                partial + directorySize(path: path)
            }
            guard bytes > 0 else { continue }
            categories.append(StorageCategoryUsage(id: spec.id, name: spec.name, bytes: bytes, colorHex: spec.colorHex))
        }

        let accounted = categories.reduce(Int64(0)) { $0 + $1.bytes }
        let systemDataBytes = max(0, usage.usedBytes - accounted)
        categories.append(
            StorageCategoryUsage(
                id: "system-data",
                name: "System Data",
                bytes: systemDataBytes,
                colorHex: "#8D8D8D"
            )
        )

        let sorted = categories.sorted { $0.bytes > $1.bytes }
        let finalAccounted = sorted.reduce(Int64(0)) { $0 + $1.bytes }
        return StorageBreakdown(
            categories: sorted,
            accountedBytes: finalAccounted,
            usedBytes: usage.usedBytes,
            totalBytes: usage.totalBytes
        )
    }

    private func directorySize(path: String) -> Int64 {
        guard fileManager.fileExists(atPath: path) else { return 0 }

        var total: Int64 = 0
        let rootURL = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        while let next = enumerator.nextObject() as? URL {
            guard let values = try? next.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            guard values.isSymbolicLink != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }

        return total
    }
}
