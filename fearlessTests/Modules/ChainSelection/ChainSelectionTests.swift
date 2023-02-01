import XCTest
@testable import fearless
import BigInt
import Cuckoo
import SoraFoundation
import RobinHood

class ChainSelectionTests: XCTestCase {
    func testSuccessfullSelection() {
        // given

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let chains = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: UInt16(index),
                hasCrowdloans: true
            )
        }

        let view = MockChainSelectionViewProtocol()
        let wireframe = MockChainSelectionWireframeProtocol()

        let storageFacade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let operationQueue = OperationQueue()

        let saveChainsOperation = repository.saveOperation( { chains }, { [] })
        operationQueue.addOperations([saveChainsOperation], waitUntilFinished: true)

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub()

        let adapter = MockAccountInfoSubscriptionAdapter()
        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: selectedAccount,
            repository: AnyDataProviderRepository(repository),
            accountInfoSubscriptionAdapter: adapter,
            operationQueue: operationQueue,
            showBalances: true,
            chainModels: chains
        )
    
        let presenter = ChainSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: chains.first!.chainId,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            includeAllNetworksCell: true,
            showBalances: true,
            selectedMetaAccount: selectedAccount,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let loadingExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)
            stub.didReload().then {
                if presenter.numberOfItems == chains.count {
                    loadingExpectation.fulfill()
                }
            }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.complete(on: any(), selecting: any()).then { (_, chain) in
                XCTAssertEqual(chains.first, chain)
                completionExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [loadingExpectation], timeout: 10)

        // when

        presenter.selectItem(at: 0)

        // then

        wait(for: [completionExpectation], timeout: 10)
    }
}
