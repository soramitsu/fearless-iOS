import XCTest
import UIKit
import SSFModels
import SoraFoundation
@testable import fearless

final class CovJLocksInteractor: BalanceLocksDetailInteractorInput {
    weak var output: BalanceLocksDetailInteractorOutput?
    func setup(with output: BalanceLocksDetailInteractorOutput) { self.output = output }
}

final class CovJLocksRouter: BalanceLocksDetailRouterInput {
    var dismissals = 0
    func dismiss(view: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJLocksOutput: BalanceLocksDetailViewOutput {
    var loads = 0
    var closes = 0
    func didLoad(view: BalanceLocksDetailViewInput) { loads += 1 }
    func didTapCloseButton() { closes += 1 }
}

final class CovJLocksView: UIViewController, BalanceLocksDetailViewInput {
    var staking: BalanceLocksDetailStakingViewModel?
    var pools: BalanceLocksDetailPoolViewModel?
    var liquidity: LocalizableResource<BalanceViewModelProtocol>?
    var governance: LocalizableResource<BalanceViewModelProtocol>?
    var crowdloan: LocalizableResource<BalanceViewModelProtocol>?
    var hint: String?
    var total: LocalizableResource<BalanceViewModelProtocol>?
    var frozen: LocalizableResource<BalanceViewModelProtocol>?
    var blocked: LocalizableResource<BalanceViewModelProtocol>?
    var onBlocked: (() -> Void)?
    func didReceiveStakingLocksViewModel(_ viewModel: BalanceLocksDetailStakingViewModel?) async { staking = viewModel }
    func didReceivePoolLocksViewModel(_ viewModel: BalanceLocksDetailPoolViewModel?) async { pools = viewModel }
    func didReceiveLiquidityPoolLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { liquidity = viewModel }
    func didReceiveGovernanceLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { governance = viewModel }
    func didReceiveCrowdloanLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { crowdloan = viewModel }
    func didReceiveVestingHint(_ hint: String?) async { self.hint = hint }
    func didReceiveTotalLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { total = viewModel }
    func didReceiveAssetFrozenViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { frozen = viewModel }
    func didReceiveAssetBlockedViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async { blocked = viewModel; onBlocked?() }
}

final class CovJBalanceLocksTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private func chainAsset(paraId: String? = nil) throws -> ChainAsset {
        let asset = CovJFixture.asset(id: "locks-asset", symbol: "LCK", precision: 12)
        let chain = ChainModel(rank: nil, disabled: false, chainId: "locks", parentId: paraId == nil ? nil : "relay",
                               paraId: paraId, name: "Locks", xcm: nil, nodes: [], addressPrefix: 42, types: nil,
                               icon: nil, options: nil, externalApi: nil, selectedNode: nil, customNodes: nil,
                               iosMinAppVersion: nil, identityChain: nil)
        chain.assets = [asset]
        return ChainAsset(chain: chain, asset: asset)
    }

    private func balanceFactory(_ asset: ChainAsset) -> BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: asset.assetDisplayInfo, selectedMetaAccount: AccountGenerator.generateMetaAccount())
    }

    private func amount(_ value: LocalizableResource<BalanceViewModelProtocol>?) -> String? {
        value?.value(for: locale).amount
    }

    func testFactoryFormatsEachCategoryAndSumsAllLockComponents() throws {
        let asset = try chainAsset()
        let balances = balanceFactory(asset)
        let factory = BalanceLockDetailViewModelFactoryDefault(balanceViewModelFactory: balances, chainAsset: asset)
        let locks = StakingLocks(staked: 10, unstaking: 3, redeemable: 2, claimable: 1)
        let staking = try XCTUnwrap(factory.buildStakingLocksViewModel(stakingLocks: locks, priceData: nil))
        let pools = try XCTUnwrap(factory.buildNominationPoolLocksViewModel(nominationPoolLocks: locks, priceData: nil))
        let expected: (Decimal) -> String = { value in
            balances.balanceFromPrice(value, priceData: nil, usageCase: .detailsCrypto).value(for: self.locale).amount
        }
        XCTAssertEqual(amount(staking.stakedViewModel), expected(10))
        XCTAssertEqual(amount(staking.unstakingViewModel), expected(3))
        XCTAssertEqual(amount(staking.redeemableViewModel), expected(2))
        XCTAssertEqual(amount(pools.stakedViewModel), expected(10))
        XCTAssertEqual(amount(pools.unstakingViewModel), expected(3))
        XCTAssertEqual(amount(pools.redeemableViewModel), expected(2))
        XCTAssertEqual(amount(pools.claimableViewModel), expected(1))
        XCTAssertNil(factory.buildLiquidityPoolLocksViewModel())
        XCTAssertEqual(amount(factory.buildGovernanceLocksViewModel(governanceLocks: 4, priceData: nil)), expected(4))
        XCTAssertEqual(amount(factory.buildCrowdloanLocksViewModel(crowdloanLocks: 5, priceData: nil)), expected(5))
        XCTAssertEqual(amount(factory.buildVestingLocksViewModel(vestingLocks: 6, priceData: nil)), expected(6))
        XCTAssertEqual(amount(factory.buildAssetFrozenViewModel(assetFrozen: 7, priceData: nil)), expected(7))
        XCTAssertEqual(amount(factory.buildAssetBlockedViewModel(assetBlocked: 8, priceData: nil)), expected(8))
        XCTAssertEqual(amount(factory.buildTotalLocksViewModel(stakingLocks: locks, nominationPoolLocks: locks,
                                                               governanceLocks: 4, crowdloanLocks: 5, vestingLocks: 6, priceData: nil)), expected(47))
        XCTAssertEqual(amount(factory.buildTotalLocksViewModel(stakingLocks: nil, nominationPoolLocks: nil,
                                                               governanceLocks: nil, crowdloanLocks: nil, vestingLocks: nil, priceData: nil)), expected(0))
        XCTAssertEqual(amount(factory.buildStakingLocksViewModel(stakingLocks: nil, priceData: nil)?.stakedViewModel), expected(0))
        XCTAssertEqual(amount(factory.buildNominationPoolLocksViewModel(nominationPoolLocks: nil, priceData: nil)?.claimableViewModel), expected(0))
    }

    @MainActor func testPresenterWaitsForAllCategoriesAndReplacesErrorsWithZero() async throws {
        let asset = try chainAsset()
        let balances = balanceFactory(asset)
        let interactor = CovJLocksInteractor()
        let router = CovJLocksRouter()
        let presenter = BalanceLocksDetailPresenter(
            interactor: interactor, router: router, localizationManager: LocalizationManager.shared, logger: Logger.shared,
            viewModelFactory: BalanceLockDetailViewModelFactoryDefault(balanceViewModelFactory: balances, chainAsset: asset),
            chainAsset: asset, selectedCurrency: Currency.defaultCurrency()
        )
        let view = CovJLocksView()
        let loading = expectation(description: "Initial placeholders")
        view.onBlocked = { loading.fulfill() }
        presenter.didLoad(view: view)
        await fulfillment(of: [loading], timeout: 5)
        view.onBlocked = nil
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertNil(view.total)
        let locks = StakingLocks(staked: 10, unstaking: 3, redeemable: 2, claimable: 1)
        await presenter.didReceiveStakingLocks(locks)
        await presenter.didReceiveNominationPoolLocks(locks)
        await presenter.didReceiveGovernanceLocks(4)
        await presenter.didReceiveCrowdloanLocks(5)
        XCTAssertNil(view.total)
        XCTAssertNotNil(view.crowdloan)
        await presenter.didReceiveVestingLocks(6)
        let expected = balances.balanceFromPrice(47, priceData: nil, usageCase: .detailsCrypto).value(for: locale).amount
        XCTAssertEqual(amount(view.total), expected)
        await presenter.didReceiveAssetFrozen(7)
        await presenter.didReceiveAssetBlocked(8)
        XCTAssertNotNil(view.frozen)
        XCTAssertNotNil(view.blocked)
        let error = NSError(domain: "fixture", code: 1)
        await presenter.didReceiveStakingLocksError(error)
        await presenter.didReceiveNominationPoolLocksError(error)
        await presenter.didReceiveGovernanceLocksError(error)
        await presenter.didReceiveCrowdloanLocksError(error)
        await presenter.didReceiveVestingLocksError(error)
        await presenter.didReceiveAssetFrozenError(error)
        await presenter.didReceiveAssetBlockedError(error)
        let zero = balances.balanceFromPrice(0, priceData: nil, usageCase: .detailsCrypto).value(for: locale).amount
        XCTAssertEqual(amount(view.total), zero)
        XCTAssertEqual(amount(view.staking?.stakedViewModel), zero)
        XCTAssertEqual(amount(view.pools?.claimableViewModel), zero)
        XCTAssertEqual(amount(view.governance), zero)
        XCTAssertEqual(amount(view.frozen), zero)
        XCTAssertEqual(amount(view.blocked), zero)
        XCTAssertNil(view.crowdloan)
        presenter.didTapCloseButton()
        XCTAssertEqual(router.dismissals, 1)
    }

    @MainActor func testAssetHubVestingUsesRelayTimeHintAndSuppressesLegacyCrowdloan() async throws {
        let asset = try chainAsset(paraId: "1000")
        let balances = balanceFactory(asset)
        let presenter = BalanceLocksDetailPresenter(
            interactor: CovJLocksInteractor(), router: CovJLocksRouter(), localizationManager: LocalizationManager.shared, logger: nil,
            viewModelFactory: BalanceLockDetailViewModelFactoryDefault(balanceViewModelFactory: balances, chainAsset: asset),
            chainAsset: asset, selectedCurrency: Currency.defaultCurrency()
        )
        let view = CovJLocksView()
        let loading = expectation(description: "Initial placeholders")
        view.onBlocked = { loading.fulfill() }
        presenter.didLoad(view: view)
        await fulfillment(of: [loading], timeout: 5)
        view.onBlocked = nil
        await presenter.didReceiveCrowdloanLocks(9)
        XCTAssertNil(view.crowdloan)
        await presenter.didReceiveVestingLocks(6)
        XCTAssertEqual(amount(view.crowdloan), balances.balanceFromPrice(6, priceData: nil, usageCase: .detailsCrypto).value(for: locale).amount)
        XCTAssertEqual(view.hint, "Uses Relay Chain block time on Asset Hubs")
    }

    @MainActor func testControllerBindsBalancesAndVestingHintAcrossContexts() async throws {
        for legacy in [true, false] {
            let output = CovJLocksOutput()
            let controller = BalanceLocksDetailViewController(output: output, isLegacyCrowdloanContext: legacy,
                                                              localizationManager: LocalizationManager.shared)
            let window = try CovJViewFixture.host(controller)
            defer { window.isHidden = true }
            let balance = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: "10 DOT", price: "$50") }
            await controller.didReceiveGovernanceLocksViewModel(balance)
            await controller.didReceiveCrowdloanLocksViewModel(balance)
            await controller.didReceiveStakingLocksViewModel(.init(stakedViewModel: balance, unstakingViewModel: balance, redeemableViewModel: balance))
            await controller.didReceivePoolLocksViewModel(.init(stakedViewModel: balance, unstakingViewModel: balance,
                                                               redeemableViewModel: balance, claimableViewModel: balance))
            await controller.didReceiveLiquidityPoolLocksViewModel(balance)
            await controller.didReceiveTotalLocksViewModel(balance)
            await controller.didReceiveAssetFrozenViewModel(balance)
            await controller.didReceiveAssetBlockedViewModel(balance)
            await controller.didReceiveVestingHint("Unlocking")
            let root = controller.rootView
            XCTAssertEqual(output.loads, 1)
            XCTAssertEqual(root.stakingStakedRowView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.poolsClaimableRowView.valueBottom.text, "$50")
            XCTAssertEqual(root.governanceView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.liquidityPoolsView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.totalView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.frozenView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.blockedView.valueTop.text, "10 DOT")
            XCTAssertEqual(root.crowdloansView.valueBottom.text, "Unlocking")
            XCTAssertFalse(root.crowdloansView.isHidden)
            XCTAssertEqual(root.crowdloansView.titleLabel.text, legacy
                           ? NSLocalizedString("asset.legacy_crowdloan", value: "Legacy crowdloan", comment: "")
                           : NSLocalizedString("asset.vesting", value: "Vesting", comment: ""))
            root.navigationBar.backButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(output.closes, 1)
            await controller.didReceiveCrowdloanLocksViewModel(nil)
            XCTAssertTrue(root.crowdloansView.isHidden)
        }
    }
}
