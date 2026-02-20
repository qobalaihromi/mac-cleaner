import Foundation
import MacCleanerCore

@main
struct MacCleanerCLIApp {
    static func main() async {
        let service = CleanupService()
        let command = CLIParser.parse(arguments: CommandLine.arguments)

        switch command {
        case let .scan(json, includeReview, limit):
            let items = await service.scan(includeReviewItems: includeReview, limit: limit)
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(items), let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
            } else {
                printSummary(items: items)
                for item in items.prefix(50) {
                    let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
                    print("[\(item.category.rawValue)] [\(item.risk.rawValue)] \(size) - \(item.path)")
                }
                if items.count > 50 {
                    print("... and \(items.count - 50) more files")
                }
            }
            exit(0)

        case let .clean(yes, includeReview, limit):
            let items = await service.scan(includeReviewItems: includeReview, limit: limit)
            guard !items.isEmpty else {
                print("No files selected for cleanup.")
                exit(0)
            }

            printSummary(items: items)
            guard yes || confirm(prompt: "Continue and move selected files to Trash? [y/N]: ") else {
                print("Cancelled.")
                exit(0)
            }

            let result = service.clean(items: items)
            print("Cleanup success: \(result.succeeded.count)")
            print("Cleanup failed: \(result.failed.count)")
            print("Freed space: \(ByteCountFormatter.string(fromByteCount: result.totalFreedBytes, countStyle: .file))")

            if let manifestPath = result.manifestPath {
                print("Manifest: \(manifestPath)")
            }

            if !result.failed.isEmpty {
                for failure in result.failed.prefix(10) {
                    print("FAILED: \(failure.item.path) -> \(failure.error.localizedDescription)")
                }
                exit(1)
            }

            exit(0)

        case let .storage(json):
            do {
                let usage = try service.storageUsage()
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    if let data = try? encoder.encode(usage), let output = String(data: data, encoding: .utf8) {
                        print(output)
                    }
                } else {
                    let total = ByteCountFormatter.string(fromByteCount: usage.totalBytes, countStyle: .file)
                    let used = ByteCountFormatter.string(fromByteCount: usage.usedBytes, countStyle: .file)
                    let free = ByteCountFormatter.string(fromByteCount: usage.availableBytes, countStyle: .file)
                    let percent = Int((usage.usedRatio * 100).rounded())
                    print("Storage total : \(total)")
                    print("Storage used  : \(used) (\(percent)%)")
                    print("Storage free  : \(free)")
                }
                exit(0)
            } catch {
                print("Failed to read storage usage: \(error.localizedDescription)")
                exit(1)
            }

        case let .duplicates(json, includeReview, limit, groups):
            let duplicateGroups = await service.duplicateGroups(
                includeReviewItems: includeReview,
                limit: limit,
                maxGroups: groups
            )

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(duplicateGroups), let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
                exit(0)
            }

            guard !duplicateGroups.isEmpty else {
                print("No duplicate groups found in current scan scope.")
                exit(0)
            }

            let totalReclaimable = duplicateGroups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
            print("Duplicate groups: \(duplicateGroups.count)")
            print("Potential reclaimable: \(ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file))")

            for group in duplicateGroups {
                let eachSize = ByteCountFormatter.string(fromByteCount: group.fileSizeBytes, countStyle: .file)
                let reclaim = ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file)
                print("- \(group.duplicateCount)x \(eachSize) | reclaimable \(reclaim)")
                for path in group.files.prefix(5) {
                    print("  \(path)")
                }
                if group.files.count > 5 {
                    print("  ... and \(group.files.count - 5) more")
                }
            }
            exit(0)

        case .rules:
            let rules = service.rules()
            print("Active rules: \(rules.count)")
            for rule in rules {
                print("- [\(rule.category.rawValue)] \(rule.id) -> \(rule.rootPath) (minAgeDays: \(rule.minAgeDays))")
            }
            exit(0)

        case .initConfig:
            do {
                let path = try service.initConfig()
                print("Config initialized at: \(path)")
                exit(0)
            } catch {
                print("Failed to write config: \(error.localizedDescription)")
                exit(1)
            }

        case .help:
            CLIParser.printHelp()
            exit(0)
        }
    }
}
