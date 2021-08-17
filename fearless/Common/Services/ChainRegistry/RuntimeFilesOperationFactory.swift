import Foundation
import RobinHood

protocol RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>
    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>

    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>

    func saveChainTypesOperation(
        for chainId: ChainModel.Id,
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

final class RuntimeFilesOperationFactory {
    let repository: FileRepositoryProtocol
    let directoryPath: String

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
