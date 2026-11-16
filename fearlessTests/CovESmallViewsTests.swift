@testable import fearless
import SoraFoundation
import SoraUI
import UIKit
import XCTest

/// Small reusable views: binding, layout invariants and callbacks.
@MainActor
final class CovESmallViewsTests: XCTestCase {
    func testLearnMoreViewBindsPlainAndUnderlinedSubtitles() throws {
        let view = LearnMoreView()
        view.contentInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        XCTAssertEqual(view.intrinsicContentSize, CGSize(width: UIView.noIntrinsicMetric, height: 48))
        let icon = BundleImageViewModel(image: R.image.iconClose())
        view.bind(viewModel: LearnMoreViewModel(iconViewModel: icon, title: "Wiki", subtitle: "Read more"))
        XCTAssertEqual(view.titleLabel.text, "Wiki")
        XCTAssertEqual(view.subtitleLabel.text, "Read more")
        XCTAssertEqual(view.iconView.image, R.image.iconClose())
        view.bind(viewModel: LearnMoreViewModel(iconViewModel: nil, title: "Terms", subtitle: "Open terms", subtitleUnderlined: true))
        XCTAssertNil(view.iconView.image, "Rebinding cancels the previous icon")
        let attributed = try XCTUnwrap(view.subtitleLabel.attributedText)
        XCTAssertEqual(attributed.string, "Open terms")
        XCTAssertNotNil(attributed.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        view.bind(viewModel: nil)
        XCTAssertNil(view.titleLabel.text)

        let window = CovEHost.window(for: view, frame: CGRect(x: 0, y: 100, width: 390, height: 48))
        defer { CovEHost.close(window) }
        XCTAssertEqual(view.contentView?.frame, CGRect(x: 16, y: 4, width: 358, height: 40))
        XCTAssertNotNil(view.backgroundView as? ShapeView)
    }

    func testHintInfoTitleAndSelectionViews() {
        let hint = HintView()
        hint.titleLabel.text = "Fees are paid in DOT"
        let window = CovEHost.window(for: hint, frame: CGRect(x: 16, y: 100, width: 358, height: 40))
        defer { CovEHost.close(window) }
        XCTAssertFalse(hint.iconView.isHidden)
        XCTAssertGreaterThanOrEqual(hint.titleLabel.frame.minX, hint.iconView.frame.maxX)
        hint.setIconHidden(true)
        hint.layoutIfNeeded()
        XCTAssertTrue(hint.iconView.isHidden)
        XCTAssertEqual(hint.titleLabel.frame.minX, 0, accuracy: 0.5, "A hidden icon gives its room to the title")
        hint.setIconHidden(false)
        hint.layoutIfNeeded()
        XCTAssertGreaterThan(hint.titleLabel.frame.minX, 0)

        let info = InfoTitleView(frame: .zero)
        info.titleLabel.text = "Rewards"
        info.set(highlighted: true, animated: false)
        XCTAssertTrue(info.isHighlighted)
        XCTAssertTrue(info.titleLabel.isHighlighted)
        XCTAssertTrue(info.iconImageView.isHighlighted)
        info.set(highlighted: false, animated: true)
        XCTAssertFalse(info.isHighlighted, "The animation lands on the requested state")
        XCTAssertEqual(info.alpha, 1)
        let decoded = InfoTitleView(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertEqual(decoded?.subviews.count, 2)

        let selection = TitleValueSelectionView()
        selection.titleLabel.text = "Network"
        selection.detailsLabel.text = "Polkadot"
        let second = CovEHost.window(for: selection, frame: CGRect(x: 16, y: 100, width: 358, height: 48))
        defer { CovEHost.close(second) }
        XCTAssertLessThan(selection.detailsLabel.frame.maxX, selection.arrowIconView.frame.minX + 0.5)
        XCTAssertEqual(selection.detailsLabel.textColor, R.color.colorPink())
    }

    func testWarningTitleStatusAndTwoLabelViews() {
        let warning = WarningView()
        warning.titleLabel.text = "Attention"
        warning.textLabel.text = "This network is deprecated"
        let window = CovEHost.window(for: warning, frame: CGRect(x: 16, y: 100, width: 358, height: 80))
        defer { CovEHost.close(window) }
        XCTAssertEqual(warning.hStack.arrangedSubviews, [warning.iconView, warning.vStack])
        XCTAssertEqual(warning.vStack.arrangedSubviews, [warning.titleLabel, warning.textLabel])
        XCTAssertEqual(warning.backgroundView.frame.size, warning.bounds.size)

        let status = TitleStatusView()
        status.titleLabel.text = "Active"
        status.indicatorColor = .green
        XCTAssertEqual(status.indicatorColor, .green)
        status.spacing = 6
        XCTAssertEqual(status.spacing, 6)
        let stack = CovEFind.first(UIStackView.self, in: status)
        XCTAssertEqual(stack?.arrangedSubviews.first, status.titleLabel)
        status.mode = .indicatorTile
        XCTAssertEqual(stack?.arrangedSubviews.first, status.indicatorView)
        XCTAssertEqual(stack?.arrangedSubviews.count, 2)

        let twoLabels = TwoVerticalLabelView(frame: .zero)
        twoLabels.titleLabel.text = "Title"
        twoLabels.subtitleLabelView.text = "A much longer subtitle"
        twoLabels.verticalSpacing = 5
        twoLabels.horizontalSubtitleSpacing = 4
        let size = twoLabels.intrinsicContentSize
        XCTAssertEqual(size.width, twoLabels.subtitleLabelView.intrinsicContentSize.width)
        XCTAssertEqual(size.height, twoLabels.titleLabel.intrinsicContentSize.height + 5 + twoLabels.subtitleLabelView.intrinsicContentSize.height)
        let second = CovEHost.window(for: twoLabels, frame: CGRect(x: 16, y: 300, width: 300, height: 60))
        defer { CovEHost.close(second) }
        XCTAssertEqual(twoLabels.subtitleLabelView.frame.minY, twoLabels.titleLabel.frame.maxY + 5, accuracy: 0.5)
        let decoded = TwoVerticalLabelView(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertEqual(decoded?.subviews.count, 2)
    }

    func testErrorStateViewRetriesAndLocalizes() {
        let view = ErrorStateView()
        let delegate = CovEErrorDelegate()
        view.delegate = delegate
        view.locale = Locale(identifier: "en")
        XCTAssertEqual(view.retryButton.title(for: .normal), R.string.localizable.commonRetry(preferredLanguages: ["en"]))
        view.retryButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.retries, 1)
        view.setRetryEnabled(false)
        XCTAssertTrue(view.retryButton.isHidden)
        view.setRetryEnabled(true)
        XCTAssertFalse(view.retryButton.isHidden)
        view.setTitle("Network error")
        XCTAssertEqual(view.errorTitleLabel.text, "Network error")
        XCTAssertFalse(view.errorTitleLabel.isHidden)
        view.setTitle(nil)
        XCTAssertTrue(view.errorTitleLabel.isHidden)
        view.locale = Locale(identifier: "ja")
        XCTAssertEqual(view.retryButton.title(for: .normal), R.string.localizable.commonRetry(preferredLanguages: ["ja"]))
    }

    func testStakeAmountViewAppliesAmountAndShadowColor() {
        let view = StakeAmountView()
        let amount = NSAttributedString(string: "12.5 DOT")
        view.bind(viewModel: StakeAmountViewModel(amountTitle: amount, iconViewModel: nil, color: "#FF0000"))
        XCTAssertEqual(view.amountLabel.attributedText?.string, "12.5 DOT")
        XCTAssertNotEqual(view.iconBackground.shadowColor, .clear, "A valid hex colour tints the icon shadow")
        let plain = StakeAmountView()
        plain.bind(viewModel: StakeAmountViewModel(amountTitle: amount, iconViewModel: nil, color: nil))
        XCTAssertEqual(plain.iconBackground.shadowColor, .clear)
        let window = CovEHost.window(for: view, frame: CGRect(x: 0, y: 100, width: 390, height: 200))
        defer { CovEHost.close(window) }
        XCTAssertEqual(view.iconBackground.frame.size, CGSize(width: 100, height: 100))
        XCTAssertGreaterThan(view.amountLabel.frame.minY, view.iconBackground.frame.minY)
    }

    func testLinkedLabelReportsTapsInsideLinkRangesOnly() throws {
        let label = LinkedLabel()
        let text = "Read the terms"
        label.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 17)])
        label.frame = CGRect(origin: .zero, size: label.intrinsicContentSize)
        let url = try XCTUnwrap(URL(string: "https://example.invalid/terms"))
        let delegate = CovELinkDelegate()
        label.setLinks([(url, NSRange(location: 9, length: 5))], delegate: delegate)
        XCTAssertTrue(label.isUserInteractionEnabled)
        XCTAssertEqual(label.gestureRecognizers?.count, 1)

