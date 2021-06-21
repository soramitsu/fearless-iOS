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

            let settings = SettingsManager.shared
            let assetId = WalletAssetId.kusama
            let chain = assetId.chain!
            let selectedAccount = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"

            try! AccountCreationHelper.createAccountFromMnemonic(
                cryptoType: .sr25519,
                networkType: chain,
                keychain: Keychain(),
                settings: settings
            )

            WebSocketService.shared.setup()
            let connection = WebSocketService.shared.connection!
            let runtimeService = RuntimeRegistryFacade.sharedService
            runtimeService.setup()

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
                runtimeService: runtimeService,
                chain: chain
            )

            let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
                OperationCombiningService(operationManager: operationManager) {
                    let crowdloans = try crowdloansWrapper.targetOperation.extractNoCancellableResultData()
                    return crowdloans.map { crowdloan in
                        crowdloanOperationFactory.fetchContributionOperation(
                            connection: connection,
                            runtimeService: runtimeService,
                            address: selectedAccount,
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
