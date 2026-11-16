import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelChainOutputSpy: ChainSelectionInteractorOutputProtocol {
    private(set) var chainResults: [Result<[ChainModel], Error>] = []
    private(set) var accountInfoKeys: [ChainAssetKey] = []

    func didReceiveChains(result: Result<[ChainModel], Error>) {
        chainResults.append(result)
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for chainAssetKey: ChainAssetKey) {
        accountInfoKeys.append(chainAssetKey)
    }
}

final class CovJSelAssetSelectionDelegateSpy: AssetSelectionDelegate {
    private(set) var completions: [(chainAsset: ChainAsset, context: Any?)] = []

    func assetSelection(view _: ChainSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset, context: Any?) {
        completions.append((chainAsset, context))
    }
}

final class CovJSelChainSelectionDelegateSpy: ChainSelectionDelegate {
    private(set) var completions: [ChainModel?] = []

    func chainSelection(view _: ChainSelectionViewProtocol, didCompleteWith chain: ChainModel?) {
        completions.append(chain)
    }
}

final class CovJSelChainSelectionTests: XCTestCase {
    private func row(_ presenter: ChainSelectionPresenter, _ index: Int) throws -> SelectableIconDetailsListViewModel {
        try XCTUnwrap(presenter.item(at: index) as? SelectableIconDetailsListViewModel)
    }

