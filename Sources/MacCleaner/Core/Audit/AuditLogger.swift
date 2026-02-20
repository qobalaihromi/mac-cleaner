import Foundation

public protocol AuditLogging {
    func log(_ message: String)
}

public struct AuditLogger: AuditLogging {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init() {}

    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[AUDIT] \(timestamp) \(message)")
    }
}
