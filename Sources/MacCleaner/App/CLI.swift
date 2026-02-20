import Foundation

enum CLICommand {
    case scan(json: Bool, includeReview: Bool, limit: Int?)
    case clean(yes: Bool, includeReview: Bool, limit: Int?)
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
          mac-cleaner rules
          mac-cleaner init-config

        Notes:
          - Default clean target only includes risk=safe files.
          - --include-review will include risk=review files too.
          - Cleanup always moves files to Trash, not permanent delete.
          - Config file: ~/.mac-cleaner/config.json
        """)
    }

    private static func intValue(after flag: String, in flags: [String]) -> Int? {
        guard let idx = flags.firstIndex(of: flag), flags.indices.contains(idx + 1) else {
            return nil
        }
        return Int(flags[idx + 1])
    }
}
