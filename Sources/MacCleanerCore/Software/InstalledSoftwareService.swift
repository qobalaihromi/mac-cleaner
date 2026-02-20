import AppKit
import CoreServices
import Foundation

public enum AppRecommendation: String, Codable {
    case keep
    case review
    case uninstallCandidate
}

public struct InstalledAppInfo: Identifiable, Codable {
    public let id: String
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public let lastUsedAt: Date?
    public let recommendation: AppRecommendation
    public let recommendationReason: String

    public init(
        name: String,
        path: String,
        sizeBytes: Int64,
        lastUsedAt: Date?,
        recommendation: AppRecommendation,
        recommendationReason: String
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.lastUsedAt = lastUsedAt
        self.recommendation = recommendation
        self.recommendationReason = recommendationReason
    }
}

public protocol InstalledSoftwareProviding {
    func listInstalledApps() -> [InstalledAppInfo]
    func uninstallApp(at path: String) throws
}

public struct InstalledSoftwareService: InstalledSoftwareProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func listInstalledApps() -> [InstalledAppInfo] {
        let searchRoots = ["/Applications", NSHomeDirectory() + "/Applications"]
        let appURLs = searchRoots.flatMap { appBundles(in: $0) }

        let apps = appURLs.compactMap { appInfo(for: $0) }
        return apps.sorted { lhs, rhs in
            if lhs.recommendation == rhs.recommendation {
                return lhs.sizeBytes > rhs.sizeBytes
            }
            return recommendationPriority(lhs.recommendation) > recommendationPriority(rhs.recommendation)
        }
    }

    public func uninstallApp(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }

    private func appBundles(in rootPath: String) -> [URL] {
        guard fileManager.fileExists(atPath: rootPath) else { return [] }
        let rootURL = URL(fileURLWithPath: rootPath)

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var result: [URL] = []
        while let next = enumerator.nextObject() as? URL {
            guard next.pathExtension.lowercased() == "app" else { continue }
            result.append(next)
            enumerator.skipDescendants()
        }
        return result
    }

    private func appInfo(for appURL: URL) -> InstalledAppInfo? {
        let sizeBytes = directorySize(path: appURL.path)
        let name = appURL.deletingPathExtension().lastPathComponent
        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier
        let lastUsed = bestLastUsedDate(appURL: appURL, appName: name, bundleIdentifier: bundleIdentifier)
        let recommendation = recommendationFor(lastUsed: lastUsed, sizeBytes: sizeBytes)

        return InstalledAppInfo(
            name: name,
            path: appURL.path,
            sizeBytes: sizeBytes,
            lastUsedAt: lastUsed,
            recommendation: recommendation.level,
            recommendationReason: recommendation.reason
        )
    }

    private func recommendationFor(lastUsed: Date?, sizeBytes: Int64) -> (level: AppRecommendation, reason: String) {
        let oneDay: TimeInterval = 24 * 60 * 60
        let now = Date()

        if let lastUsed {
            let daysUnused = max(0, Int(now.timeIntervalSince(lastUsed) / oneDay))
            if daysUnused >= 365 && sizeBytes >= 1024 * 1024 * 1024 {
                return (.uninstallCandidate, "Tidak digunakan sekitar \(daysUnused) hari")
            }
            if daysUnused >= 180 && sizeBytes >= 500 * 1024 * 1024 {
                return (.uninstallCandidate, "Tidak digunakan sekitar \(daysUnused) hari")
            }
            if daysUnused >= 90 && sizeBytes >= 300 * 1024 * 1024 {
                return (.review, "Jarang digunakan (\(daysUnused) hari)")
            }
            return (.keep, "Masih aktif digunakan")
        }

        return (.review, "Data penggunaan tidak tersedia")
    }

    private func recommendationPriority(_ recommendation: AppRecommendation) -> Int {
        switch recommendation {
        case .uninstallCandidate: return 3
        case .review: return 2
        case .keep: return 1
        }
    }

    private func bestLastUsedDate(appURL: URL, appName: String, bundleIdentifier: String?) -> Date? {
        var candidates: [Date] = []
        let fallbackValues = try? appURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])

        if let bundleIdentifier,
           !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
            candidates.append(Date())
        }

        if let spotlightDate = spotlightLastUsedDate(for: appURL) {
            candidates.append(spotlightDate)
        }

        candidates.append(contentsOf: appDataActivityDates(appName: appName, bundleIdentifier: bundleIdentifier))

        if let modifiedAt = fallbackValues?.contentModificationDate {
            candidates.append(modifiedAt)
        }
        if let createdAt = fallbackValues?.creationDate {
            candidates.append(createdAt)
        }

        return candidates.max()
    }

    private func spotlightLastUsedDate(for appURL: URL) -> Date? {
        guard let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, appURL as CFURL) else {
            return nil
        }

        if let value = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate as CFString) {
            return value as? Date
        }

        return nil
    }

    private func appDataActivityDates(appName: String, bundleIdentifier: String?) -> [Date] {
        let home = NSHomeDirectory()
        var candidatePaths: [String] = [
            home + "/Library/Application Support/" + appName,
            home + "/Library/Caches/" + appName,
            home + "/Library/Logs/" + appName
        ]

        if let bundleIdentifier {
            candidatePaths.append(home + "/Library/Application Support/" + bundleIdentifier)
            candidatePaths.append(home + "/Library/Caches/" + bundleIdentifier)
            candidatePaths.append(home + "/Library/Containers/" + bundleIdentifier)
            candidatePaths.append(home + "/Library/Preferences/" + bundleIdentifier + ".plist")

            let components = bundleIdentifier.split(separator: ".").map(String.init)
            if components.count >= 3 {
                let vendor = components[1].capitalized
                let product = components.dropFirst(2).joined(separator: ".")
                if !product.isEmpty {
                    candidatePaths.append(home + "/Library/Application Support/" + vendor + "/" + product)
                    candidatePaths.append(home + "/Library/Caches/" + vendor + "/" + product)
                }
            }
        }

        var result: [Date] = []
        for path in candidatePaths {
            if let date = latestModificationDate(path: path) {
                result.append(date)
            }
        }
        return result
    }

    private func latestModificationDate(path: String) -> Date? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]

        if let directValues = try? url.resourceValues(forKeys: keys), directValues.isRegularFile == true {
            return directValues.contentModificationDate
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }

        var latest: Date?
        var inspected = 0
        let maxInspected = 1500

        while let next = enumerator.nextObject() as? URL {
            inspected += 1
            if inspected > maxInspected { break }
            guard let values = try? next.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate else {
                continue
            }

            if let current = latest {
                if modifiedAt > current { latest = modifiedAt }
            } else {
                latest = modifiedAt
            }
        }

        return latest
    }

    private func directorySize(path: String) -> Int64 {
        guard fileManager.fileExists(atPath: path) else { return 0 }
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        while let next = enumerator.nextObject() as? URL {
            guard let values = try? next.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            guard values.isSymbolicLink != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
