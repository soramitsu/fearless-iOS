import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelChainInteractorSpy: ChainSelectionInteractorInputProtocol {
    private(set) var setupCount = 0

    func setup() {
        setupCount += 1
    }
}

final class CovJSelAssetWireframeSpy: CovJSheetSpy, AssetSelectionWireframeProtocol {
    private(set) var completions: [(chainAsset: ChainAsset, context: Any?)] = []

    func complete(on _: ChainSelectionViewProtocol, selecting chainAsset: ChainAsset, context: Any?) {
        completions.append((chainAsset, context))
    }
}

final class CovJSelChainWireframeSpy: CovJSheetSpy, ChainSelectionWireframeProtocol {
    private(set) var completions: [ChainModel?] = []

    func complete(on _: ChainSelectionViewProtocol, selecting chain: ChainModel?) {
        completions.append(chain)
    }
}

final class CovJSelAssetSelectionTests: XCTestCase {
    private func iconDetails(_ presenter: ChainSelectionPresenterProtocol, _ index: Int) throws -> SelectableIconDetailsListViewModel {
        try XCTUnwrap(presenter.item(at: index) as? SelectableIconDetailsListViewModel)
    }

    func testAssetSelectionListsFilteredAssetsMarksSelectionAndFormatsBalances() throws {
        let manager = try CovJSelFixture.manager()
        let locale = manager.selectedLocale
        let wallet = CovJSelFixture.substrateWallet()
        let dot = CovJSelFixture.asset("dot")
        let extra = CovJSelFixture.asset("extra", utility: false)
        let ksm = CovJSelFixture.asset("ksm", icon: UniversalWalletRegistry.bitcoinIconURL)
        let eth = CovJSelFixture.asset("eth")
        let polkadot = CovJSelFixture.chain(name: "Polkadot", assets: [dot, extra])
        let kusama = CovJSelFixture.chain(name: "Kusama", assets: [ksm])
        let ethereum = CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: [eth])
        let interactor = CovJSelChainInteractorSpy()
        let wireframe = CovJSelAssetWireframeSpy()
        let view = CovJSelListViewSpy()
        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { $0.isUtility },
            type: .normal(chainAsset: ChainAsset(chain: kusama, asset: ksm)),
            selectedMetaAccount: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: manager
        )
        presenter.view = view
        presenter.setup()
        XCTAssertEqual(interactor.setupCount, 1)

        presenter.didReceiveChains(result: .success([polkadot, kusama, ethereum]))
        XCTAssertEqual(presenter.numberOfItems, 2, "the non-utility asset and the chain without an account are left out")
        let first = try iconDetails(presenter, 0)
        XCTAssertEqual(first.title, "Polkadot")
        XCTAssertEqual(first.subtitle, "")
        XCTAssertNil(first.icon)
        XCTAssertFalse(first.isSelected)
        XCTAssertEqual(first.identifier, polkadot.chainId)
        let second = try iconDetails(presenter, 1)
        XCTAssertEqual(second.title, "Kusama")
        XCTAssertNotNil(second.icon)
        XCTAssertTrue(second.isSelected)
        XCTAssertTrue(CovJWait.until { view.reloadCount >= 1 })

        let dotKey = try CovJSelFixture.key(ChainAsset(chain: polkadot, asset: dot), wallet: wallet)
        let ksmKey = try CovJSelFixture.key(ChainAsset(chain: kusama, asset: ksm), wallet: wallet)
        presenter.didReceiveAccountInfo(result: .success(CovJSelFixture.info(free: CovJSelFixture.units(5))), for: dotKey)
        presenter.didReceiveAccountInfo(result: .success(nil), for: ksmKey)
        XCTAssertEqual(try iconDetails(presenter, 0).subtitle, CovJSelFixture.token(5, dot, locale: locale))
        XCTAssertEqual(try iconDetails(presenter, 1).subtitle, CovJSelFixture.token(0, ksm, locale: locale))
        presenter.didReceiveAccountInfo(result: .failure(CovJError("balance")), for: dotKey)
        XCTAssertEqual(try iconDetails(presenter, 0).subtitle, "")

        presenter.selectItem(at: 1)
        XCTAssertEqual(wireframe.completions.count, 1)
        XCTAssertEqual(wireframe.completions.first?.chainAsset.chain.chainId, kusama.chainId)
        XCTAssertEqual(wireframe.completions.first?.chainAsset.asset.id, "ksm")
        XCTAssertNil(wireframe.completions.first?.context)

        presenter.didReceiveChains(result: .failure(CovJError("chains")))
        XCTAssertEqual(wireframe.errors.compactMap { $0 as? CovJError }, [CovJError("chains")])
    }

    func testAssetSelectionNeedsAViewToCompleteAndReloadsOnlyWhenSetUp() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let dot = CovJSelFixture.asset("dot")
        let polkadot = CovJSelFixture.chain(name: "Polkadot", assets: [dot])
        let wireframe = CovJSelAssetWireframeSpy()
        let presenter = AssetSelectionPresenter(
            interactor: CovJSelChainInteractorSpy(),
            wireframe: wireframe,
            assetFilter: { _ in true },
            type: .pool(chainAsset: nil),
            selectedMetaAccount: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didReceiveChains(result: .success([polkadot]))
        CovJWait.drain()
        XCTAssertEqual(presenter.numberOfItems, 1)
        XCTAssertFalse(try iconDetails(presenter, 0).isSelected)
        presenter.selectItem(at: 0)
        XCTAssertTrue(wireframe.completions.isEmpty)

        let view = CovJSelListViewSpy()
        view.isSetup = false
        presenter.view = view
        presenter.applyLocalization()
        CovJWait.drain()
        XCTAssertEqual(view.reloadCount, 0)
        view.isSetup = true
        presenter.applyLocalization()
        XCTAssertTrue(CovJWait.until { view.reloadCount == 1 })
    }

    func testStakingSelectionAddsPoolRowsShowsStakeableBalanceAndCompletesWithType() throws {
        let manager = try CovJSelFixture.manager()
        let wallet = CovJSelFixture.substrateWallet()
        let pooledAsset = CovJSelFixture.asset("pooled")
        let plainAsset = CovJSelFixture.asset("plain")
        let pooled = CovJSelFixture.chain(name: "Pooled", options: [.poolStaking], assets: [pooledAsset])
        let plain = CovJSelFixture.chain(name: "Plain", assets: [plainAsset])
        let pooledChainAsset = ChainAsset(chain: pooled, asset: pooledAsset)
        let interactor = CovJSelChainInteractorSpy()
        let wireframe = CovJSelAssetWireframeSpy()
        let view = CovJSelListViewSpy()
        let presenter = StakingAssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { _ in true },
            type: .pool(chainAsset: pooledChainAsset),
            selectedMetaAccount: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: manager
        )
        presenter.view = view
        presenter.setup()
        XCTAssertEqual(interactor.setupCount, 1)

        presenter.didReceiveChains(result: .success([pooled, plain]))
        XCTAssertEqual(view.reloadCount, 1)
        let rows = try (0 ..< presenter.numberOfItems).map { try XCTUnwrap(presenter.item(at: $0) as? AssetSelectionTableViewCellModel) }
        XCTAssertEqual(rows.map(\.title), ["Pooled", "Plain", "Pooled"])
        XCTAssertEqual(rows.map(\.isSelected), [false, false, true])
        XCTAssertEqual(rows.map(\.stakingType.title), [nil, nil, "POOL"])
        XCTAssertEqual(rows[2].stakingType, .pool(chainAsset: pooledChainAsset))
        XCTAssertEqual(rows.map(\.subtitle), ["", "", ""])

        let key = try CovJSelFixture.key(pooledChainAsset, wallet: wallet)
        let info = CovJSelFixture.info(free: CovJSelFixture.units(3), frozen: CovJSelFixture.units(1))
        presenter.didReceiveAccountInfo(result: .success(info), for: key)
        XCTAssertTrue(CovJWait.until { view.reloadCount == 2 })
        let stakeable = CovJSelFixture.token(2, pooledAsset, locale: manager.selectedLocale)
        XCTAssertEqual((presenter.item(at: 0) as? AssetSelectionTableViewCellModel)?.subtitle, stakeable)
        XCTAssertEqual((presenter.item(at: 1) as? AssetSelectionTableViewCellModel)?.subtitle, "")
        XCTAssertEqual((presenter.item(at: 2) as? AssetSelectionTableViewCellModel)?.subtitle, stakeable)

        presenter.selectItem(at: 2)
        let completion = try XCTUnwrap(wireframe.completions.first)
        XCTAssertEqual(completion.chainAsset.chain.chainId, pooled.chainId)
        XCTAssertEqual(completion.context as? AssetSelectionStakingType, .pool(chainAsset: pooledChainAsset))

        presenter.applyLocalization()
        XCTAssertEqual(view.reloadCount, 3)
        presenter.didReceiveChains(result: .failure(CovJError("staking")))
        XCTAssertEqual(wireframe.errors.compactMap { $0 as? CovJError }, [CovJError("staking")])
    }

    func testStakingSelectionWithoutViewOrNotSetUpDoesNotComplete() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let asset = CovJSelFixture.asset("plain")
        let chain = CovJSelFixture.chain(name: "Plain", assets: [asset])
        let wireframe = CovJSelAssetWireframeSpy()
        let presenter = StakingAssetSelectionPresenter(
            interactor: CovJSelChainInteractorSpy(),
            wireframe: wireframe,
            assetFilter: { _ in true },
            type: .normal(chainAsset: ChainAsset(chain: chain, asset: asset)),
            selectedMetaAccount: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didReceiveChains(result: .success([chain]))
        XCTAssertTrue(try XCTUnwrap(presenter.item(at: 0) as? AssetSelectionTableViewCellModel).isSelected)
        presenter.selectItem(at: 0)
        XCTAssertTrue(wireframe.completions.isEmpty)
        let view = CovJSelListViewSpy()
        view.isSetup = false
        presenter.view = view
        presenter.applyLocalization()
        XCTAssertEqual(view.reloadCount, 0)
        let key = try CovJSelFixture.key(ChainAsset(chain: chain, asset: asset), wallet: wallet)
        presenter.didReceiveAccountInfo(result: .success(nil), for: key)
        XCTAssertTrue(CovJWait.until { view.reloadCount == 1 })
        let zero = CovJSelFixture.token(0, asset, locale: presenter.selectedLocale)
        XCTAssertEqual((presenter.item(at: 0) as? AssetSelectionTableViewCellModel)?.subtitle, zero)
    }

    func testStakingTypeTitlesAndChainAssets() {
        let chainAsset = CovJFixture.chainAsset(chainName: "Staking", symbol: "STK")
        XCTAssertNil(AssetSelectionStakingType.normal(chainAsset: chainAsset).title)
        XCTAssertEqual(AssetSelectionStakingType.pool(chainAsset: nil).title, "POOL")
        XCTAssertEqual(AssetSelectionStakingType.normal(chainAsset: chainAsset).chainAsset, chainAsset)
        XCTAssertEqual(AssetSelectionStakingType.pool(chainAsset: chainAsset).chainAsset, chainAsset)
        XCTAssertNil(AssetSelectionStakingType.pool(chainAsset: nil).chainAsset)
        XCTAssertNotEqual(AssetSelectionStakingType.pool(chainAsset: chainAsset), .normal(chainAsset: chainAsset))
        let model = AssetSelectionTableViewCellModel(title: "T", subtitle: nil, icon: nil, isSelected: true, stakingType: .pool(chainAsset: nil))
        XCTAssertEqual(model.title, "T")
        XCTAssertNil(model.subtitle)
        XCTAssertTrue(model.isSelected)
    }
}
