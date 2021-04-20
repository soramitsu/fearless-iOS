import XCTest
import SoraKeystore
import FearlessUtils
@testable import fearless

class PayoutRewardsServiceTests: XCTestCase {

    func testPayoutRewardsList() {
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

        let storageRequestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())
        let identityOperation = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let service = PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            chain: chain,
            subscanBaseURL: assetId.subscanUrl!,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            operationManager: operationManager,
            subscanOperationFactory: SubscanOperationFactory(),
            identityOperationFactory: identityOperation
        )

        let expectation = XCTestExpectation()

        let wrapper = service.fetchPayoutsOperationWrapper()
        wrapper.targetOperation.completionBlock = {
            do {
                let info = try wrapper.targetOperation.extractNoCancellableResultData()
                let totalReward = info.payouts.reduce(Decimal(0.0)) { $0 + $1.reward }
                let eras = info.payouts.map { $0.era }.sorted()
                Logger.shared.info("Active era: \(info.activeEra)")
                Logger.shared.info("Total reward: \(totalReward)")
                Logger.shared.info("Eras: \(eras)")
            } catch {
                Logger.shared.error("Did receive error: \(error)")
            }

            expectation.fulfill()
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        wait(for: [expectation], timeout: 30)
    }
}