        let tap = CovETap()
        tap.stubLocation = CGPoint(x: label.bounds.width - 3, y: label.bounds.midY)
        label.tappedOnLabel(tap)
        XCTAssertEqual(delegate.links, [url])
        tap.stubLocation = CGPoint(x: 2, y: label.bounds.midY)
        label.tappedOnLabel(tap)
        XCTAssertEqual(delegate.links, [url], "Taps outside the link are ignored")
    }

    func testNetworkFeeFooterCreatesFeeAndDurationRowsLazily() {
        let footer = NetworkFeeFooterView()
        footer.locale = Locale(identifier: "en")
        XCTAssertEqual(footer.actionButton.imageWithTitleView?.title, R.string.localizable.commonConfirm(preferredLanguages: ["en"]))
        footer.actionTitle = LocalizableResource { _ in "Send" }
        XCTAssertEqual(footer.actionButton.imageWithTitleView?.title, "Send")
        XCTAssertNil(footer.networkFeeView)
        footer.bindBalance(viewModel: BalanceViewModel(amount: "0.01 DOT", price: "$0.05"))
        let fee = footer.networkFeeView
        XCTAssertNotNil(fee)
        footer.bindBalance(viewModel: nil)
        XCTAssertTrue(footer.networkFeeView === fee, "The fee row is created once")
        footer.bindDuration(viewModel: LocalizableResource { _ in TitleWithSubtitleViewModel(title: "Duration", subtitle: "~6 s") })
        XCTAssertEqual(footer.durationView?.titleLabel.text, "Duration")
        XCTAssertEqual(footer.durationView?.valueLabel.text, "~6 s")
        footer.bindDuration(viewModel: LocalizableResource { _ in TitleWithSubtitleViewModel(title: "Time", subtitle: "~12 s") })
        XCTAssertEqual(footer.durationView?.valueLabel.text, "~12 s")
        footer.locale = Locale(identifier: "ja")
        XCTAssertEqual(footer.networkFeeView?.locale, Locale(identifier: "ja"))

        XCTAssertTrue(footer.extendsUnderSafeArea)
        XCTAssertTrue(footer.contentView === footer)
        footer.isActionEnabled = false
        XCTAssertFalse(footer.isActionEnabled)
        footer.isActionEnabled = true
        XCTAssertTrue(footer.isActionEnabled)
        footer.bind(viewModel: AccessoryViewModel(title: "Fee", action: "Confirm"))
        XCTAssertEqual(footer.actionButton.imageWithTitleView?.title, "Confirm")
        XCTAssertEqual(footer.networkFeeView?.titleLabel.text, "Fee")
        footer.bind(viewModel: ExtrinisicConfirmViewModel(
            title: "Network fee", amount: "0.02 DOT", price: "$0.10", icon: nil, action: "Pay", numberOfLines: 1, shouldAllowAction: true
        ))
        XCTAssertEqual(footer.networkFeeView?.titleLabel.text, "Network fee")
        let window = CovEHost.window(for: footer, frame: CGRect(x: 0, y: 500, width: 390, height: 200))
        defer { CovEHost.close(window) }
        XCTAssertEqual(footer.actionButton.frame.height, UIConstants.actionHeight)
    }
}

final class CovEErrorDelegate: ErrorStateViewDelegate {
    private(set) var retries = 0

    func didRetry(errorView _: ErrorStateView) {
        retries += 1
    }
}

final class CovELinkDelegate: TappedLabelDelegate {
    private(set) var links: [URL] = []

    func didTappedOn(link: URL) {
        links.append(link)
    }
}

final class CovETap: UITapGestureRecognizer {
    var stubLocation: CGPoint = .zero

    override func location(in _: UIView?) -> CGPoint {
        stubLocation
    }
}
