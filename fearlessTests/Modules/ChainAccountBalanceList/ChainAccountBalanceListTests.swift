import XCTest
@testable import fearless
import SoraFoundation
import SoraKeystore
import BigInt
import Cuckoo
import RobinHood

class ChainAccountBalanceListTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAssetsGeneratedSuccessfully() throws {
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
//        let repository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository(
//            for: nil,
//            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
//        )
//        let operationQueue = OperationQueue()
//    
//        let saveChainsOperation = repository.saveOperation( { chains }, { [] })
//        operationQueue.addOperations([saveChainsOperation], waitUntilFinished: true)
//        
//        let view = MockChainAccountBalanceListViewProtocol()
//        let wireframe = MockChainAccountBalanceListWireframeProtocol()
//        
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
//        }
//
//        
//        let presenter = try createPresenter(for: view,
//                                               wireframe: wireframe,
//                                               operationQueue: operationQueue, repository: repository)
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
    }
}

extension ChainAccountBalanceListTests {
//    private func createPresenter(
//        for view: MockChainAccountBalanceListViewProtocol,
//        wireframe: MockChainAccountBalanceListWireframeProtocol,
//        operationQueue: OperationQueue,
//        repository: AnyDataProviderRepository<ChainModel>
//    ) throws -> ChainAccountBalanceListPresenter? {
//        let localizationManager = LocalizationManager.shared
//        let selectedAccount = AccountGenerator.generateMetaAccount()
//
//        let maybeInteractor = createInteractor(
//            selectedAccount: selectedAccount,
//            operationQueue: operationQueue,
//            repository: repository
//        )
//
//        guard let interactor = maybeInteractor else {
//            return nil
//        }
//
//        let presenter = ChainAccountBalanceListPresenter(interactor: interactor, wireframe: wireframe, assetBalanceFormatterFactory: AssetBalanceFormatterFactory(), localizationManager: localizationManager)
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
//        repository: AnyDataProviderRepository<ChainModel>
//    ) -> ChainAccountBalanceListInteractor? {
//
//        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
//            balance: BigUInt(1e+18)
//        )
//
//        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(priceData:  PriceData(price: "100", usdDayChange: 0.01))
//
//
//        return ChainAccountBalanceListInteractor(selectedMetaAccount: selectedAccount, repository: repository, walletLocalSubscriptionFactory: walletLocalSubscriptionFactory, operationQueue: operationQueue, priceLocalSubscriptionFactory: priceLocalSubscriptionFactory)
//    }
}
