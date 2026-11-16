import XCTest
import UIKit
import BigInt
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJFinClaimInteractor: ClaimCrowdloanRewardsInteractorInput {
    weak var output: ClaimCrowdloanRewardsInteractorOutput?
    var setups = 0
    var estimates = 0
    var submits = 0

    func setup(with output: ClaimCrowdloanRewardsInteractorOutput) {
        self.output = output
        setups += 1
    }

    func estimateFee() { estimates += 1 }
    func submit() { submits += 1 }
}

final class CovJFinClaimRouter: CovJSheetSpy, ClaimCrowdloanRewardsRouterInput {
    var dismissals = 0
    var completions: [(title: String, chainAssetId: ChainAssetId)] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset: ChainAsset) {
        completions.append((title, chainAsset.chainAssetId))
    }
}

final class CovJFinClaimView: UIViewController, ClaimCrowdloanRewardsViewInput {
    var fees: [BalanceViewModelProtocol?] = []
    var vestings: [BalanceViewModelProtocol?] = []
    var balances: [BalanceViewModelProtocol?] = []
    var stakes: [LocalizableResource<StakeAmountViewModel>] = []
    var hints: [DetailsTriangularedAttributedViewModel?] = []

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) { fees.append(feeViewModel) }
    func didReceiveVestingViewModel(_ viewModel: BalanceViewModelProtocol?) { vestings.append(viewModel) }
    func didReceiveBalanceViewModel(_ viewModel: BalanceViewModelProtocol?) { balances.append(viewModel) }
    func didReceiveStakeAmountViewModel(_ stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>) { stakes.append(stakeAmountViewModel) }
    func didReceiveHintViewModel(_ hintViewModel: DetailsTriangularedAttributedViewModel?) { hints.append(hintViewModel) }
}

final class CovJFinAuthorizer: SubmissionAuthorizing {
    var allow = true
    var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(allow)
    }
}

final class CovJFinClaimViewOutput: ClaimCrowdloanRewardsViewOutput {
    var loads = 0
    var backs = 0
    var confirms = 0
    func didLoad(view _: ClaimCrowdloanRewardsViewInput) { loads += 1 }
    func backButtonClicked() { backs += 1 }
    func confirmButtonClicked() { confirms += 1 }
}

/// A `ControllerBackedProtocol` controller, so routers can present from it.
final class CovJFinBackedController: UIViewController, ControllerBackedProtocol {}

final class CovJFinClaimCrowdloanPresenterTests: XCTestCase {
    private var locale: Locale { LocalizationManager.shared.selectedLocale }

