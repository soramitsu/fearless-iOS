import XCTest
@testable import fearless
import FearlessUtils
import RobinHood
import IrohaCrypto

class ChainRegistryIntegrationTests: XCTestCase {
    func testNetworkConnection() {
        let address = "12hAtDZJGt4of3m2GqZcUCVAjZPALfvPwvtUTFZPQUbdX1Ud"

        let chainRegistry = ChainRegistryFactory.createDefaultRegistry(
            from: SubstrateStorageTestFacade()
        )

        chainRegistry.syncUp()

        var availableChains: [ChainModel.Id: ChainModel] = [:]

        let syncExpectation = XCTestExpectation()

        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { changes in
            for change in changes {
                switch change {
                case let .insert(chain):
                    availableChains[chain.chainId] = chain
                case let .update(chain):
                    availableChains[chain.chainId] = chain
                case let .delete(deletedIdentifier):
                    availableChains[deletedIdentifier] = nil
                }
            }

            if !changes.isEmpty {
                syncExpectation.fulfill()
            }
        }

        wait(for: [syncExpectation], timeout: 10)

        guard !availableChains.isEmpty else {
            XCTFail("Unexpected empty chains")
            return
        }

        Logger.shared.info("Did receive chains: \(availableChains)")

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let addressFactory = SS58AddressFactory()
        let accountId = try! addressFactory.accountId(from: address)

        let operationQueue = OperationQueue()

        for chain in availableChains.values {
            guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
                XCTFail("Unexpected missing connection for chain: \(chain.chainId)")
                return
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                XCTFail("Unexpected missing runtime provider: \(chain.chainId)")
                return
            }

            guard let utilityAsset = chain.assets.first(where: { $0.isUtility }) else {
                XCTFail("Can't find utility asset: \(chain.chainId)")
                return
            }

            let factoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = storageOperationFactory.queryItems(
                engine: connection,
                keyParams: {
                    [accountId]
                }, factory: {
                    try factoryOperation.extractNoCancellableResultData()
                }, storagePath: .account
            )

            queryWrapper.addDependency(operations: [factoryOperation])

            let mapOperation: BaseOperation<AccountInfo?> = ClosureOperation {
                guard let response = try queryWrapper.targetOperation.extractNoCancellableResultData()
                        .first else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return response.value
            }

            mapOperation.addDependency(queryWrapper.targetOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [factoryOperation] + queryWrapper.allOperations)

            let queryExpectation = XCTestExpectation()

            wrapper.targetOperation.completionBlock = {
                queryExpectation.fulfill()
            }

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            do {
                let accountInfo = try wrapper.targetOperation.extractNoCancellableResultData()
                let available = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.available,
                        precision: Int16(utilityAsset.precision)
                    ) ?? 0.0
                } ?? 0.0

                let balanceString = available.stringWithPointSeparator + " \(utilityAsset.symbol)"
                Logger.shared.info("Balance: \(balanceString)")
            } catch {
                Logger.shared.error("Couldn't fetch from chain \(chain.chainId): \(error)")
            }
        }
    }
}
