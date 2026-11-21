import XCTest
import SoraFoundation
@testable import fearless

final class CovCBPPayoutConfirmPresenterDouble: StakingPayoutConfirmationPresenterProtocol {
    var setupCount = 0
    var proceedCount = 0
    var backCount = 0
    var accountOptions: [AccountInfoViewModel] = []

    func setup() { setupCount += 1 }
    func proceed() { proceedCount += 1 }
    func presentAccountOptions(for viewModel: AccountInfoViewModel) { accountOptions.append(viewModel) }
    func didTapBackButton() { backCount += 1 }
}

final class CovCBPPayoutConfirmViewTests: XCTestCase {
    private let languages = ["en"]

    private func sameColor(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return abs(lr - rr) < 0.01 && abs(lg - rg) < 0.01 && abs(lb - rb) < 0.01 && abs(la - ra) < 0.01
    }

    private func makeLayout() -> StakingPayoutConfirmationViewLayout {
        let layout = StakingPayoutConfirmationViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = Locale(identifier: "en")
        layout.layoutIfNeeded()
        return layout
    }

    private func makeSingleViewModel(name: String?) -> StakingPayoutConfirmationViewModel {
        let stake = LocalizableResource { _ in
            StakeAmountViewModel(
                amountTitle: NSAttributedString(string: "Claim 12 DOT"),
                iconViewModel: nil,
                color: "#FF0000"
            )
        }
        return StakingPayoutConfirmationViewModel(
            senderAddress: "5Sender",
            senderIcon: nil,
            senderName: name,
            amount: stake,
            amountString: LocalizableResource { _ in "12 DOT" }
        )
    }

    private func makeRows() -> [LocalizableResource<PayoutConfirmViewModel>] {
        let first = AccountInfoViewModel(title: "Account", address: "5First", name: "First", icon: nil)
        let second = AccountInfoViewModel(title: "Destination", address: "5Second", name: "Second", icon: nil)
        return [
            LocalizableResource { _ in .accountInfo(first) },
            LocalizableResource { _ in .accountInfo(second) },
            LocalizableResource { _ in .restakeDestination(.init(titleText: "Rewards", valueText: "Restake")) },
            LocalizableResource { _ in .rewardAmountViewModel(.init(title: "Reward", tokenAmountText: "1 DOT", usdAmountText: "$2")) }
        ]
    }

    private func makeController() throws -> (StakingPayoutConfirmationViewController, CovCBPPayoutConfirmPresenterDouble) {
        let presenter = CovCBPPayoutConfirmPresenterDouble()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingPayoutConfirmationViewController(presenter: presenter, localizationManager: manager)
        return (controller, presenter)
    }

    func testLayoutLocalizationSetsTitles() {
        let layout = makeLayout()

        XCTAssertEqual(layout.accountView.titleLabel.text, R.string.localizable.commonAccount(preferredLanguages: languages))
        XCTAssertEqual(layout.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(layout.amountView.titleLabel.text, R.string.localizable.walletSendAmountTitle(preferredLanguages: languages))
        XCTAssertEqual(
            layout.hintView.detailsLabel.text,
            R.string.localizable.stakingHintRewardBondMore(preferredLanguages: languages)
        )
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.commonConfirmTitle(preferredLanguages: languages))
    }

    func testLayoutBindsFeeAndAsset() {
        let layout = makeLayout()

        layout.bind(feeViewModel: BalanceViewModel(amount: "0.1 DOT", price: "$0.5"))
        XCTAssertEqual(layout.feeView.valueTop.text, "0.1 DOT")
        XCTAssertEqual(layout.feeView.valueBottom.text, "$0.5")
        XCTAssertNotNil(layout.networkFeeFooterView.networkFeeView)

        let asset = AssetBalanceViewModel(
            symbol: "DOT",
            balance: "10 DOT",
            fiatBalance: nil,
            price: "$50",
            iconViewModel: nil,
            selectable: false
        )
        layout.bind(assetViewModel: asset)
        XCTAssertEqual(layout.amountView.valueTop.text, "10 DOT")
        XCTAssertEqual(layout.amountView.valueBottom.text, "$50")

        layout.bind(feeViewModel: nil)
        XCTAssertEqual(layout.feeView.valueTop.text, "0.1 DOT")
    }

