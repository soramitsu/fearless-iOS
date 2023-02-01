import XCTest
@testable import fearless
import BigInt
import Cuckoo
import SoraFoundation
import RobinHood

class MockAccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    
    func subscribe(chainAsset: ChainAsset, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?, deliveryOn queue: DispatchQueue?) {
        let accountInfo  = AccountInfo(
            nonce: 0,
            consumers: 1,
            providers: 2,
            data: AccountData(
                free: BigUInt(100000),
                reserved: 0,
                miscFrozen: 0,
                feeFrozen: 0
            )
        )
        
            
        handler?.handleAccountInfo(result: .success(accountInfo), accountId: accountId, chainAsset: chainAsset)
    }
    
    func subscribe(chainsAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?, deliveryOn queue: DispatchQueue?) {
        chainsAssets.forEach { chainAsset in
            let accountInfo  = AccountInfo(
                nonce: 0,
                consumers: 1,
                providers: 2,
                data: AccountData(
                    free: BigUInt(100000),
                    reserved: 0,
                    miscFrozen: 0,
                    feeFrozen: 0
                )
            )
            
                
            handler?.handleAccountInfo(result: .success(accountInfo), accountId: Data.random(of: 32)!, chainAsset: chainAsset)
        }
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

        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: selectedAccount,
            repository: AnyDataProviderRepository(repository),
            accountInfoSubscriptionAdapter: MockAccountInfoSubscriptionAdapter(),
            operationQueue: operationQueue,
            showBalances: true,
            chainModels: nil
        )
        
        let selectedChain = chains.last!
        let selectedAsset = selectedChain.assets.first!
        let selectedChainAssetId = ChainAssetId(
            chainId: selectedChain.chainId,
            assetId: selectedAsset.assetId
        )
        let chainAsset = ChainAsset(chain: selectedChain, asset: selectedAsset.asset)

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { asset in asset.staking != nil },
            type: .normal(chainAsset: chainAsset),
            selectedMetaAccount: selectedAccount,
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
            stub.complete(on: any(), selecting: any(), context: any()).then { result in
                XCTAssertEqual(chains.first, result.1.chain)
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
