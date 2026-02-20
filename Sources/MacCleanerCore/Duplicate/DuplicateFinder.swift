import CryptoKit
import Foundation

public struct DuplicateFileGroup: Identifiable, Codable {
    public let id: String
    public let fileSizeBytes: Int64
    public let files: [String]

    public var duplicateCount: Int {
        files.count
    }

    public var reclaimableBytes: Int64 {
        guard files.count > 1 else { return 0 }
        return fileSizeBytes * Int64(files.count - 1)
    }

    public init(hash: String, fileSizeBytes: Int64, files: [String]) {
        self.id = hash
        self.fileSizeBytes = fileSizeBytes
        self.files = files
    }
}

public protocol DuplicateFinding {
    func findDuplicateGroups(items: [FileItem], maxGroups: Int?) -> [DuplicateFileGroup]
}

public struct DuplicateFinder: DuplicateFinding {
    public init() {}

    public func findDuplicateGroups(items: [FileItem], maxGroups: Int? = nil) -> [DuplicateFileGroup] {
        let sizeCandidates = Dictionary(grouping: items, by: { $0.sizeBytes })
            .filter { $0.key > 0 && $0.value.count > 1 }

        var groups: [DuplicateFileGroup] = []

        for (size, candidates) in sizeCandidates {
            var hashBuckets: [String: [String]] = [:]

            for item in candidates {
                guard let hash = fileSHA256(path: item.path) else { continue }
                hashBuckets[hash, default: []].append(item.path)
            }

            for (hash, paths) in hashBuckets where paths.count > 1 {
                groups.append(
                    DuplicateFileGroup(
                        hash: hash,
                        fileSizeBytes: size,
                        files: paths.sorted()
                    )
                )
            }
        }

        let sorted = groups.sorted { lhs, rhs in
            if lhs.reclaimableBytes == rhs.reclaimableBytes {
                return lhs.fileSizeBytes > rhs.fileSizeBytes
            }
            return lhs.reclaimableBytes > rhs.reclaimableBytes
        }

        guard let maxGroups, maxGroups > 0 else { return sorted }
        return Array(sorted.prefix(maxGroups))
    }

    private func fileSHA256(path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return nil
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
