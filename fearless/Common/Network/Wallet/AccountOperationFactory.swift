import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import SSFUtils
import SSFModels

protocol AccountOperationFactoryProtocol {
    func createGenisisHashOperation() -> BaseOperation<String>
    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String>
    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private let requestFactory: StorageRequestFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainId: ChainModel.Id

    init(
        requestFactory: StorageRequestFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        chainId: ChainModel.Id
    ) {
        self.requestFactory = requestFactory
        self.chainRegistry = chainRegistry
        self.chainId = chainId
    }

    func createGenisisHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return BaseOperation.createWithError(ChainRegistryError.connectionUnavailable)
        }

        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash,
            parameters: [param]
        )
    }

    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.account
        )

        let mapOperation = ClosureOperation<AccountInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