    func testLayoutSingleViewModelShowsContent() {
        let layout = makeLayout()

        layout.bind(singleViewModel: makeSingleViewModel(name: "Wallet"))
        layout.layoutIfNeeded()

        XCTAssertTrue(layout.tableView.isHidden)
        XCTAssertFalse(layout.contentView.isHidden)
        XCTAssertEqual(layout.accountView.valueTop.text, "Wallet")
        XCTAssertEqual(layout.accountView.valueBottom.text, "5Sender")
        XCTAssertEqual(layout.amountView.valueTop.text, "12 DOT")
        XCTAssertEqual(layout.stakeAmountView.amountLabel.attributedText?.string, "Claim 12 DOT")
        XCTAssertTrue(sameColor(layout.backgroundColor, R.color.colorBlack19()))
        XCTAssertEqual(layout.networkFeeFooterView.networkFeeView?.isHidden ?? true, true)
    }

    func testLayoutWithoutSingleViewModelShowsTable() {
        let layout = makeLayout()

        layout.bind(singleViewModel: makeSingleViewModel(name: nil))
        XCTAssertEqual(layout.accountView.valueTop.text, nil)

        layout.bind(singleViewModel: nil)
        XCTAssertFalse(layout.tableView.isHidden)
        XCTAssertTrue(layout.contentView.isHidden)
        XCTAssertNil(layout.accountView.valueBottom.text)

        layout.bind(viewModel: makeRows())
        XCTAssertTrue(sameColor(layout.backgroundColor, R.color.colorBlack()))
        XCTAssertTrue(sameColor(layout.tableView.backgroundColor, R.color.colorBlack()))
    }

    func testControllerLoadCallsSetupAndActions() throws {
        let (controller, presenter) = try makeController()
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: languages))

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(presenter.proceedCount, 1)
        XCTAssertEqual(presenter.backCount, 1)
        XCTAssertFalse(controller.rootView.tableView.allowsSelection)
    }

    func testControllerTableRowsAndHeights() throws {
        let (controller, _) = try makeController()
        controller.loadViewIfNeeded()
        let table = controller.rootView.tableView

        controller.didRecieve(viewModel: makeRows())

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 4)

        let firstCell = try XCTUnwrap(
            controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? AccountInfoTableViewCell
        )
        XCTAssertEqual(firstCell.detailsView.title, "Account")
        XCTAssertEqual(firstCell.detailsView.subtitle, "First")

        let labelCell = try XCTUnwrap(
            controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0)) as? StakingPayoutLabelTableCell
        )
        XCTAssertEqual(labelCell.valueLabel.text, "Restake")

        let rewardCell = try XCTUnwrap(
            controller.tableView(table, cellForRowAt: IndexPath(row: 3, section: 0)) as? StakingPayoutRewardTableCell
        )
        XCTAssertEqual(rewardCell.tokenAmountLabel.text, "1 DOT")
        XCTAssertEqual(rewardCell.usdAmountLabel.text, "$2")

        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 66.0)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 1, section: 0)), 82.0)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 2, section: 0)), 48.0)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 3, section: 0)), 48.0)
    }

    func testAccountCellActionForwardsViewModel() throws {
        let (controller, presenter) = try makeController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()

        controller.view.layoutIfNeeded()
        controller.didRecieve(viewModel: makeRows())
        controller.rootView.tableView.frame = CGRect(x: 0, y: 100, width: 390, height: 600)
        controller.rootView.tableView.layoutIfNeeded()

        let cell = try XCTUnwrap(
            controller.rootView.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? AccountInfoTableViewCell
        )
        cell.actionDetails()

        XCTAssertEqual(presenter.accountOptions.map(\.address), ["5Second"])

        let detachedCell = AccountInfoTableViewCell(style: .default, reuseIdentifier: nil)
        controller.accountInfoCellDidReceiveAction(detachedCell)
        XCTAssertEqual(presenter.accountOptions.count, 1)

        window.isHidden = true
    }

    func testControllerReceivesFeeAndSingleViewModel() throws {
        let (controller, _) = try makeController()
        controller.loadViewIfNeeded()

        let fee = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: "0.2 DOT", price: nil) }
        controller.didReceive(feeViewModel: fee)
        XCTAssertEqual(controller.rootView.feeView.valueTop.text, "0.2 DOT")
        XCTAssertNotNil(controller.rootView.networkFeeFooterView.networkFeeView)

        controller.didReceive(singleViewModel: makeSingleViewModel(name: "Main"))
        XCTAssertFalse(controller.rootView.contentView.isHidden)
        XCTAssertEqual(controller.rootView.accountView.valueTop.text, "Main")

        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
    }

    func testSealWithoutLoaderDoesNothing() throws {
        let (controller, _) = try makeController()
        controller.loadViewIfNeeded()

        controller.didReachTransferStage(.ready)
        XCTAssertNil(FWTransferSeal.sealView(in: controller.view))

        controller.didBreakTransfer()
        XCTAssertNil(FWTransferSeal.sealView(in: controller.view))
    }
}
