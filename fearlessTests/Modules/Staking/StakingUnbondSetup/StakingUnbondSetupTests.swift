import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation

class StakingUnbondSetupTests: XCTestCase {

    func testUnbondingSetupAndAmountProvidingSuccess() throws {
        // given

        let view = MockStakingUnbondSetupViewProtocol()
        let wireframe = MockStakingUnbondSetupWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe)

        let inputViewModelReloaded = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveInput(viewModel: any()).then { viewModel in
                inputViewModelReloaded.fulfill()
            }

            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
            when(stub).didReceiveBonding(duration: any()).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(view: any(), amount: any()).then { (view, amount) in
                completionExpectation.fulfill()
            }
        }

        presenter.selectAmountPercentage(0.75)
        presenter.proceed()

        // then

        wait(for: [inputViewModelReloaded, completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingUnbondSetupViewProtocol,
        wireframe: MockStakingUnbondSetupWireframeProtocol
    ) throws -> StakingUnbondSetupPresenterProtocol {
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

        // save controller
        let controllerItem = settings.selectedAccount!
        let saveControllerOperation = anyAccountRepository.saveOperation({ [controllerItem] }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: cryptoType)
        )

        let interactor = StakingUnbondSetupInteractor(
            assetId: assetId,
            chain: chain,
            singleValueProviderFactory: singleValueProviderFactory,
            substrateProviderFactory: substrateProviderFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            feeProxy: ExtrinsicFeeProxy(),
            accountRepository: anyAccountRepository,
            settings: settings,
            runtimeService: runtimeCodingService,
            operationManager: operationManager
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chain: chain
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let bondingDurationExpectation = XCTestExpectation()

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

            when(stub).didReceiveBonding(duration: any()).then { viewModel in
                if !viewModel.value(for: Locale.current).isEmpty {
                    bondingDurationExpectation.fulfill()
                }
            }

            when(stub).didReceiveInput(viewModel: any()).then { _ in
                inputExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [inputExpectation, assetExpectation, feeExpectation, bondingDurationExpectation], timeout: 10)

        return presenter
    }
}
