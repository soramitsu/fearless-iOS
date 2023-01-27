// import FearlessUtils
// import Foundation
// import RobinHood
//
// protocol RuntimeFilesOperationFacadeProtocol {
//    func fetchDefaultOperation(for chain: Chain) -> CompoundOperationWrapper<Data?>
//    func fetchNetworkOperation(for chain: Chain) -> CompoundOperationWrapper<Data?>
//
//    func saveDefaultOperation(
//        for chain: Chain,
//        data closure: @escaping () throws -> Data
//    ) -> CompoundOperationWrapper<Void>
//
//    func saveNetworkOperation(
//        for chain: Chain,
//        data closure: @escaping () throws -> Data
//    ) -> CompoundOperationWrapper<Void>
// }
//
// enum RuntimeFilesOperationFacadeError: Error {
//    case missingBundleFile
// }
//
// private enum RuntimeFileType: String {
//    case `default`
//    case network
//
//    func fileName(for chain: Chain) -> String {
//        "\(chain.rawValue)-\(rawValue).json"
//    }
// }
//
// final class RuntimeFilesOperationFacade {
//    let repository: FileRepositoryProtocol
//    let directoryPath: String
//
//    init(repository: FileRepositoryProtocol, directoryPath: String) {
//        self.repository = repository
//        self.directoryPath = directoryPath
//    }
//
//    private func fetchFileOperation(fileName: String, fallback: String) -> CompoundOperationWrapper<Data?> {
//        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)
//
//        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)
//
//        let fileExistsOperation = repository.fileExistsOperation(at: filePath)
//        fileExistsOperation.addDependency(createDirOperation)
//
//        let copyOperation = repository.copyOperation(from: fallback, to: filePath)
//        copyOperation.configurationBlock = {
//            do {
//                let exists = try fileExistsOperation
//                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//                if exists == .file {
//                    copyOperation.result = .success(())
//                }
//
//            } catch {
//                copyOperation.result = .failure(error)
//            }
//        }
//
//        copyOperation.addDependency(fileExistsOperation)
//
//        let readOperation = repository.readOperation(at: filePath)
//        readOperation.configurationBlock = {
//            do {
//                try copyOperation.extractResultData()
//            } catch {
//                readOperation.result = .failure(error)
//            }
//        }
//        readOperation.addDependency(copyOperation)
//
//        let dependencies = [createDirOperation, fileExistsOperation, copyOperation]
//
//        return CompoundOperationWrapper(
//            targetOperation: readOperation,
//            dependencies: dependencies
//        )
//    }
//
//    private func saveFileOperation(
//        fileName: String,
//        data: @escaping () throws -> Data
//    ) -> CompoundOperationWrapper<Void> {
//        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)
//
//        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)
//
//        let writeOperation = repository.writeOperation(dataClosure: data, at: filePath)
//        writeOperation.addDependency(createDirOperation)
//
//        return CompoundOperationWrapper(
//            targetOperation: writeOperation,
//            dependencies: [createDirOperation]
//        )
//    }
// }
//
// extension RuntimeFilesOperationFacade: RuntimeFilesOperationFacadeProtocol {
//    private func fileName(for chain: Chain, type: RuntimeFileType) -> String {
//        type.fileName(for: chain)
//    }
//
//    private func fetchLocalFile(
//        _ file: String?,
//        for chain: Chain,
//        type: RuntimeFileType
//    ) -> CompoundOperationWrapper<Data?> {
//        guard let localFilePath = file else {
//            return CompoundOperationWrapper.createWithError(
//                RuntimeRegistryServiceError.unexpectedCoderFetchingFailure
//            )
//        }
//
//        return fetchFileOperation(
//            fileName: fileName(for: chain, type: type),
//            fallback: localFilePath
//        )
//    }
//
//    func fetchDefaultOperation(for chain: Chain) -> CompoundOperationWrapper<Data?> {
//        fetchLocalFile(chain.preparedDefaultTypeDefPath(), for: chain, type: .default)
//    }
//
//    func fetchNetworkOperation(for chain: Chain) -> CompoundOperationWrapper<Data?> {
//        fetchLocalFile(chain.preparedNetworkTypeDefPath(), for: chain, type: .network)
//    }
//
//    func saveDefaultOperation(
//        for chain: Chain,
//        data closure: @escaping () throws -> Data
//    ) -> CompoundOperationWrapper<Void> {
//        saveFileOperation(
//            fileName: fileName(for: chain, type: .default),
//            data: closure
//        )
//    }
//
//    func saveNetworkOperation(
//        for chain: Chain,
//        data closure: @escaping () throws -> Data
//    ) -> CompoundOperationWrapper<Void> {
//        saveFileOperation(
//            fileName: fileName(for: chain, type: .network),
//            data: closure
//        )
//    }
// }
