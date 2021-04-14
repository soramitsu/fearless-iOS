import XCTest
import SoraKeystore
import FearlessUtils
@testable import fearless

class PayoutRewardsServiceTests: XCTestCase {

    func testPayoutRewardsList() {
        let operationManager = OperationManagerFacade.sharedManager

        let settings = SettingsManager.shared
        let assetId = WalletAssetId.westend
        let chain = assetId.chain!
        let selectedAccount = "5CZbJ5rdD9QmxzYKXqTLLKWQTCDnKPd8LnUqmuJejquwZj6V"

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

        let service = PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            chain: chain,
            subscanBaseURL: assetId.subscanUrl!,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            operationManager: operationManager,
            subscanOperationFactory: SubscanOperationFactory()
        )

        let expectation = XCTestExpectation()
        service.fetchPayoutRewards { result in
            print(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
    }
}
