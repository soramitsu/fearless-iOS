import XCTest
@testable import fearless
import BigInt
import Cuckoo
import SoraFoundation
import RobinHood

class MockAccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    func subscribe(chain: ChainModel,
                   accountId: AccountId,
                   handler: AccountInfoSubscriptionAdapterHandler?) {
    }
    func subscribe(chains: [ChainModel], handler: AccountInfoSubscriptionAdapterHandler?) {
    }
    func reset() {
    }
}

class AssetSelectionTests: XCTestCase {
    func testSuccessfullSelection() {
        // given

        let selectedAccount = AccountGenerator.generateMetaAccount()

        let assetsPerChain = 2
        let chains = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: assetsPerChain,
                addressPrefix: UInt16(index),
                staking: .relayChain
            )
        }

        let view = MockChainSelectionViewProtocol()
        let wireframe = MockAssetSelectionWireframeProtocol()

        let storageFacade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let operationQueue = OperationQueue()

        let saveChainsOperation = repository.saveOperation( { chains }, { [] })
        operationQueue.addOperations([saveChainsOperation], waitUntilFinished: true)

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        let interactor = ChainSelectionInteractor(selectedMetaAccount: selectedAccount,
                                                  repository: AnyDataProviderRepository(repository),
                                                  accountInfoSubscriptionAdapter: MockAccountInfoSubscriptionAdapter(),
                                                  operationQueue: operationQueue)

        let selectedChain = chains.last!
        let selectedAsset = selectedChain.assets.first!
        let selectedChainAssetId = ChainAssetId(
            chainId: selectedChain.chainId,
            assetId: selectedAsset.assetId
        )

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { asset in asset.staking != nil },
            selectedChainAssetId: selectedChainAssetId,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let loadingExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)
            stub.didReload().then {
                if presenter.numberOfItems == assetsPerChain * chains.count {
                    loadingExpectation.fulfill()
                }
            }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.complete(on: any(), selecting: any()).then { (_, chainAsset) in
                XCTAssertEqual(chains.first, chainAsset.chain)
                XCTAssertNotNil(selectedAsset.staking)
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
