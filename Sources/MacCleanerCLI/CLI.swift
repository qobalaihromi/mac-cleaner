import Foundation
import MacCleanerCore

enum CLICommand {
    case scan(json: Bool, includeReview: Bool, limit: Int?)
    case clean(yes: Bool, includeReview: Bool, limit: Int?)
    case cleanDuplicates(yes: Bool, includeReview: Bool, limit: Int?, groups: Int?)
    case restore(yes: Bool, latest: Bool, manifestPath: String?)
    case storage(json: Bool)
    case duplicates(json: Bool, includeReview: Bool, limit: Int?, groups: Int?)
    case rules
    case initConfig
    case help
}

enum CLIParser {
    static func parse(arguments: [String]) -> CLICommand {
        guard arguments.count >= 2 else { return .help }

        let command = arguments[1]
        let flags = Array(arguments.dropFirst(2))

        switch command {
        case "scan":
            return .scan(
                json: flags.contains("--json"),
                includeReview: flags.contains("--include-review"),
                limit: intValue(after: "--limit", in: flags)
            )
        case "clean":
            return .clean(
                yes: flags.contains("--yes"),
                includeReview: flags.contains("--include-review"),
                limit: intValue(after: "--limit", in: flags)
            )
        case "clean-duplicates":
            return .cleanDuplicates(
                yes: flags.contains("--yes"),
                includeReview: flags.contains("--include-review"),
                limit: intValue(after: "--limit", in: flags),
                groups: intValue(after: "--groups", in: flags)
            )
        case "restore":
            return .restore(
                yes: flags.contains("--yes"),
                latest: flags.contains("--latest"),
                manifestPath: stringValue(after: "--manifest", in: flags)
            )
        case "storage":
            return .storage(json: flags.contains("--json"))
        case "duplicates":
            return .duplicates(
                json: flags.contains("--json"),
                includeReview: flags.contains("--include-review"),
                limit: intValue(after: "--limit", in: flags),
                groups: intValue(after: "--groups", in: flags)
            )
        case "rules":
            return .rules
        case "init-config":
            return .initConfig
        case "help", "--help", "-h":
            return .help
        default:
            return .help
        }
    }

    static func printHelp() {
        print("""
        mac-cleaner - Safe macOS junk cleaner

        Usage:
          mac-cleaner scan [--json] [--include-review] [--limit N]
          mac-cleaner clean [--yes] [--include-review] [--limit N]
          mac-cleaner clean-duplicates [--yes] [--include-review] [--limit N] [--groups N]
          mac-cleaner restore [--latest] [--manifest PATH] [--yes]
          mac-cleaner storage [--json]
          mac-cleaner duplicates [--json] [--include-review] [--limit N] [--groups N]
          mac-cleaner rules
          mac-cleaner init-config

        Notes:
          - Default clean target only includes risk=safe files.
          - --include-review will include risk=review files too.
          - Cleanup always moves files to Trash, not permanent delete.
          - Restore will move files from Trash back to original paths.
          - Config file: ~/.mac-cleaner/config.json
        """)
    }

    private static func intValue(after flag: String, in flags: [String]) -> Int? {
        guard let idx = flags.firstIndex(of: flag), flags.indices.contains(idx + 1) else {
            return nil
        }
        return Int(flags[idx + 1])
    }

    private static func stringValue(after flag: String, in flags: [String]) -> String? {
        guard let idx = flags.firstIndex(of: flag), flags.indices.contains(idx + 1) else {
            return nil
        }
        return flags[idx + 1]
    }
}

func printSummary(items: [FileItem]) {
    let summary = CleanupSummary(items: items)
    print("Candidates: \(summary.totalFiles) files")
    print("Potential savings: \(ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))")

    for category in JunkCategory.allCases {
        let count = summary.filesByCategory[category] ?? 0
        guard count > 0 else { continue }
        let bytes = summary.bytesByCategory[category] ?? 0
        print("- \(category.rawValue): \(count) files, \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))")
    }
}

func confirm(prompt: String) -> Bool {
    print(prompt, terminator: "")
    guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
        return false
    }
    return response == "y" || response == "yes"
}
