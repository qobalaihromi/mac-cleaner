import Foundation

public enum DIContainer {
    public static func makeCleanupUseCase() -> CleanupUseCase {
        let config = AppConfig.load()
        return CleanupUseCase(config: config)
    }
}
