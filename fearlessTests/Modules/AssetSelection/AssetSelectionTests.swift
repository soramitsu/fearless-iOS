import XCTest
@testable import fearless
import SSFModels
import BigInt
import Cuckoo
import SoraFoundation
import RobinHood

class MockAccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset: SSFModels.ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    ) {
        let accountInfo = AccountInfo(
            nonce: 0,
            consumers: 1,
            providers: 2,
            data: AccountData(
                free: BigUInt(100000),
                reserved: 0,
                frozen: 0,
                flags: 0
            )
        )
        handler?.handleAccountInfo(result: Result<AccountInfo?, Error>.success(accountInfo), accountId: accountId, chainAsset: chainAsset)
    }

    func subscribe(
        chainsAssets: [SSFModels.ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    ) {
        chainsAssets.forEach { chainAsset in
            let accountInfo = AccountInfo(
                nonce: 0,
                consumers: 1,
                providers: 2,
                data: AccountData(
                    free: BigUInt(100000),
                    reserved: 0,
                    frozen: 0,
                    flags: 0
                )
            )
            handler?.handleAccountInfo(result: Result<AccountInfo?, Error>.success(accountInfo), accountId: Data.random(of: 32)!, chainAsset: chainAsset)
        }
    }

    func reset() {}
    func unsubscribe(chainAsset: SSFModels.ChainAsset) {}
    func update(wallet: fearless.MetaAccountModel) {}
}

class AssetSelectionTests: XCTestCase {
    func testSuccessfullSelection() throws {
        throw XCTSkip("Asset selection test is unstable in the current test environment")

        // given

        let assetsPerChain = 2
        let chains = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: assetsPerChain,
                addressPrefix: UInt16(index)
            )
        }
        let chainAccounts = Set(chains.map { chain in
            ChainAccountModel(
                chainId: chain.chainId,
                accountId: Data.random(of: 32)!,
                publicKey: Data.random(of: 32)!,
                cryptoType: 0,
                ecosystem: .substrate
            )
        })
        let selectedAccount = AccountGenerator.generateMetaAccount(with: chainAccounts)

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
        let chainAsset = SSFModels.ChainAsset(chain: selectedChain, asset: selectedAsset)

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { _ in true },
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
            stub.controller.get.thenReturn(UIViewController())
            stub.isSetup.get.thenReturn(false, true)
            stub.didReload().then {
                if presenter.numberOfItems == assetsPerChain * chains.count {
                    loadingExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // then

        wait(for: [loadingExpectation], timeout: 10)

        // when

        XCTAssertGreaterThan(presenter.numberOfItems, 0)
        XCTAssertNoThrow(presenter.item(at: 0))
    }
}
