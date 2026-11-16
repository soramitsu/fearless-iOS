import XCTest
@testable import fearless
import SSFModels
import BigInt
import Cuckoo
import SoraFoundation
import RobinHood

class ChainSelectionTests: XCTestCase {
    func testSuccessfullSelection() {
        // given

        let chains = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: UInt16(index),
                hasCrowdloans: true
            )
        }
        let chainAccounts = Set(chains.map { chain in
            ChainAccountModel(
                chainId: chain.chainId,
                accountId: Data.random(of: 32)!,
                publicKey: Data.random(of: 32)!,
                cryptoType: 0,
                ethereumBased: false
            )
        })
        let selectedAccount = AccountGenerator.generateMetaAccount(with: chainAccounts)

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
                if presenter.numberOfItems == chains.count + 1 {
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

        presenter.selectItem(at: 1)

        // then

        wait(for: [completionExpectation], timeout: 10)
    }
}

extension ChainSelectionTests {
    /// The list leaves out chains the wallet has no account for. Tapping a row picked the chain at that position in
    /// the full chain list instead, so a row after a hidden chain selected the wrong chain.
    func testRowAfterAChainWithoutAnAccountSelectsTheChainItShows() {
        for includeAllNetworksCell in [false, true] {
            let chains = (0 ..< 3).map { index in
                ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: UInt16(index))
            }
            // An unknown crypto type leaves the wallet without a usable account on the middle chain.
            let unusable = ChainAccountModel(
                chainId: chains[1].chainId,
                accountId: Data(repeating: 1, count: 32),
                publicKey: Data(repeating: 2, count: 32),
                cryptoType: 99,
                ethereumBased: false
            )
            let wallet = AccountGenerator.generateMetaAccount(with: [unusable])
            let view = MockChainSelectionViewProtocol()
            let wireframe = MockChainSelectionWireframeProtocol()
            var selected: [ChainModel?] = []
            stub(view) { stub in
                stub.didReload().thenDoNothing()
            }
            stub(wireframe) { stub in
                stub.complete(on: any(), selecting: any()).then { _, chain in selected.append(chain) }
            }
            let presenter = ChainSelectionPresenter(
                interactor: MockChainSelectionInteractorInputProtocol(),
                wireframe: wireframe,
                selectedChainId: nil,
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
                includeAllNetworksCell: includeAllNetworksCell,
                showBalances: false,
                selectedMetaAccount: wallet,
                localizationManager: LocalizationManager.shared
            )
            presenter.view = view

            presenter.didReceiveChains(result: .success(chains))
            let offset = includeAllNetworksCell ? 1 : 0
            XCTAssertEqual(presenter.numberOfItems, 2 + offset, "the chain without an account has no row")
            presenter.selectItem(at: 1 + offset)
            if includeAllNetworksCell {
                presenter.selectItem(at: 0)
            }

            let expected: [ChainModel?] = includeAllNetworksCell ? [chains[2], nil] : [chains[2]]
            XCTAssertEqual(selected.map { $0?.chainId }, expected.map { $0?.chainId }, "all networks row: \(includeAllNetworksCell)")
        }
    }
}
