//import XCTest
//@testable import fearless
//import Cuckoo
//import RobinHood
//import SSFUtils
//import SoraKeystore
//import SoraFoundation
//
//class BondMoreConfirmTests: XCTestCase {
//
//    func testBondMoreConfirmationSuccess() throws {
//        // given
//
//        let view = MockStakingBondMoreConfirmationViewProtocol()
//        let wireframe = MockStakingBondMoreConfirmationWireframeProtocol()
//
//        // when
//
//        let presenter = try setupPresenter(for: 0.1, view: view, wireframe: wireframe)
//
//        let completionExpectation = XCTestExpectation()
//
//        stub(view) { stub in
//            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
//
//            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
//
//            when(stub).didReceiveConfirmation(viewModel: any()).thenDoNothing()
//
//            when(stub).localizationManager.get.then { nil }
//
//            when(stub).didStartLoading().thenDoNothing()
//
//            when(stub).didStopLoading().thenDoNothing()
//        }
//
//        stub(wireframe) { stub in
//            when(stub).complete(from: any()).then { _ in
//                completionExpectation.fulfill()
//            }
//        }
//
//        presenter.confirm()
//
//        // then
//
//        wait(for: [completionExpectation], timeout: 10.0)
//    }
//
//    private func setupPresenter(
//        for inputAmount: Decimal,
//        view: MockStakingBondMoreConfirmationViewProtocol,
//        wireframe: MockStakingBondMoreConfirmationWireframeProtocol
//    ) throws -> StakingBondMoreConfirmationPresenterProtocol {
//        // given
//
//        let settings = SelectedWalletSettings(
//            storageFacade: UserDataStorageTestFacade(),
//            operationQueue: OperationQueue()
//        )
//        let keychain = InMemoryKeychain()
//
//        try AccountCreationHelper.createMetaAccountFromMnemonic(cryptoType: .sr25519,
//                                                                keychain: keychain,
//                                                                settings: settings)
//
//        let asset = ChainModelGenerator.generateAssetWithId("testAssetId")
//
//        let storageFacade = SubstrateStorageTestFacade()
//        let operationManager = OperationManager()
//
//        let nominatorAddress = "nominator address"
//        let cryptoType = settings.value?.substrateCryptoType
//
//        let singleValueProviderFactory = SingleValueProviderFactoryStub.westendNominatorStub()
//
//        // save stash item
//
//        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
//        let repository: CoreDataRepository<StashItem, CDStashItem> =
//            storageFacade.createRepository()
//
//        let operationQueue = OperationQueue()
//        let saveStashItemOperation = repository.saveOperation({ [stashItem] }, { [] })
//        operationQueue.addOperations([saveStashItemOperation], waitUntilFinished: true)
//
//        let substrateProviderFactory = SubstrateDataProviderFactory(
//            facade: storageFacade,
//            operationManager: operationManager
//        )
//
//        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()
//
//        let accountRepository = AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())
//
//        // save controller
//        let controllerItem = settings.value!
//        let saveControllerOperation = accountRepository.saveOperation({ [controllerItem] }, { [] })
//        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)
//
//        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
//            extrinsicService: ExtrinsicServiceStub.dummy(),
//            signingWraper: try DummySigner(cryptoType: CryptoType(rawValue: cryptoType!) ?? .sr25519)
//        )
//
//        let interactor = StakingBondMoreInteractor(
//            settings: settings,
//            singleValueProviderFactory: singleValueProviderFactory,
//            substrateProviderFactory: substrateProviderFactory,
//            accountRepository: accountRepository,
//            extrinsicServiceFactory: extrinsicServiceFactory,
//            feeProxy: ExtrinsicFeeProxy(),
//            runtimeService: runtimeCodingService,
//            operationManager: operationManager,
//            chain: chain,
//            assetId: assetId
//        )
//
//        let balanceViewModelFactory = BalanceViewModelFactory(
//            walletPrimitiveFactory: primitiveFactory,
//            selectedAddressType: chain.addressType,
//            limit: StakingConstants.maxAmount
//        )
//
//        let confirmViewModelFactory = StakingBondMoreConfirmViewModelFactory(asset: asset)
//
//        let presenter = StakingBondMoreConfirmationPresenter(
//            interactor: interactor,
//            wireframe: wireframe,
//            inputAmount: inputAmount,
//            confirmViewModelFactory: confirmViewModelFactory,
//            balanceViewModelFactory: balanceViewModelFactory,
//            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
//            chain: chain
//        )
//
//        presenter.view = view
//        interactor.presenter = presenter
//
//        // when
//
//        let feeExpectation = XCTestExpectation()
//        let assetExpectation = XCTestExpectation()
//        let confirmViewModelExpectation = XCTestExpectation()
//
//        stub(view) { stub in
//            when(stub).didReceiveAsset(viewModel: any()).then { viewModel in
//                if let balance = viewModel.value(for: Locale.current).balance, !balance.isEmpty {
//                    assetExpectation.fulfill()
//                }
//            }
//
//            when(stub).didReceiveFee(viewModel: any()).then { viewModel in
//                if let fee = viewModel?.value(for: Locale.current).amount, !fee.isEmpty {
//                    feeExpectation.fulfill()
//                }
//            }
//
//            when(stub).didReceiveConfirmation(viewModel: any()).then { viewModel in
//                confirmViewModelExpectation.fulfill()
//            }
//        }
//
//        presenter.setup()
//
//        // then
//
//        wait(for: [assetExpectation, feeExpectation, confirmViewModelExpectation], timeout: 10)
//
//        return presenter
//    }
//
//}
