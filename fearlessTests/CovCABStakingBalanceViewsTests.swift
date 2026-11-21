import XCTest
import SoraUI
@testable import fearless

final class CovCABSBVActionsDelegate: StakingBalanceActionsWidgetViewDelegate {
    private(set) var actions: [StakingBalanceAction] = []

    func didSelect(action: StakingBalanceAction) {
        actions.append(action)
    }
}

enum CovCABSBVHelpers {
    static func labels(in view: UIView) -> [UILabel] {
        var result: [UILabel] = []
        for subview in view.subviews {
            if let label = subview as? UILabel {
                result.append(label)
            }
            result.append(contentsOf: labels(in: subview))
        }
        return result
    }

    static func labelTexts(in view: UIView) -> [String] {
        labels(in: view).compactMap(\.text)
    }

    static func roundedButtons(in view: UIView) -> [RoundedButton] {
        var result: [RoundedButton] = []
        for subview in view.subviews {
            if let button = subview as? RoundedButton {
                result.append(button)
            } else {
                result.append(contentsOf: roundedButtons(in: subview))
            }
        }
        return result
    }

    static func unbondingItem(interval: TimeInterval?, name: String = "Unbond") -> UnbondingItemViewModel {
        UnbondingItemViewModel(
            addressOrName: name,
            daysLeftText: NSAttributedString(),
            tokenAmountText: "1.5 DOT",
            usdAmountText: "$3",
            timeInterval: interval,
            locale: Locale(identifier: "en")
        )
    }
}

final class CovCABStakingBalanceViewsTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testWidgetViewBindsTitleAndItems() {
        let view = StakingBalanceWidgetView()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 300)

        let viewModel = StakingBalanceWidgetViewModel(
            title: "Balance",
            itemViewModels: [
                StakingBalanceWidgetItemViewModel(title: "Bonded", tokenAmountText: "10 DOT", usdAmountText: "$20"),
                StakingBalanceWidgetItemViewModel(title: "Unbonding", tokenAmountText: "2 DOT", usdAmountText: nil),
                StakingBalanceWidgetItemViewModel(title: "Redeemable", tokenAmountText: "1 DOT", usdAmountText: "$2")
            ]
        )

        view.bind(viewModel: viewModel)
        view.layoutIfNeeded()

        XCTAssertEqual(view.balanceTitleLabel.text, "Balance")
        let texts = CovCABSBVHelpers.labelTexts(in: view)
        for expected in ["Bonded", "10 DOT", "$20", "Unbonding", "2 DOT", "Redeemable", "1 DOT", "$2"] {
            XCTAssertTrue(texts.contains(expected), "missing \(expected)")
        }

        let rebound = StakingBalanceWidgetViewModel(
            title: "Other",
            itemViewModels: [StakingBalanceWidgetItemViewModel(title: "Only", tokenAmountText: "5 KSM", usdAmountText: nil)]
        )
        view.bind(viewModel: rebound)

        let reboundTexts = CovCABSBVHelpers.labelTexts(in: view)
        XCTAssertEqual(view.balanceTitleLabel.text, "Other")
        XCTAssertTrue(reboundTexts.contains("5 KSM"))
        XCTAssertFalse(reboundTexts.contains("10 DOT"))
    }

    func testActionsWidgetBindsTitlesAndAvailability() {
        let view = StakingBalanceActionsWidgetView()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 80)
        view.layoutIfNeeded()

        let buttons = CovCABSBVHelpers.roundedButtons(in: view)
        XCTAssertEqual(buttons.count, 3)

        let viewModel = StakingBalanceActionsWidgetViewModel(
            bondTitle: "Bond",
            unbondTitle: "Unbond",
            redeemTitle: "Redeem",
            redeemIcon: R.image.iconRedeem(),
            redeemActionIsAvailable: false,
            stakeMoreActionAvailable: true,
            stakeLessActionAvailable: false
        )
        view.bind(viewModel: viewModel)

        XCTAssertEqual(buttons.map { $0.imageWithTitleView?.title }, ["Bond", "Unbond", "Redeem"])
        XCTAssertEqual(buttons.map(\.isEnabled), [true, false, false])
        XCTAssertNotNil(buttons[2].imageWithTitleView?.iconImage)

        let enabled = StakingBalanceActionsWidgetViewModel(
            bondTitle: "B",
            unbondTitle: "U",
            redeemTitle: "R",
            redeemIcon: nil,
            redeemActionIsAvailable: true,
            stakeMoreActionAvailable: false,
            stakeLessActionAvailable: true
        )
        view.bind(viewModel: enabled)
        XCTAssertEqual(buttons.map(\.isEnabled), [false, true, true])
    }

    func testActionsWidgetForwardsTapsToDelegate() {
        let view = StakingBalanceActionsWidgetView()
        let delegate = CovCABSBVActionsDelegate()
        view.delegate = delegate

        let buttons = CovCABSBVHelpers.roundedButtons(in: view)
        buttons.forEach { $0.sendActions(for: .touchUpInside) }

        XCTAssertEqual(delegate.actions, [.bondMore, .unbond, .redeem])

        view.handleActionButton(sender: UIControl())
        XCTAssertEqual(delegate.actions.count, 3)
    }

    func testUnbondingWidgetEmptyList() {
        let view = StakingBalanceUnbondingWidgetView()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 200)

        view.bind(viewModel: StakingBalanceUnbondingWidgetViewModel(
            title: "Unbonding",
            emptyListDescription: "Nothing here",
            unbondings: []
        ))
        view.layoutIfNeeded()

        XCTAssertEqual(view.titleLabel.text, "Unbonding")
        XCTAssertEqual(view.emptyListLabel.text, "Nothing here")
        XCTAssertFalse(view.emptyListLabel.isHidden)
        XCTAssertFalse(view.moreButton.isEnabled)
    }

    func testUnbondingWidgetWithItemsReplacesRows() {
        let view = StakingBalanceUnbondingWidgetView()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 300)

        view.bind(viewModel: StakingBalanceUnbondingWidgetViewModel(
            title: "Unbonding",
            emptyListDescription: "Nothing here",
            unbondings: [
                CovCABSBVHelpers.unbondingItem(interval: nil, name: "first"),
                CovCABSBVHelpers.unbondingItem(interval: 0, name: "second")
            ]
        ))
        view.layoutIfNeeded()

        XCTAssertTrue(view.emptyListLabel.isHidden)
        XCTAssertTrue(view.moreButton.isEnabled)
        var texts = CovCABSBVHelpers.labelTexts(in: view)
        XCTAssertTrue(texts.contains("first"))
        XCTAssertTrue(texts.contains("second"))

        view.bind(viewModel: StakingBalanceUnbondingWidgetViewModel(
            title: "Again",
            emptyListDescription: "Nothing here",
            unbondings: [CovCABSBVHelpers.unbondingItem(interval: nil, name: "third")]
        ))

        texts = CovCABSBVHelpers.labelTexts(in: view)
        XCTAssertEqual(view.titleLabel.text, "Again")
        XCTAssertTrue(texts.contains("third"))
        XCTAssertFalse(texts.contains("first"))
    }

    func testUnbondingItemFinishedWhenNoInterval() {
        let item = StakingBalanceUnbondingItemView()
        item.frame = CGRect(x: 0, y: 0, width: 390, height: 60)

        item.bind(model: CovCABSBVHelpers.unbondingItem(interval: nil, name: "Request"))
        item.layoutIfNeeded()

        XCTAssertEqual(item.titleLabel.text, "Request")
        XCTAssertEqual(item.tokenAmountLabel.text, "1.5 DOT")
        XCTAssertEqual(item.usdAmountLabel.text, "$3")
        XCTAssertEqual(
            item.daysLeftLabel.text,
            R.string.localizable.parachainStakingRequestFinished(preferredLanguages: ["en"])
        )
        XCTAssertEqual(item.locale.identifier, "en")
    }

    func testUnbondingItemShowsDaysAndTimeLeft() {
        let item = StakingBalanceUnbondingItemView()

        item.bind(model: CovCABSBVHelpers.unbondingItem(interval: 3 * 86400 + 10))
        XCTAssertEqual(
            item.daysLeftLabel.text,
            R.string.localizable.commonDaysLeftFormat(format: 3, format: 3, preferredLanguages: ["en"])
        )

        item.bind(model: CovCABSBVHelpers.unbondingItem(interval: 3661))
        XCTAssertEqual(item.daysLeftLabel.text, "01:01:01")

        item.didCountdown(remainedInterval: 59)
        XCTAssertEqual(item.daysLeftLabel.text, "00:00:59")

        item.didStop(with: 0)
        XCTAssertEqual(item.daysLeftLabel.text, "")

        item.didStart(with: 2 * 86400)
        XCTAssertEqual(
            item.daysLeftLabel.text,
            R.string.localizable.commonDaysLeftFormat(format: 2, format: 2, preferredLanguages: ["en"])
        )

        item.bind(model: CovCABSBVHelpers.unbondingItem(interval: nil))
        XCTAssertEqual(
            item.daysLeftLabel.text,
            R.string.localizable.parachainStakingRequestFinished(preferredLanguages: ["en"])
        )
    }

    func testBalanceViewLayoutBuildsWidgets() {
        let layout = StakingBalanceViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.layoutIfNeeded()

        XCTAssertNotNil(layout.navBarBlurViewHeightConstraint)
        XCTAssertTrue(layout.balanceWidget.isDescendant(of: layout.scrollView))
        XCTAssertTrue(layout.actionsWidget.isDescendant(of: layout.scrollView))
        XCTAssertTrue(layout.unbondingWidget.isDescendant(of: layout.scrollView))
        XCTAssertTrue(layout.refreshControl.isDescendant(of: layout.scrollView))
        XCTAssertTrue(layout.scrollView.alwaysBounceVertical)

        layout.navBarBlurViewHeightConstraint.update(offset: 44)
        XCTAssertEqual(layout.navBarBlurViewHeightConstraint.layoutConstraints.first?.constant, 44)
    }

    func testStakingManageCellBindsModel() {
        let cell = StakingManageCell(style: .default, reuseIdentifier: "manage")
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: StakingManageCell.cellHeight)

        let icon = R.image.iconStakingBalance()
        cell.bind(model: StakingManageViewModel(icon: icon, title: "Balance", details: "3"))
        cell.layoutIfNeeded()

        XCTAssertEqual(cell.titleLabel.text, "Balance")
        XCTAssertEqual(cell.detailsLabel.text, "3")
        XCTAssertNotNil(icon)
        XCTAssertNotNil(cell.iconImageView.image)
        XCTAssertNotNil(cell.selectedBackgroundView)
        XCTAssertFalse(cell.checkmarked)
        XCTAssertEqual(StakingManageCell.cellHeight, 48)

        cell.bind(model: StakingManageViewModel(icon: nil, title: "Other", details: nil))
        XCTAssertNil(cell.detailsLabel.text)
        XCTAssertNil(cell.iconImageView.image)
    }

    func testStakingManageOptionTitlesDetailsAndIcons() {
        let languages = ["en"]
        let options: [(StakingManageOption, String)] = [
            (.stakingBalance, R.string.localizable.stakingBalanceTitle(preferredLanguages: languages)),
            (.pendingRewards, R.string.localizable.stakingPendingRewards(preferredLanguages: languages)),
            (.rewardDestination, R.string.localizable.stakingRewardsDestinationTitle(preferredLanguages: languages)),
            (.setupValidators, R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: languages)),
            (.changeValidators(count: 4), R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: languages)),
            (.controllerAccount, R.string.localizable.stakingControllerAccountTitle(preferredLanguages: languages)),
            (.yourValidator, R.string.localizable.stakingYourValidatorTitle(preferredLanguages: languages))
        ]

        for (option, title) in options {
            XCTAssertEqual(option.titleForLocale(locale), title)
            XCTAssertNotNil(option.icon)
        }

        XCTAssertEqual(StakingManageOption.changeValidators(count: 16).detailsForLocale(locale), "16")
        XCTAssertNil(StakingManageOption.changeValidators(count: nil).detailsForLocale(locale))
        XCTAssertNil(StakingManageOption.stakingBalance.detailsForLocale(locale))
        XCTAssertNil(StakingManageOption.yourValidator.detailsForLocale(locale))
    }

    func testStakingBalanceActionTitlesAndIcons() {
        let languages = ["en"]
        XCTAssertEqual(
            StakingBalanceAction.bondMore.title(for: locale),
            R.string.localizable.stakingBondMore_v190(preferredLanguages: languages)
        )
        XCTAssertEqual(
            StakingBalanceAction.unbond.title(for: locale),
            R.string.localizable.stakingUnbond_v190(preferredLanguages: languages)
        )
        XCTAssertEqual(
            StakingBalanceAction.redeem.title(for: locale),
            R.string.localizable.stakingRedeem(preferredLanguages: languages)
        )
        XCTAssertNotNil(StakingBalanceAction.bondMore.iconImage)
        XCTAssertNotNil(StakingBalanceAction.unbond.iconImage)
        XCTAssertNotNil(StakingBalanceAction.redeem.iconImage)
    }

    func testStakingRebondOptionTitles() {
        let languages = ["en"]
        XCTAssertEqual(StakingRebondOption.allCases, [.all, .last, .customAmount])
        XCTAssertEqual(StakingRebondOption.all.titleForLocale(locale), R.string.localizable.stakingRebondAll(preferredLanguages: languages))
        XCTAssertEqual(StakingRebondOption.last.titleForLocale(locale), R.string.localizable.stakingRebondLast(preferredLanguages: languages))
        XCTAssertEqual(
            StakingRebondOption.customAmount.titleForLocale(locale),
            R.string.localizable.stakingRebondCustomAmount(preferredLanguages: languages)
        )
        XCTAssertEqual(StakingRebondOption.all.titleForLocale(nil), R.string.localizable.stakingRebondAll(preferredLanguages: nil))
    }
}
