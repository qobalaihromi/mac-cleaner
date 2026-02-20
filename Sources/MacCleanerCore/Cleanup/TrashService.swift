import Foundation

public protocol TrashServicing {
    func moveToTrash(path: String) throws -> String
}

public struct TrashService: TrashServicing {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func moveToTrash(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        return (resultingURL as URL?)?.path ?? ""
    }
}