    private func assetHubChainAsset() -> ChainAsset {
        let asset = CovJFixture.asset(id: "dot-hub", symbol: "dot", precision: 10)
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "asset-hub-\(UUID().uuidString)", parentId: "relay", paraId: "1000",
            name: "Asset Hub", xcm: nil, nodes: [], addressPrefix: 0, types: nil, icon: nil, options: nil, externalApi: nil,
            selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil
        )
        chain.assets = [asset]
        return ChainAsset(chain: chain, asset: asset)
    }

    private func amount(_ value: Decimal, _ chainAsset: ChainAsset, wallet: MetaAccountModel) -> String {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet)
            .balanceFromPrice(value, priceData: nil, usageCase: .detailsCrypto).value(for: locale).amount
    }

    private func makeFactory(_ chainAsset: ChainAsset, wallet: MetaAccountModel) -> ClaimCrowdloanRewardViewModelFactory {
        ClaimCrowdloanRewardViewModelFactory(
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet),
            chainAsset: chainAsset
        )
    }

    func testViewModelFactoryBuildsBalanceVestingStakeAndHint() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFinClaimFixture.ormlChainAsset(precision: 2)
        let factory = makeFactory(chainAsset, wallet: wallet)
        let en = CovJFixture.locale

        let balance = factory.buildBalanceViewModel(accountInfo: CovJFinClaimFixture.accountInfo(free: 900, frozen: 100), priceData: nil)
        XCTAssertEqual(balance.value(for: locale).amount, amount(8, chainAsset, wallet: wallet))
        XCTAssertEqual(factory.buildBalanceViewModel(accountInfo: nil, priceData: nil).value(for: locale).amount, amount(0, chainAsset, wallet: wallet))

        let locks = try CovJFinClaimFixture.balanceLocks([("staking ", 300), ("vesting ", 700)])
        XCTAssertEqual(factory.buildVestingViewModel(balanceLocks: locks, priceData: nil).value(for: locale).amount, amount(7, chainAsset, wallet: wallet))
        let noVesting = try CovJFinClaimFixture.balanceLocks([("staking ", 300)])
        XCTAssertEqual(factory.buildVestingViewModel(balanceLocks: noVesting, priceData: nil).value(for: locale).amount, amount(0, chainAsset, wallet: wallet))
        XCTAssertEqual(factory.buildVestingViewModel(balanceLocks: nil, priceData: nil).value(for: locale).amount, amount(0, chainAsset, wallet: wallet))

        let stake = factory.createStakedAmountViewModel().value(for: en)
        XCTAssertEqual(stake.amountTitle.string, "KAR")
        XCTAssertNil(stake.iconViewModel)
        XCTAssertEqual(stake.color, "#FF0000")

        let hint = try XCTUnwrap(factory.buildHintViewModel().value(for: en))
        let title = R.string.localizable.vestingClaimDisclaimerTitle(preferredLanguages: en.rLanguages)
        let text = R.string.localizable.vestingClaimDisclaimerText(preferredLanguages: en.rLanguages)
        XCTAssertEqual(hint.title?.string, title + "\n" + text)
        XCTAssertEqual(hint.icon.size, try XCTUnwrap(R.image.iconWarning()).size)
    }

    func testHintMentionsRelayBlockTimeOnAssetHub() throws {
        let chainAsset = assetHubChainAsset()
        let factory = makeFactory(chainAsset, wallet: AccountGenerator.generateMetaAccount())
        let hint = try XCTUnwrap(factory.buildHintViewModel().value(for: CovJFixture.locale))
        XCTAssertTrue((hint.title?.string ?? "").hasSuffix("\n\n(Info: Vesting on Asset Hub uses Relay Chain block time)"))
        XCTAssertEqual(factory.createStakedAmountViewModel().value(for: CovJFixture.locale).amountTitle.string, "DOT")
    }

    func testPresenterDrivesViewFromInteractorOutputs() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFinClaimFixture.ormlChainAsset(precision: 2)
        let interactor = CovJFinClaimInteractor()
        let router = CovJFinClaimRouter()
        let authorizer = CovJFinAuthorizer()
        let presenter = ClaimCrowdloanRewardsPresenter(
            interactor: interactor, router: router, localizationManager: LocalizationManager.shared, logger: Logger.shared,
            chainAsset: chainAsset,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet),
            viewModelFactory: makeFactory(chainAsset, wallet: wallet), wallet: wallet, submissionAuthorizer: authorizer
        )
        let view = CovJFinClaimView()

        presenter.didLoad(view: view)
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.estimates, 1)
        XCTAssertEqual(view.stakes.first?.value(for: locale).amountTitle.string, "KAR")
        XCTAssertEqual(view.hints.count, 1)
        XCTAssertNotNil(view.hints.first ?? nil)

        presenter.didReceiveBalanceLocks(try CovJFinClaimFixture.balanceLocks([("vesting ", 700)]))
        presenter.didReceiveTokenLocks(nil)
        XCTAssertEqual(view.vestings.compactMap { $0?.amount }, [amount(7, chainAsset, wallet: wallet), amount(7, chainAsset, wallet: wallet)])
        presenter.didReceiveBalanceLocks(nil)
        presenter.didReceiveTokenLocks(try CovJFinClaimFixture.tokenLocks([("ormlvest", 50)]))
        XCTAssertEqual(view.vestings.last??.amount, amount(Decimal(string: "0.5") ?? 0, chainAsset, wallet: wallet))

        presenter.didReceiveAccountInfo(accountInfo: CovJFinClaimFixture.accountInfo(free: 900, frozen: 100))
        XCTAssertEqual(view.balances.last??.amount, amount(8, chainAsset, wallet: wallet))

        presenter.didReceiveFee(RuntimeDispatchInfo(feeValue: 12_345))
        XCTAssertEqual(view.fees.last??.amount, amount(Decimal(string: "123.45") ?? 0, chainAsset, wallet: wallet))

        let counts = (view.fees.count, view.vestings.count, view.balances.count)
        presenter.didReceiveTokenLocksError(CovJError("tokens"))
        presenter.didReceiveBalanceLocksError(CovJError("balances"))
        presenter.didReceiveFeeError(CovJError("fee"))
        XCTAssertEqual(view.fees.count, counts.0)
        XCTAssertEqual(view.vestings.count, counts.1)
        XCTAssertEqual(view.balances.count, counts.2)

        presenter.applyLocalization()
        XCTAssertEqual(view.vestings.count, counts.1 + 1)

        presenter.didReceiveTxHash("0xfeed")
        XCTAssertEqual(router.completions.map(\.title), ["0xfeed"])
        XCTAssertEqual(router.completions.first?.chainAssetId, chainAsset.chainAssetId)
        presenter.didReceiveTxError(CovJError("tx"))
        XCTAssertEqual(router.errors.first as? CovJError, CovJError("tx"))

        presenter.backButtonClicked()
        XCTAssertEqual(router.dismissals, 1)
        presenter.confirmButtonClicked()
        authorizer.allow = false
        presenter.confirmButtonClicked()
        XCTAssertEqual(authorizer.requests, 2)
        XCTAssertEqual(interactor.submits, 1)
    }

    func testControllerBindsEveryViewModelAndForwardsActions() throws {
        let output = CovJFinClaimViewOutput()
        let controller = ClaimCrowdloanRewardsViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? ClaimCrowdloanRewardsViewLayout)
        XCTAssertEqual(output.loads, 1)

        controller.didReceiveVestingViewModel(BalanceViewModel(amount: "7 KAR", price: "$1"))
        controller.didReceiveBalanceViewModel(BalanceViewModel(amount: "8 KAR", price: "$2"))
        controller.didReceiveFeeViewModel(BalanceViewModel(amount: "0.1 KAR", price: nil))
        controller.didReceiveStakeAmountViewModel(LocalizableResource { _ in
            StakeAmountViewModel(amountTitle: NSAttributedString(string: "KAR"), iconViewModel: nil, color: "#00FF00")
        })
        controller.didReceiveHintViewModel(DetailsTriangularedAttributedViewModel(
            icon: try XCTUnwrap(R.image.iconWarning()), title: NSAttributedString(string: "Claim hint")
        ))
        XCTAssertEqual(root.lockedRewardsView.valueTop.text, "7 KAR")
        XCTAssertEqual(root.lockedRewardsView.valueBottom.text, "$1")
        XCTAssertEqual(root.transerableBalanceView.valueTop.text, "8 KAR")
        XCTAssertEqual(root.feeView.valueTop.text, "0.1 KAR")
        XCTAssertTrue(root.feeView.valueBottom.isHidden)
        XCTAssertEqual(root.stakeAmountView.amountLabel.attributedText?.string, "KAR")
        XCTAssertEqual(root.hintView.detailsLabel.attributedText?.string, "Claim hint")

        controller.applyLocalization()
        XCTAssertEqual(root.locale, controller.selectedLocale)

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.confirms, 1)
    }

    func testRouterDismissesClaimAndPresentsAllDoneFromPresenter() throws {
        let presenting = CovJFinBackedController()
        let window = try CovJViewFixture.host(presenting)
        defer { window.isHidden = true }
        let claim = CovJFinBackedController()
        presenting.present(claim, animated: false)
        XCTAssertTrue(CovJWait.until { presenting.presentedViewController === claim && !claim.isBeingPresented })

        ClaimCrowdloanRewardsRouter().complete(on: claim, title: "0xbeef", chainAsset: CovJFinClaimFixture.ormlChainAsset())

        XCTAssertTrue(CovJWait.until(timeout: 4) { presenting.presentedViewController is AllDoneViewController })
        let allDone = try XCTUnwrap(presenting.presentedViewController)
        XCTAssertEqual(allDone.modalPresentationStyle, .custom)
        XCTAssertTrue(CovJWait.until(timeout: 3) { !allDone.isBeingPresented })
        allDone.dismiss(animated: false)
        XCTAssertTrue(CovJWait.until { presenting.presentedViewController == nil })
    }
}
