import XCTest
import SoraFoundation
import SSFModels
@testable import fearless

final class CovBVmCalculatorDelegate: RewardCalculatorViewDelegate {
    private(set) var amounts: [Decimal?] = []
    private(set) var percentages: [Float] = []
    private(set) var infoRequests = 0

    func rewardCalculatorView(_: StakingRewardCalculatorView, didChange amount: Decimal?) {
        amounts.append(amount)
    }

    func rewardCalculatorView(_: StakingRewardCalculatorView, didSelect percentage: Float) {
        percentages.append(percentage)
    }

    func rewardCalculatorDidRequestInfo(_: StakingRewardCalculatorView) {
        infoRequests += 1
    }
}

final class CovBVmStakingRewardCalculatorViewTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var window: UIWindow!
    private var view: StakingRewardCalculatorView!
    private var delegate: CovBVmCalculatorDelegate!

    override func setUp() {
        super.setUp()
        let controller = UIViewController()
        window = CovBAnFixtures.host(controller)
        view = StakingRewardCalculatorView(frame: CGRect(x: 0, y: 100, width: 390, height: 260))
        controller.view.addSubview(view)
        view.locale = locale
        delegate = CovBVmCalculatorDelegate()
        view.delegate = delegate
        view.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        delegate = nil
        super.tearDown()
    }

    private func child<T>(_ name: String, of object: Any) throws -> T {
        let value = Mirror(reflecting: object).children.first { $0.label == name }?.value
        return try XCTUnwrap(value as? T, "missing \(name)")
    }

    private func label(_ name: String) throws -> UILabel {
        try child(name, of: try XCTUnwrap(view))
    }

    private var assetInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 4,
            assetPrecision: 12,
            symbol: "KSM",
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: nil
        )
    }

    private func viewModel(amount: Decimal?, withReward: Bool) -> StakingEstimationViewModel {
        let balance = LocalizableResource<AssetBalanceViewModelProtocol> { _ in
            AssetBalanceViewModel(
                symbol: "KSM",
                balance: "12.5",
                fiatBalance: "$25",
                price: "$2",
                iconViewModel: nil,
                selectable: false
            )
        }
        let reward: LocalizableResource<PeriodRewardViewModel>? = withReward ? LocalizableResource { _ in
            PeriodRewardViewModel(
                monthlyReward: RewardViewModel(amount: "1.1 KSM", price: "$2.2", increase: "1.5%"),
                yearlyReward: RewardViewModel(amount: "13 KSM", price: nil, increase: "18%")
            )
        } : nil
        return StakingEstimationViewModel(
            assetBalance: balance,
            rewardViewModel: reward,
            assetInfo: assetInfo,
            inputLimit: 1000,
            amount: amount
        )
    }

    func testInitialLayoutShowsLocalizedTitleAndPlaceholders() throws {
        XCTAssertEqual(
            try label("titleLabel").text,
            R.string.localizable.stakingEstimateEarningTitle_v190(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(try label("monthlyAmountLabel").text, " ")
        XCTAssertEqual(try label("yearlyFiatAmountLabel").text, " ")
        let input: AmountInputViewV2 = try child("amountInputView", of: try XCTUnwrap(view))
        XCTAssertGreaterThan(input.frame.width, 0)
        XCTAssertLessThanOrEqual(input.frame.maxX, view.bounds.width)
    }

    func testBindWithoutRewardShowsSkeletonAndHidesInfo() throws {
        view.bind(viewModel: viewModel(amount: 10, withReward: false))
        let infoButton: UIButton = try child("infoButton", of: try XCTUnwrap(view))
        XCTAssertTrue(infoButton.isHidden)
        XCTAssertEqual(try label("monthlyAmountLabel").alpha, 0)
        XCTAssertEqual(try label("yearlyTitleLabel").alpha, 0)
        let skeleton: UIView = try child("skeletonView", of: try XCTUnwrap(view))
        XCTAssertTrue(skeleton.superview === view)
        XCTAssertEqual(skeleton.frame.size, view.frame.size)
        let input: AmountInputViewV2 = try child("amountInputView", of: try XCTUnwrap(view))
        XCTAssertEqual(input.inputFieldText, "10")

        view.frame.size.height = 300
        view.didUpdateSkeletonLayout()
        let resized: UIView = try child("skeletonView", of: try XCTUnwrap(view))
        XCTAssertFalse(resized === skeleton)
        XCTAssertEqual(resized.frame.size.height, 300)
        view.didAppearSkeleton()
        view.didDisappearSkeleton()
        view.didUpdateSkeletonLayout()
        let unchanged: UIView = try child("skeletonView", of: try XCTUnwrap(view))
        XCTAssertTrue(unchanged === resized)
    }

    func testBindWithRewardFillsPeriodsAndStopsLoading() throws {
        view.bind(viewModel: viewModel(amount: 10, withReward: false))
        view.bind(viewModel: viewModel(amount: 10, withReward: true))
        let languages = locale.rLanguages
        XCTAssertEqual(
            try label("monthlyTitleLabel").text,
            R.string.localizable.stakingMonthPeriodFormat("1.5%", preferredLanguages: languages)
        )
        XCTAssertEqual(try label("monthlyAmountLabel").text, "1.1 KSM")
        XCTAssertEqual(try label("monthlyFiatAmountLabel").text, "$2.2")
        XCTAssertEqual(
            try label("yearlyTitleLabel").text,
            R.string.localizable.stakingYearPeriodFormat("18%", preferredLanguages: languages)
        )
        XCTAssertEqual(try label("yearlyAmountLabel").text, "13 KSM")
        XCTAssertEqual(try label("yearlyFiatAmountLabel").text, " ")
        XCTAssertEqual(try label("monthlyAmountLabel").alpha, 1)
        let infoButton: UIButton = try child("infoButton", of: try XCTUnwrap(view))
        XCTAssertFalse(infoButton.isHidden)
        let skeleton = Mirror(reflecting: try XCTUnwrap(view)).children.first { $0.label == "skeletonView" }?.value
        XCTAssertNil(skeleton.flatMap { $0 as? UIView })

        infoButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.infoRequests, 1)
    }

    func testTypingUpdatesAmountAndNotifiesDelegate() throws {
        view.bind(viewModel: viewModel(amount: nil, withReward: true))
        let input: AmountInputViewV2 = try child("amountInputView", of: try XCTUnwrap(view))
        let text = input.textField.text ?? ""
        let accepted = view.textField(
            input.textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: (text as NSString).length),
            replacementString: "7"
        )
        XCTAssertFalse(accepted)
        XCTAssertEqual(input.inputFieldText, "7")
        XCTAssertEqual(delegate.amounts.last ?? nil, Decimal(7))

        view.bind(viewModel: viewModel(amount: 3, withReward: true))
        XCTAssertEqual(input.inputFieldText, "3")
    }

    func testTextFieldRejectsInputBeforeBinding() throws {
        let input: AmountInputViewV2 = try child("amountInputView", of: try XCTUnwrap(view))
        XCTAssertFalse(view.textField(input.textField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1"))
        XCTAssertTrue(delegate.amounts.isEmpty)
    }

    func testAccessoryViewForwardsPercentageAndDone() throws {
        view.uiFactory = UIFactory.default
        let input: AmountInputViewV2 = try child("amountInputView", of: try XCTUnwrap(view))
        let accessory = try XCTUnwrap(input.textField.inputAccessoryView as? AmountInputAccessoryView)
        accessory.actionSelect50()
        accessory.actionSelect100()
        accessory.actionSelectDone()
        XCTAssertEqual(delegate.percentages, [0.5, 1.0])
        XCTAssertFalse(input.textField.isFirstResponder)
    }

    func testChangingLocaleReappliesTitleAndWidget() throws {
        view.bind(viewModel: viewModel(amount: 2, withReward: true))
        view.locale = Locale(identifier: "ja")
        XCTAssertEqual(
            try label("titleLabel").text,
            R.string.localizable.stakingEstimateEarningTitle_v190(preferredLanguages: Locale(identifier: "ja").rLanguages)
        )
        XCTAssertEqual(try label("yearlyAmountLabel").text, "13 KSM")
    }

    func testStopLoadingWithoutSkeletonKeepsLabelsVisible() throws {
        view.stopLoadingIfNeeded()
        XCTAssertEqual(try label("monthlyTitleLabel").alpha, 1)
        view.startLoadingIfNeeded()
        let first: UIView = try child("skeletonView", of: try XCTUnwrap(view))
        view.startLoadingIfNeeded()
        let second: UIView = try child("skeletonView", of: try XCTUnwrap(view))
        XCTAssertTrue(first === second)
        view.stopLoadingIfNeeded()
        XCTAssertNil(first.superview)
        XCTAssertEqual(try label("yearlyFiatAmountLabel").alpha, 1)
    }

    func testSkeletonIsNotCreatedForZeroSizedView() throws {
        let empty = StakingRewardCalculatorView(frame: .zero)
        empty.startLoadingIfNeeded()
        let skeleton = Mirror(reflecting: empty as Any).children.first { $0.label == "skeletonView" }?.value
        XCTAssertNil(skeleton.flatMap { $0 as? UIView })
        let monthly: UILabel = try child("monthlyAmountLabel", of: empty as Any)
        XCTAssertEqual(monthly.alpha, 0)
    }
}

final class CovBVmStakingPayoutCellsTests: XCTestCase {
    private func layout(_ cell: UITableViewCell) {
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 56)
        cell.layoutIfNeeded()
    }

    func testBaseCellConfiguresAppearanceAndTitle() {
        let cell = StakingPayoutBaseTableCell(style: .default, reuseIdentifier: "base")
        XCTAssertEqual(cell.backgroundColor, .clear)
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertGreaterThanOrEqual(cell.separatorInset.left, UIConstants.horizontalInset)
        XCTAssertTrue(cell.titleLabel.superview === cell.contentView)
        layout(cell)
        XCTAssertEqual(cell.titleLabel.frame.minX, 16)
    }

    func testLabelCellBindsTitleAndValue() {
        let cell = StakingPayoutLabelTableCell(style: .default, reuseIdentifier: "label")
        cell.bind(model: StakingRewardDetailsSimpleLabelViewModel(titleText: "Era", valueText: "#1,690"))
        layout(cell)
        XCTAssertEqual(cell.titleLabel.text, "Era")
        XCTAssertEqual(cell.valueLabel.text, "#1,690")
        XCTAssertEqual(cell.valueLabel.frame.maxX, 390 - UIConstants.horizontalInset, accuracy: 0.5)
        XCTAssertGreaterThan(cell.valueLabel.frame.minX, cell.titleLabel.frame.maxX)
    }

    func testRewardCellSpacesTokenFromPriceOnlyWhenPriceExists() {
        let cell = StakingPayoutRewardTableCell(style: .default, reuseIdentifier: "reward")
        cell.bind(model: StakingRewardTokenUsdViewModel(title: "Reward", tokenAmountText: "1 KSM", usdAmountText: "$5"))
        layout(cell)
        XCTAssertEqual(cell.titleLabel.text, "Reward")
        XCTAssertEqual(cell.tokenAmountLabel.text, "1 KSM")
        XCTAssertEqual(cell.usdAmountLabel.text, "$5")
        XCTAssertEqual(cell.tokenAmountLabel.frame.maxX, cell.usdAmountLabel.frame.minX - 8, accuracy: 0.5)

        cell.bind(model: StakingRewardTokenUsdViewModel(title: "Reward", tokenAmountText: "2 KSM", usdAmountText: nil))
        layout(cell)
        XCTAssertNil(cell.usdAmountLabel.text)
        XCTAssertEqual(cell.tokenAmountLabel.frame.maxX, cell.usdAmountLabel.frame.minX, accuracy: 0.5)

        cell.bind(model: StakingRewardTokenUsdViewModel(title: "Reward", tokenAmountText: "3 KSM", usdAmountText: ""))
        layout(cell)
        XCTAssertEqual(cell.tokenAmountLabel.frame.maxX, cell.usdAmountLabel.frame.minX, accuracy: 0.5)
    }

    func testStatusCellBindsTextAndIcon() {
        let cell = StakingPayoutStatusTableCell(style: .default, reuseIdentifier: "status")
        let icon = R.image.iconValid()
        cell.bind(model: StakingRewardStatusViewModel(title: "Status", statusText: "Claimable", icon: icon))
        layout(cell)
        XCTAssertEqual(cell.titleLabel.text, "Status")
        XCTAssertEqual(cell.statusLabel.text, "Claimable")
        XCTAssertTrue(cell.statusImageView.image === icon)
        XCTAssertEqual(cell.statusImageView.frame.size, CGSize(width: 22, height: 22))
        XCTAssertEqual(cell.statusLabel.frame.maxX, cell.statusImageView.frame.minX - 9, accuracy: 0.5)
    }
}
