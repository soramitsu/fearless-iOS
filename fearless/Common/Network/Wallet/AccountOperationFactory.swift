import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import SSFUtils

protocol AccountOperationFactoryProtocol {
    func createGenisisHashOperation() -> BaseOperation<String>
    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String>
    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    let engine: JSONRPCEngine
    let requestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        engine: JSONRPCEngine,
        requestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.engine = engine
        self.requestFactory = requestFactory
        self.runtimeService = runtimeService
    }

    func createGenisisHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String> {
        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(
            engine: engine,
            method: RPCMethod.getBlockHash,
            parameters: [param]
        )
    }

    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: engine,
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
