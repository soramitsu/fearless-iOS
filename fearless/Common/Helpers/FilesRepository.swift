import Foundation
import RobinHood

protocol FileRepositoryProtocol {
    func createDirectoryIfNeededOperation(at path: String) -> BaseOperation<Void>
    func fileExistsOperation(at path: String) -> BaseOperation<FileExistence>
    func readOperation(at path: String) -> BaseOperation<Data?>
    func writeOperation(dataClosure: @escaping () throws -> Data, at path: String) -> BaseOperation<Void>
    func copyOperation(from fromPath: String, to toPath: String) -> BaseOperation<Void>
    func removeOperation(at path: String) -> BaseOperation<Void>
}

enum FileExistence {
    case notExists
    case directory
    case file
}

/**
 *  Repository implements wrapper around shared file manager to enable operations
 *  usage for files management.
 *
 *  Note: It is important to use native shared file manager because it gives
 *  thread safety from the box.
 */

final class FileRepository: FileRepositoryProtocol {
    func createDirectoryIfNeededOperation(at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                || !isDirectory.boolValue {
                try FileManager.default
                    .createDirectory(atPath: path, withIntermediateDirectories: true)
            }
        }
    }

    func fileExistsOperation(at path: String) -> BaseOperation<FileExistence> {
        ClosureOperation {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            if !exists {
                return .notExists
            } else {
                return isDirectory.boolValue ? .directory : .file
            }
        }
    }

    func readOperation(at path: String) -> BaseOperation<Data?> {
        ClosureOperation {
            FileManager.default.contents(atPath: path)
        }
    }

    func writeOperation(dataClosure: @escaping () throws -> Data, at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            let data = try dataClosure()
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    func copyOperation(from fromPath: String, to toPath: String) -> BaseOperation<Void> {
        ClosureOperation {
            try FileManager.default.copyItem(atPath: fromPath, toPath: toPath)
        }
    }

    func removeOperation(at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
    }
}
