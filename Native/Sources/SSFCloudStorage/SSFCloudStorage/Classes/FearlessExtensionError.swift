import Foundation

public enum FearlessExtensionError: Error {
    case cantRemoveExtensionBackup
    case backupNotFound
}

extension FearlessExtensionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cantRemoveExtensionBackup:
            return "Can not remove fearless extension backup"
        case .backupNotFound:
            return "Backup is not found"
        }
    }
}
