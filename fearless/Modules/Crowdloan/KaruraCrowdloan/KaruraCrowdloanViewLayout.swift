import UIKit
import SoraUI

final class KaruraCrowdloanViewLayout: UIView {
    private enum Constants {
        static let applyAppButtonHeight: CGFloat = 24.0
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let codeInputView = UIFactory.default.createCommonInputView()

    let applyAppBonusView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.strokeColor = R.color.colorDarkGray()!
        view.borderType = .bottom
        view.strokeWidth = 1.0
        return view
    }()

    let applyAppBonusLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let applyAppBonusButton: GradientButton = {
        let button = GradientButton()
        button.gradientBackgroundView?.startColor = R.color.colorAccentGradientEnd()!
        button.gradientBackgroundView?.startPoint = CGPoint(x: 0.0, y: 0.5)
        button.gradientBackgroundView?.endPoint = CGPoint(x: 1.0, y: 0.5)
        button.gradientBackgroundView?.endColor = R.color.colorAccentGradientStart()!
        button.gradientBackgroundView?.cornerRadius = Constants.applyAppButtonHeight / 2.0
        button.imageWithTitleView?.titleColor = R.color.colorWhite()
        button.imageWithTitleView?.titleFont = .h6Title
        button.changesContentOpacityWhenHighlighted = true
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        return button
    }()

    let bonusView: TitleValueView = UIFactory.default.createTitleValueView()

    let signView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let privacyLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        return label
    }()

    let learnMoreView = UIFactory.default.createLearnMoreView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        privacyLabel.attributedText = NSAttributedString.crowdloanTerms(for: locale)

        applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        // TODO: Fix localization
        applyAppBonusLabel.text = "Fearless Wallet bonus (5%)"
        codeInputView.textField.title = "Referral code"
        bonusView.titleLabel.text = "Bonus"
        actionButton.imageWithTitleView?.title = "Enter your referral code"
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(applyAppBonusView)
        applyAppBonusView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: applyAppBonusView)

        applyAppBonusView.addSubview(applyAppBonusLabel)
        applyAppBonusLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        applyAppBonusView.addSubview(applyAppBonusButton)
        applyAppBonusButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(applyAppBonusLabel.snp.trailing).offset(8.0)
        }

        contentView.stackView.addArrangedSubview(codeInputView)
        codeInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: codeInputView)

        let privacyView = UIView()
        contentView.stackView.addArrangedSubview(privacyView)
        privacyView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        privacyView.addSubview(signView)
        signView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        privacyView.addSubview(privacyLabel)
        privacyLabel.snp.makeConstraints { make in
            make.leading.equalTo(signView.snp.trailing).offset(16.0)
            make.trailing.centerY.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }
}
