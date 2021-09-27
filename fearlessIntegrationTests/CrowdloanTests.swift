import XCTest
@testable import fearless
import FearlessUtils
import RobinHood
import SoraKeystore
import IrohaCrypto

class CrowdloanTests: XCTestCase {
    func testFetchContributions() {
        do {
            let operationManager = OperationManagerFacade.sharedManager
            let chainId = Chain.kusama.genesisHash
            let selectedAccountId = try "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf".toAccountId()

            let chainRegistry = ChainRegistryFactory.createDefaultRegistry(
                from: SubstrateStorageTestFacade()
            )

            chainRegistry.syncUp()

            let syncCompletionExpectation = XCTestExpectation()
            chainRegistry.chainsSubscribe(self, runningInQueue: .main) { changes in
                if !changes.isEmpty {
                    syncCompletionExpectation.fulfill()
                }
            }

            wait(for: [syncCompletionExpectation], timeout: 10)

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: operationManager
            )

            let crowdloanOperationFactory = CrowdloanOperationFactory(
                requestOperationFactory: storageRequestFactory,
                operationManager: operationManager
            )

            let crowdloansWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
                connection: connection,
                runtimeService: runtimeService
            )

            let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
                OperationCombiningService(operationManager: operationManager) {
                    let crowdloans = try crowdloansWrapper.targetOperation.extractNoCancellableResultData()
                    return crowdloans.map { crowdloan in
                        crowdloanOperationFactory.fetchContributionOperation(
                            connection: connection,
                            runtimeService: runtimeService,
                            accountId: selectedAccountId,
                            trieIndex: crowdloan.fundInfo.trieIndex
                        )
                    }
                }.longrunOperation()

            contributionsOperation.addDependency(crowdloansWrapper.targetOperation)

            let expectation = XCTestExpectation()

            contributionsOperation.completionBlock = {
                expectation.fulfill()
            }

            let allOperations = crowdloansWrapper.allOperations + [contributionsOperation]

            operationManager.enqueue(operations: allOperations, in: .transient)

            wait(for: [expectation], timeout: 30)

            let contributions = try contributionsOperation.extractNoCancellableResultData()

            Logger.shared.info("Did receive contributions")
            Logger.shared.info("\(contributions)")

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
}
