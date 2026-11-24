import XCTest
import SSFUtils
import SoraFoundation
@testable import fearless

final class CovCUBLayoutsTests: XCTestCase {
    private let en = ["en"]
    private let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"

    private func sized<T: UIView>(_ view: T) -> T {
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.layoutIfNeeded()
        return view
    }

    private func stakeAmount(_ text: String, color: String?) -> LocalizableResource<StakeAmountViewModel> {
        LocalizableResource { _ in
            StakeAmountViewModel(amountTitle: NSAttributedString(string: text), iconViewModel: nil, color: color)
        }
    }

    private func hints(_ titles: [String]) -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { _ in titles.map { TitleIconViewModel(title: $0, icon: R.image.iconNoReward()) } }
    }

    private func asset(balance: String?) -> AssetBalanceViewModel {
        AssetBalanceViewModel(
            symbol: "dot",
            balance: balance,
            fiatBalance: "$5",
            price: "$1.50",
            iconViewModel: nil,
            selectable: false
        )
    }

    private func hintTexts(_ views: [UIView]) -> [String?] {
        views.map { ($0 as? IconDetailsView)?.detailsLabel.text }
    }

    // MARK: - Unbond confirm

    func testUnbondConfirmLayoutLocalizesTitlesAndCornerRadius() {
        let view = sized(StakingUnbondConfirmLayout())
        view.locale = Locale(identifier: "en")

        XCTAssertEqual(view.accountView.titleLabel.text, R.string.localizable.commonAccount(preferredLanguages: en))
        XCTAssertEqual(view.amountView.titleLabel.text, R.string.localizable.walletSendAmountTitle(preferredLanguages: en))
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: en))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonConfirmTitle(preferredLanguages: en))
        XCTAssertEqual(view.networkFeeFooterView.locale, Locale(identifier: "en"))
        XCTAssertEqual(
            view.navigationBar.backButton.layer.cornerRadius,
            view.navigationBar.backButton.frame.size.height / 2
        )

        view.locale = Locale(identifier: "ru")
        XCTAssertEqual(view.accountView.titleLabel.text, R.string.localizable.commonAccount(preferredLanguages: ["ru"]))
    }

    func testUnbondConfirmLayoutBindsConfirmationAndReplacesHints() {
        let view = sized(StakingUnbondConfirmLayout())
        view.locale = Locale(identifier: "en")

        let viewModel = StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: nil,
            senderName: "Alice",
            stakeAmountViewModel: stakeAmount("Unstake 10 DOT", color: "#FF0000"),
            amountString: LocalizableResource { _ in "10 DOT" },
            hints: hints(["first", "second", "third"])
        )
        view.bind(confirmationViewModel: viewModel)

        XCTAssertEqual(view.accountView.valueTop.text, "Alice")
        XCTAssertEqual(view.accountView.valueTop.lineBreakMode, .byTruncatingTail)
        XCTAssertEqual(view.accountView.valueBottom.text, address)
        XCTAssertEqual(view.amountView.valueTop.text, "10 DOT")
        XCTAssertEqual(view.stakeAmountView.amountLabel.attributedText?.string, "Unstake 10 DOT")
        XCTAssertEqual(hintTexts(view.hintViews), ["first", "second", "third"])
        XCTAssertTrue(view.hintViews.allSatisfy { $0.superview === view.contentView.stackView })

        let replacement = StakingUnbondConfirmViewModel(
            senderAddress: "other",
            senderIcon: nil,
            senderName: nil,
            stakeAmountViewModel: nil,
            amountString: LocalizableResource { _ in "1 DOT" },
            hints: hints(["only"])
        )
        view.bind(confirmationViewModel: replacement)

        XCTAssertEqual(view.accountView.valueTop.text, "Alice")
        XCTAssertEqual(view.accountView.valueBottom.text, "other")
        XCTAssertEqual(view.amountView.valueTop.text, "1 DOT")
        XCTAssertEqual(view.stakeAmountView.amountLabel.attributedText?.string, "Unstake 10 DOT")
        XCTAssertEqual(hintTexts(view.hintViews), ["only"])
    }

    func testUnbondConfirmLayoutBindsFeeAndAsset() {
        let view = sized(StakingUnbondConfirmLayout())

        view.bind(feeViewModel: BalanceViewModel(amount: "0.01 DOT", price: "$0.02"))
        XCTAssertEqual(view.feeView.valueTop.text, "0.01 DOT")
        XCTAssertEqual(view.feeView.valueBottom.text, "$0.02")
        XCTAssertFalse(view.feeView.valueBottom.isHidden)

        view.bind(feeViewModel: BalanceViewModel(amount: "0.02 DOT", price: nil))
        XCTAssertEqual(view.feeView.valueTop.text, "0.02 DOT")
        XCTAssertTrue(view.feeView.valueBottom.isHidden)

        view.bind(feeViewModel: nil)
        XCTAssertEqual(view.feeView.valueTop.text, "0.02 DOT")

        view.bind(assetViewModel: asset(balance: "3"))
        XCTAssertEqual(view.amountView.valueBottom.text, "$1.50")
    }

    // MARK: - Redeem confirmation

    func testRedeemConfirmationLayoutLocalizesAndBindsEverything() {
        let view = sized(StakingRedeemConfirmationLayout())
        view.locale = Locale(identifier: "en")

        XCTAssertEqual(view.accountView.titleLabel.text, R.string.localizable.commonAccount(preferredLanguages: en))
        XCTAssertEqual(view.amountView.titleLabel.text, R.string.localizable.walletSendAmountTitle(preferredLanguages: en))
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: en))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonConfirmTitle(preferredLanguages: en))
        XCTAssertEqual(
            view.navigationBar.backButton.layer.cornerRadius,
            view.navigationBar.backButton.frame.size.height / 2
        )

        let viewModel = StakingRedeemConfirmationViewModel(
            senderAddress: address,
            senderIcon: nil,
            senderName: "Bob",
            stakeAmountViewModel: stakeAmount("Redeem 2 DOT", color: nil),
            amountString: LocalizableResource { _ in "2 DOT" },
            title: LocalizableResource { _ in "Redeem" }
        )
        view.bind(confirmationViewModel: viewModel)
        XCTAssertEqual(view.accountView.valueTop.text, "Bob")
        XCTAssertEqual(view.accountView.valueBottom.text, address)
        XCTAssertEqual(view.amountView.valueTop.text, "2 DOT")
        XCTAssertEqual(view.stakeAmountView.amountLabel.attributedText?.string, "Redeem 2 DOT")

        let noName = StakingRedeemConfirmationViewModel(
            senderAddress: "second",
            senderIcon: nil,
            senderName: nil,
            stakeAmountViewModel: nil,
            amountString: LocalizableResource { _ in "3 DOT" },
            title: LocalizableResource { _ in "Redeem" }
        )
        view.bind(confirmationViewModel: noName)
        XCTAssertEqual(view.accountView.valueTop.text, "Bob")
        XCTAssertEqual(view.accountView.valueBottom.text, "second")
        XCTAssertEqual(view.amountView.valueTop.text, "3 DOT")

        view.bind(feeViewModel: BalanceViewModel(amount: "0.5 DOT", price: "$1"))
        XCTAssertEqual(view.feeView.valueTop.text, "0.5 DOT")
        XCTAssertEqual(view.feeView.valueBottom.text, "$1")

        view.bind(assetViewModel: asset(balance: nil))
        XCTAssertEqual(view.amountView.valueBottom.text, "$1.50")

        view.bind(hintViewModels: [
            TitleIconViewModel(title: "h1", icon: nil),
            TitleIconViewModel(title: "h2", icon: R.image.iconRedeem())
        ])
        XCTAssertEqual(hintTexts(view.hintViews), ["h1", "h2"])

        view.bind(hintViewModels: [])
        XCTAssertTrue(view.hintViews.isEmpty)

        view.locale = Locale(identifier: "ru")
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: ["ru"]))
    }

    // MARK: - Unbond setup

    func testUnbondSetupLayoutBindsFeeFooterAndHints() {
        let view = sized(StakingUnbondSetupLayout())
        view.locale = Locale(identifier: "en")

        XCTAssertTrue(view.accountView.isHidden)
        XCTAssertEqual(view.networkFeeFooterView.locale, Locale(identifier: "en"))
        XCTAssertEqual(view.amountInputView.locale, Locale(identifier: "en"))
        XCTAssertEqual(
            view.navigationBar.backButton.layer.cornerRadius,
            view.navigationBar.backButton.frame.size.height / 2
        )

        let footer = NetworkFeeFooterViewModel(
            actionTitle: LocalizableResource { _ in "Go on" },
            feeTitle: LocalizableResource { _ in "Fee" },
            balanceViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.3 DOT", price: "$0.9") }
        )
        view.bind(feeViewModel: footer)

        XCTAssertEqual(view.networkFeeFooterView.actionButton.imageWithTitleView?.title, "Go on")
        XCTAssertEqual(view.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.3 DOT")
        XCTAssertEqual(view.networkFeeFooterView.networkFeeView?.fiatLabel?.text, "$0.9")

        view.bind(feeViewModel: nil)
        XCTAssertNil(view.networkFeeFooterView.actionTitle)
        XCTAssertNil(view.networkFeeFooterView.networkFeeView?.tokenLabel.text)

        view.bind(hintViewModels: [TitleIconViewModel(title: "a", icon: nil), TitleIconViewModel(title: "b", icon: nil)])
        XCTAssertEqual(hintTexts(view.hintViews), ["a", "b"])

        view.bind(hintViewModels: [TitleIconViewModel(title: "c", icon: nil)])
        XCTAssertEqual(hintTexts(view.hintViews), ["c"])

        view.amountInputView.bind(viewModel: asset(balance: "12"))
        XCTAssertEqual(
            view.amountInputView.balanceText,
            R.string.localizable.stakingBondedFormat("12", preferredLanguages: en)
        )
        XCTAssertEqual(view.amountInputView.symbol, "DOT")

        view.locale = Locale(identifier: "ru")
        XCTAssertEqual(view.amountInputView.locale, Locale(identifier: "ru"))
    }

    // MARK: - Rebond confirmation

    func testRebondConfirmationLayoutBindsAccountWithAndWithoutName() throws {
        let view = sized(StakingRebondConfirmationLayout())
        view.locale = Locale(identifier: "en")
        XCTAssertEqual(view.accountView.title, R.string.localizable.commonAccount(preferredLanguages: en))

        let icon = try PolkadotIconGenerator().generateFromAddress(address)
        view.bind(confirmationViewModel: StakingRebondConfirmationViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: "Carol",
            amount: LocalizableResource { _ in "4.5" }
        ))

        XCTAssertEqual(view.accountView.subtitle, "Carol")
        XCTAssertEqual(view.accountView.subtitleLabel?.lineBreakMode, .byTruncatingTail)
        XCTAssertNotNil(view.accountView.iconImage)
        XCTAssertEqual(view.amountView.inputFieldText, "4.5")

        view.bind(confirmationViewModel: StakingRebondConfirmationViewModel(
            senderAddress: address,
            senderIcon: nil,
            senderName: nil,
            amount: LocalizableResource { _ in "1" }
        ))

        XCTAssertEqual(view.accountView.subtitle, address)
        XCTAssertEqual(view.accountView.subtitleLabel?.lineBreakMode, .byTruncatingMiddle)
        XCTAssertNil(view.accountView.iconImage)
        XCTAssertEqual(view.amountView.inputFieldText, "1")
    }

    func testRebondConfirmationLayoutBindsFeeAndAsset() {
        let view = sized(StakingRebondConfirmationLayout())
        view.locale = Locale(identifier: "en")

        view.bind(feeViewModel: BalanceViewModel(amount: "0.7 DOT", price: nil))
        XCTAssertEqual(view.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.7 DOT")
        XCTAssertNil(view.networkFeeFooterView.networkFeeView?.fiatLabel)

        view.bind(assetViewModel: asset(balance: "8"))
        XCTAssertEqual(view.amountView.balanceText, R.string.localizable.commonBalanceFormat("8", preferredLanguages: en))
        XCTAssertEqual(view.amountView.symbol, "DOT")
        XCTAssertFalse(view.amountView.isUserInteractionEnabled)

        view.locale = Locale(identifier: "ru")
        XCTAssertEqual(view.accountView.title, R.string.localizable.commonAccount(preferredLanguages: ["ru"]))
        XCTAssertEqual(view.networkFeeFooterView.locale, Locale(identifier: "ru"))
    }

    // MARK: - Rebond setup

    func testRebondSetupLayoutLocalizesActionButton() {
        let view = sized(StakingRebondSetupLayout())
        view.locale = Locale(identifier: "en")

        XCTAssertEqual(
            view.actionButton.imageWithTitleView?.title,
            R.string.localizable.commonContinue(preferredLanguages: en)
        )
        XCTAssertEqual(view.networkFeeView.locale, Locale(identifier: "en"))
        XCTAssertEqual(view.amountInputView.locale, Locale(identifier: "en"))

        view.locale = Locale(identifier: "ru")
        XCTAssertEqual(
            view.actionButton.imageWithTitleView?.title,
            R.string.localizable.commonContinue(preferredLanguages: ["ru"])
        )
        XCTAssertEqual(view.networkFeeView.locale, Locale(identifier: "ru"))

        view.networkFeeView.bind(viewModel: BalanceViewModel(amount: "0.1 DOT", price: "$0.3"))
        XCTAssertEqual(view.networkFeeView.tokenLabel.text, "0.1 DOT")
        XCTAssertEqual(view.networkFeeView.fiatLabel?.text, "$0.3")
    }
}
