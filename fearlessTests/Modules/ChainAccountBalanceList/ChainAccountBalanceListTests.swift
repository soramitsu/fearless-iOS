//import XCTest
//@testable import fearless
//import SoraFoundation
//import SoraKeystore
//import BigInt
//import Cuckoo
//import RobinHood
//
//// Should be fixed after merge skeletons logic. We have several "didReceive(state: ) calls, so we can't know then chains actually loaded
//
//class ChainAccountBalanceListTests: XCTestCase {
//
//    override func setUp() {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }
//
//    func testAssetsGeneratedSuccessfully() throws {
//        let assetsPerChain: Int = 2
//        let chains = (0..<10).map { index in
//            ChainModelGenerator.generateChain(
//                generatingAssets: assetsPerChain,
//                addressPrefix: UInt16(index),
//                hasCrowdloans: true
//            )
//        }
//        
//        let storageFacade = SubstrateStorageTestFacade()
//        let chainRepository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository(
//            for: nil,
//            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
//        )
//        let operationQueue = OperationQueue()
//    
//        let saveChainsOperation = chainRepository.saveOperation( { chains }, { [] })
//        operationQueue.addOperations([saveChainsOperation], waitUntilFinished: true)
//        
//        let view = MockChainAccountBalanceListViewProtocol()
//        let wireframe = MockChainAccountBalanceListWireframeProtocol()
//        
//        let chainsGotExpectation = XCTestExpectation()
//        let stateCompletionExpectation = XCTestExpectation()
//        
//        var actualViewModel: ChainAccountBalanceListViewModel?
//
//        stub(view) { stub in
//            stub.isSetup.get.thenReturn(false, true)
//
//            stub.didReceive(state: any()).then { state in
//                if case let .loaded(viewModel) = state {
//                    actualViewModel = viewModel
//                    stateCompletionExpectation.fulfill()
//                }
//            }
//            
//            stub.didReceive(locale: any()).thenDoNothing()
//        }
//        
//        let assetRepository = SubstrateDataStorageFacade.shared.createRepository(
//            mapper: AnyCoreDataMapper(AssetModelMapper())
//        )
//        var assets: [AssetModel] = []
//        chains.forEach { chain in
//            chain.assets.forEach { assets.append($0.asset) }
//        }
//        
//        let saveAssetsOperation = assetRepository.saveOperation( { assets }, { [] })
//        operationQueue.addOperations([saveAssetsOperation], waitUntilFinished: true)
//
//        let presenter = try createPresenter(for: view,
//                                               wireframe: wireframe,
//                                               operationQueue: operationQueue,
//                                               chainRepository: AnyDataProviderRepository(chainRepository),
//                                               assetRepository: AnyDataProviderRepository(assetRepository))
//        
//        // when
//
//        presenter?.setup()
//
//        // then
//
//        wait(for: [stateCompletionExpectation], timeout: 10)
//
//        let actualViewModelsCount = actualViewModel?.accountViewModels.count
//
//        let expectedViewModelsCount = assetsPerChain * chains.count
//
//        XCTAssertEqual(actualViewModelsCount, expectedViewModelsCount)
//    }
//}
//
//extension ChainAccountBalanceListTests {
//    private func createPresenter(
//        for view: ChainAccountBalanceListViewProtocol,
//        wireframe: ChainAccountBalanceListWireframeProtocol,
//        operationQueue: OperationQueue,
//        chainRepository: AnyDataProviderRepository<ChainModel>,
//        assetRepository: AnyDataProviderRepository<AssetModel>
//    ) throws -> ChainAccountBalanceListPresenter? {
//        let localizationManager = LocalizationManager.shared
//        let selectedAccount = AccountGenerator.generateMetaAccount()
//        
//        let maybeInteractor = createInteractor(
//            selectedAccount: selectedAccount,
//            operationQueue: operationQueue,
//            chainRepository: chainRepository,
//            assetRepository: assetRepository
//        )
//
//        guard let interactor = maybeInteractor else {
//            return nil
//        }
//        
//        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
//        let viewModelFactory = ChainAccountBalanceListViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)
//
//        let presenter = ChainAccountBalanceListPresenter(interactor: interactor,
//                                                         wireframe: wireframe,
//                                                         viewModelFactory: viewModelFactory,
//                                                         localizationManager: localizationManager)
//
//        presenter.view = view
//        interactor.presenter = presenter
//
//        return presenter
//    }
//
//    private func createInteractor(
//        selectedAccount: MetaAccountModel,
//        operationQueue: OperationQueue,
//        chainRepository: AnyDataProviderRepository<ChainModel>,
//        assetRepository: AnyDataProviderRepository<AssetModel>
//    ) -> ChainAccountBalanceListInteractor? {
//      
//        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
//            balance: BigUInt(1e+18)
//        )
//        
//        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(priceData:  PriceData(price: "100", usdDayChange: 0.01))
//
//        let adapter = AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
//                                                     selectedMetaAccount: selectedAccount)
//        return ChainAccountBalanceListInteractor(selectedMetaAccount: selectedAccount,
//                                                 chainRepository: chainRepository,
//                                                 assetRepository: assetRepository,
//                                                 accountInfoSubscriptionAdapter: adapter,
//                                                 operationQueue: operationQueue,
//                                                 priceLocalSubscriber: priceLocalSubscriber,
//                                                 eventCenter: EventCenter.shared)
//    }
//}