    func testChainSelectionAddsAllNetworksRowFormatsUtilityBalanceAndMapsSelection() throws {
        let manager = try CovJSelFixture.manager()
        let locale = manager.selectedLocale
        let wallet = CovJSelFixture.substrateWallet()
        let utility = CovJSelFixture.asset("alpha")
        let token = CovJSelFixture.asset("token", utility: false)
        let alpha = CovJSelFixture.chain(name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [utility, token])
        let ethereum = CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: [CovJSelFixture.asset("eth")])
        let wireframe = CovJSelChainWireframeSpy()
        let interactor = CovJSelChainInteractorSpy()
        let view = CovJSelListViewSpy()
        let presenter = ChainSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: nil,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            includeAllNetworksCell: true,
            showBalances: true,
            selectedMetaAccount: wallet,
            localizationManager: manager
        )
        presenter.view = view
        presenter.setup()
        XCTAssertEqual(interactor.setupCount, 1)

        presenter.didReceiveChains(result: .success([alpha, ethereum]))
        XCTAssertEqual(presenter.numberOfItems, 2, "the chain without an account is not listed")
        let all = try row(presenter, 0)
        XCTAssertEqual(all.title, R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale.rLanguages))
        XCTAssertTrue(all.isSelected)
        XCTAssertNil(all.identifier)
        XCTAssertNil(all.icon)
        let alphaRow = try row(presenter, 1)
        XCTAssertEqual(alphaRow.title, "Alpha")
        XCTAssertEqual(alphaRow.identifier, alpha.chainId)
        XCTAssertNotNil(alphaRow.icon)
        XCTAssertFalse(alphaRow.isSelected)
        XCTAssertNil(alphaRow.subtitle, "no balance before the account info arrives")
        XCTAssertTrue(CovJWait.until { view.reloadCount >= 1 })

        let key = try CovJSelFixture.key(ChainAsset(chain: alpha, asset: utility), wallet: wallet)
        presenter.didReceiveAccountInfo(result: .success(nil), for: key)
        XCTAssertEqual(try row(presenter, 1).subtitle, CovJSelFixture.token(0, utility, locale: locale))
        presenter.didReceiveAccountInfo(result: .success(CovJSelFixture.info(free: CovJSelFixture.units(7))), for: key)
        XCTAssertEqual(try row(presenter, 1).subtitle, CovJSelFixture.token(7, utility, locale: locale))
        presenter.didReceiveAccountInfo(result: .failure(CovJError("info")), for: key)
        XCTAssertNil(try row(presenter, 1).subtitle)

        presenter.selectItem(at: 0)
        presenter.selectItem(at: 1)
        XCTAssertEqual(wireframe.completions.count, 2)
        XCTAssertNil(wireframe.completions[0], "the all-networks row completes without a chain")
        XCTAssertEqual(wireframe.completions[1]?.chainId, alpha.chainId)

        presenter.didReceiveChains(result: .failure(CovJError("chains")))
        XCTAssertEqual(wireframe.errors.compactMap { $0 as? CovJError }, [CovJError("chains")])
    }

    func testChainSelectionWithoutBalancesMarksSelectedChainAndHonoursSetupState() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let utility = CovJSelFixture.asset("beta")
        let beta = CovJSelFixture.chain(name: "Beta", assets: [utility])
        let wireframe = CovJSelChainWireframeSpy()
        let presenter = ChainSelectionPresenter(
            interactor: CovJSelChainInteractorSpy(),
            wireframe: wireframe,
            selectedChainId: beta.chainId,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            includeAllNetworksCell: false,
            showBalances: false,
            selectedMetaAccount: wallet,
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didReceiveChains(result: .success([beta]))
        let key = try CovJSelFixture.key(ChainAsset(chain: beta, asset: utility), wallet: wallet)
        presenter.didReceiveAccountInfo(result: .success(CovJSelFixture.info(free: CovJSelFixture.units(1))), for: key)
        CovJWait.drain()
        XCTAssertEqual(presenter.numberOfItems, 1)
        XCTAssertTrue(try row(presenter, 0).isSelected)
        XCTAssertNil(try row(presenter, 0).subtitle, "balances are hidden")

        presenter.selectItem(at: 0)
        XCTAssertTrue(wireframe.completions.isEmpty, "nothing completes without a view")

        let view = CovJSelListViewSpy()
        view.isSetup = false
        presenter.view = view
        presenter.applyLocalization()
        CovJWait.drain()
        XCTAssertEqual(view.reloadCount, 0)
        view.isSetup = true
        presenter.applyLocalization()
        XCTAssertTrue(CovJWait.until { view.reloadCount == 1 })
        presenter.selectItem(at: 0)
        XCTAssertEqual(wireframe.completions.first??.chainId, beta.chainId)
    }

    func testInteractorFetchesStoredChainsAndSubscribesToTheirBalances() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let asset = CovJSelFixture.asset("gamma")
        let gamma = CovJSelFixture.chain(name: "Gamma", assets: [asset])
        let adapter = CovJSelAccountInfoAdapterStub()
        let output = CovJSelChainOutputSpy()
        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: wallet,
            repository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>([gamma])),
            accountInfoSubscriptionAdapter: adapter,
            operationQueue: OperationQueue(),
            showBalances: true,
            chainModels: nil
        )
        interactor.presenter = output
        interactor.setup()
        XCTAssertTrue(CovJWait.until { output.chainResults.count == 1 })
        guard case let .success(chains) = output.chainResults.first else {
            return XCTFail("expected the stored chains")
        }
        XCTAssertEqual(chains.map(\.chainId), [gamma.chainId])
        XCTAssertEqual(adapter.subscriptions.first?.map(\.asset.id), ["gamma"])

        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let chainAsset = ChainAsset(chain: gamma, asset: asset)
        interactor.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: chainAsset)
        XCTAssertEqual(output.accountInfoKeys, [chainAsset.uniqueKey(accountId: accountId)])
    }

    func testInteractorReportsRepositoryFailureAndSkipsBalancesWhenHidden() {
        let wallet = CovJSelFixture.substrateWallet()
        let repository = CovJMemoryRepository<ChainModel>()
        repository.failure = CovJError("repository")
        let adapter = CovJSelAccountInfoAdapterStub()
        let output = CovJSelChainOutputSpy()
        let failing = ChainSelectionInteractor(
            selectedMetaAccount: wallet,
            repository: AnyDataProviderRepository(repository),
            accountInfoSubscriptionAdapter: adapter,
            operationQueue: OperationQueue(),
            showBalances: true,
            chainModels: nil
        )
        failing.presenter = output
        failing.setup()
        XCTAssertTrue(CovJWait.until { output.chainResults.count == 1 })
        guard case let .failure(error) = output.chainResults.first else {
            return XCTFail("expected a failure")
        }
        XCTAssertEqual(error as? CovJError, CovJError("repository"))

        let preset = CovJSelFixture.chain(name: "Preset", assets: [CovJSelFixture.asset("preset")])
        let hidden = ChainSelectionInteractor(
            selectedMetaAccount: wallet,
            repository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>()),
            accountInfoSubscriptionAdapter: adapter,
            operationQueue: OperationQueue(),
            showBalances: false,
            chainModels: [preset]
        )
        hidden.presenter = output
        hidden.setup()
        XCTAssertEqual(output.chainResults.count, 2, "preset chains are delivered synchronously")
        XCTAssertTrue(adapter.subscriptions.isEmpty)
    }

    func testAssetSelectionWireframeDismissesAndInformsDelegate() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let picker = UIViewController()
        host.controller.present(picker, animated: false)
        XCTAssertTrue(host.presented === picker)
        let delegate = CovJSelAssetSelectionDelegateSpy()
        let wireframe = AssetSelectionWireframe()
        wireframe.delegate = delegate
        let chainAsset = CovJFixture.chainAsset(chainName: "Wired", symbol: "WRD")
        wireframe.complete(on: CovJSelListViewSpy(controller: picker), selecting: chainAsset, context: "context")
        XCTAssertEqual(delegate.completions.first?.chainAsset, chainAsset)
        XCTAssertEqual(delegate.completions.first?.context as? String, "context")
        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }

    func testChainSelectionWireframeDismissesRootPickerAndPopsPushedOne() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let delegate = CovJSelChainSelectionDelegateSpy()
        let wireframe = ChainSelectionWireframe()
        wireframe.delegate = delegate
        let chain = CovJFixture.chain(name: "Wired")

        let rootPicker = UIViewController()
        host.controller.present(UINavigationController(rootViewController: rootPicker), animated: false)
        wireframe.complete(on: CovJSelListViewSpy(controller: rootPicker), selecting: chain)
        XCTAssertTrue(CovJWait.until { host.presented == nil })

        let pushedPicker = UIViewController()
        host.navigation.pushViewController(pushedPicker, animated: false)
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
        wireframe.complete(on: CovJSelListViewSpy(controller: pushedPicker), selecting: nil)
        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })

        XCTAssertEqual(delegate.completions.count, 2)
        XCTAssertEqual(delegate.completions.first??.chainId, chain.chainId)
        XCTAssertNil(delegate.completions.last ?? nil)
    }
}
