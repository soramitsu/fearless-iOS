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
        let selectedAccount = "5DEwU2U97RnBHCpfwHMDfJC7pqAdfWaPFib9wiZcr2ephSfT"

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
            switch result {
            case .success(let info):
                let totalReward = info.payouts.reduce(Decimal(0.0)) { $0 + $1.reward }
                let eras = info.payouts.map { $0.era }.sorted()
                Logger.shared.info("Active era: \(info.activeEra)")
                Logger.shared.info("Total reward: \(totalReward)")
                Logger.shared.info("Eras: \(eras)")
            case .failure(let error):
                Logger.shared.error("Did receive error: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
    }
}
