import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation

class StakingRewardDestConfirmTests: XCTestCase {

    func testRewardDestinationConfirmSuccess() throws {
        // given

        let view = MockStakingRewardDestConfirmViewProtocol()
        let wireframe = MockStakingRewardDestConfirmWireframeProtocol()

        let newPayoutAccount = AccountItem(address: "5Gh52T8TzDekJsosRp22SQ4uyGi8MfuwL8qMBJ1ASF1P8r8i",
                                           cryptoType: .sr25519,
                                           username: "new payout",
                                           publicKeyData: Data(repeating: 0, count: 32)
        )

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe, newPayout: newPayoutAccount)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in

            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()

            when(stub).didReceiveConfirmation(viewModel: any()).thenDoNothing()

            when(stub).localizationManager.get.then { nil }

            when(stub).didStartLoading().thenDoNothing()

            when(stub).didStopLoading().thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRewardDestConfirmViewProtocol,
        wireframe: MockStakingRewardDestConfirmWireframeProtocol,
        newPayout: AccountItem?
    ) throws -> StakingRewardDestConfirmPresenter {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let assetId = WalletAssetId(
            rawValue: primitiveFactory.createAssetForAddressType(chain.addressType).identifier
        )!

        let storageFacade = SubstrateStorageTestFacade()
        let operationManager = OperationManager()

        let nominatorAddress = settings.selectedAccount!.address
        let cryptoType = settings.selectedAccount!.cryptoType

        let singleValueProviderFactory = SingleValueProviderFactoryStub.westendNominatorStub()

        // save stash item

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository()

        let operationQueue = OperationQueue()
        let saveStashItemOperation = repository.saveOperation({ [stashItem] }, { [] })
        operationQueue.addOperations([saveStashItemOperation], waitUntilFinished: true)

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()
        let anyAccountRepository = AnyDataProviderRepository(accountRepository)

        // save controller and payout
        let controllerItem = settings.selectedAccount!
        let saveControllerOperation = anyAccountRepository
            .saveOperation({
                if let payout = newPayout {
                    return [controllerItem, payout]
                } else {
                    return [controllerItem]
                }
            }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: cryptoType)
        )

        let interactor = StakingRewardDestConfirmInteractor(
            settings: settings,
            singleValueProviderFactory: singleValueProviderFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            substrateProviderFactory: substrateProviderFactory,
            runtimeService: runtimeCodingService,
            operationManager: operationManager,
            accountRepository: anyAccountRepository,
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            chain: chain
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let rewardDestination = newPayout.map { RewardDestination.payout(account: $0) } ?? .restake

        let dataValidating = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: StakingRewardDestConfirmVMFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidating,
            chain: chain
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidating.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let rewardDestinationExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveFee(viewModel: any()).then { feeViewModel in
                if feeViewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveConfirmation(viewModel: any()).then { _ in
                rewardDestinationExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, rewardDestinationExpectation], timeout: 10)

        return presenter
    }

}
