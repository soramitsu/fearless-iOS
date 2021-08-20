import Foundation
import RobinHood

/**
 *  Protocol is designed for fetching and saving files representing runtime
 *  types.
 */

protocol RuntimeFilesOperationFactoryProtocol {
    /**
     *  Constructs an operations wrapper that fetches data of
     *  common runtime types from corresponding file.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that fetches data of the
     *  runtime types from a file which matches concrete chain's id.
     *
     *  - Parameters:
     *      - chainId: Idetifier of a chain for which runtime types data
     *  must be fetched.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  chain's specific runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - chainId: Identifier of the chain for which runtime types must be stored
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveChainTypesOperation(
        for chainId: ChainModel.Id,
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

/**
 *  Class is designed to provide runtime types file management functions. Instance of the class
 *  contains instance of the `FileRepositoryProtocol` which performs file reading and
 *  writing and directory where files should be stored.
 *
 *  Common types file has `common-types` name. Chain type file hash $(chainId)-types name.
 */

final class RuntimeFilesOperationFactory {
    /// Engine that reads and writes files from filesystem
    let repository: FileRepositoryProtocol

    /// Path to the directory where files are stored
    let directoryPath: String

    /**
     *  Creates instance a new instance for runtime types management.
     *
     *  - Parameters:
     *      - repository: Engine that reads and writes files from filesystem;
     *      - directoryPath: Path to the directory where files are stored.
     */

    init(repository: FileRepositoryProtocol, directoryPath: String) {
        self.repository = repository
        self.directoryPath = directoryPath
    }

    private func fetchFileOperation(for fileName: String) -> CompoundOperationWrapper<Data?> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let readOperation = repository.readOperation(at: filePath)
        readOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: readOperation,
            dependencies: [createDirOperation]
        )
    }

    private func saveFileOperation(
        for fileName: String,
        data: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let writeOperation = repository.writeOperation(dataClosure: data, at: filePath)
        writeOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: writeOperation,
            dependencies: [createDirOperation]
        )
    }
}

extension RuntimeFilesOperationFactory: RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "common-types")
    }

    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "\(chainId)-types")
    }

    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "common-types", data: closure)
    }

    func saveChainTypesOperation(
        for chainId: ChainModel.Id, data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "\(chainId)-types", data: closure)
    }
}
