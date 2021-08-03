import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation

class StakingRebondSetupTests: XCTestCase {

    func testRebondSetupAndAmountProvidingSuccess() throws {
        // given

        let view = MockStakingRebondSetupViewProtocol()
        let wireframe = MockStakingRebondSetupWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe)

        stub(view) { stub in
            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(view: any(), amount: any()).then { (view, amount) in
                completionExpectation.fulfill()
            }
        }

        presenter.updateAmount(0.01)
        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRebondSetupViewProtocol,
        wireframe: MockStakingRebondSetupWireframeProtocol
    ) throws -> StakingRebondSetupPresenterProtocol {
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

        let singleValueProviderFactory = try StakingRebondMock.addNomination(
            to: SingleValueProviderFactoryStub.westendNominatorStub(),
            address: nominatorAddress
        )

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

        // save controller
        let controllerItem = settings.selectedAccount!
        let saveControllerOperation = anyAccountRepository.saveOperation({ [controllerItem] }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: cryptoType)
        )

        let interactor = StakingRebondSetupInteractor(
            settings: settings,
            substrateProviderFactory: substrateProviderFactory,
            singleValueProviderFactory: singleValueProviderFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager,
            accountRepository: anyAccountRepository,
            feeProxy: ExtrinsicFeeProxy(),
            chain: chain,
            assetId: assetId
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAsset(viewModel: any()).then { viewModel in
                if let balance = viewModel.value(for: Locale.current).balance, !balance.isEmpty {
                    assetExpectation.fulfill()
                }
            }

            when(stub).didReceiveFee(viewModel: any()).then { viewModel in
                if let fee = viewModel?.value(for: Locale.current).amount, !fee.isEmpty {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveInput(viewModel: any()).then { _ in
                inputExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [inputExpectation, assetExpectation, feeExpectation], timeout: 10)

        return presenter
    }
}
