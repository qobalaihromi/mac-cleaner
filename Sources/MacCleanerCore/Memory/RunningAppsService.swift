import AppKit
import Foundation

public struct RunningAppInfo: Identifiable, Codable {
    public let id: Int32
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    public let memoryBytes: Int64
    public let isActive: Bool
    public let isSystemCritical: Bool
    public let canCloseSafely: Bool
    public let recommendedToClose: Bool
    public let recommendationReason: String

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String?,
        memoryBytes: Int64,
        isActive: Bool,
        isSystemCritical: Bool,
        canCloseSafely: Bool,
        recommendedToClose: Bool,
        recommendationReason: String
    ) {
        self.id = pid
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.isActive = isActive
        self.isSystemCritical = isSystemCritical
        self.canCloseSafely = canCloseSafely
        self.recommendedToClose = recommendedToClose
        self.recommendationReason = recommendationReason
    }
}

public protocol RunningAppsProviding {
    func listRunningApps() -> [RunningAppInfo]
    func closeApp(pid: Int32) -> Bool
}

public struct RunningAppsService: RunningAppsProviding {
    public init() {}

    public func listRunningApps() -> [RunningAppInfo] {
        let rssByPID = residentMemoryMapByPID()
        let ownBundleID = Bundle.main.bundleIdentifier

        let running = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != nil || $0.localizedName != nil }

        let mapped: [RunningAppInfo] = running.map { app in
            let pid = app.processIdentifier
            let name = app.localizedName ?? "Unknown"
            let bundleID = app.bundleIdentifier
            let rss = rssByPID[pid] ?? 0
            let isSystem = isSystemCritical(app: app)
            let isOwnApp = bundleID == ownBundleID
            let canClose = !isSystem && !isOwnApp

            let recommended = canClose && !app.isActive && rss >= 500 * 1024 * 1024
            let reason: String
            if isSystem {
                reason = "System app - avoid closing"
            } else if isOwnApp {
                reason = "Current app"
            } else if app.isActive {
                reason = "Currently active"
            } else if recommended {
                reason = "High memory and inactive"
            } else {
                reason = "Normal"
            }

            return RunningAppInfo(
                pid: pid,
                name: name,
                bundleIdentifier: bundleID,
                memoryBytes: rss,
                isActive: app.isActive,
                isSystemCritical: isSystem,
                canCloseSafely: canClose,
                recommendedToClose: recommended,
                recommendationReason: reason
            )
        }

        return mapped.sorted { lhs, rhs in
            if lhs.recommendedToClose != rhs.recommendedToClose {
                return lhs.recommendedToClose && !rhs.recommendedToClose
            }
            return lhs.memoryBytes > rhs.memoryBytes
        }
    }

    public func closeApp(pid: Int32) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return false
        }

        guard !isSystemCritical(app: app) else {
            return false
        }

        return app.terminate()
    }

    private func isSystemCritical(app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        let critical = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.SystemUIServer"
        ]
        if critical.contains(bundleID) { return true }
        return bundleID.hasPrefix("com.apple.")
    }

    private func residentMemoryMapByPID() -> [Int32: Int64] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return [:]
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var result: [Int32: Int64] = [:]
        for raw in output.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            let parts = line.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }
            guard let pid = Int32(parts[0]), let rssKB = Int64(parts[1]) else { continue }
            result[pid] = rssKB * 1024
        }
        return result
    }
}
