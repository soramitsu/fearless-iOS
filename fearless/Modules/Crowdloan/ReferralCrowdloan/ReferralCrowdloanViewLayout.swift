import UIKit
import SoraUI

final class ReferralCrowdloanViewLayout: UIView {
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
        button.applyDefaultStyle()
        button.gradientBackgroundView?.cornerRadius = Constants.applyAppButtonHeight / 2.0
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        return button
    }()

    let bonusView: TitleValueView = UIFactory.default.createTitleValueView()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.numberOfLines = 2
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
        termsLabel.attributedText = NSAttributedString.crowdloanTerms(for: locale)

        applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        codeInputView.animatedInputField.title = R.string.localizable.commonReferralCodeTitle(
            preferredLanguages: locale.rLanguages
        )

        bonusView.titleLabel.text = R.string.localizable.commonBonus(preferredLanguages: locale.rLanguages)
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

        contentView.stackView.addArrangedSubview(bonusView)
        bonusView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: bonusView)

        let privacyView = UIView()
        contentView.stackView.addArrangedSubview(privacyView)
        privacyView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        privacyView.addSubview(termsSwitchView)
        termsSwitchView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        privacyView.addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsSwitchView.snp.trailing).offset(16.0)
            make.trailing.centerY.equalToSuperview()
        }

        contentView.stackView.setCustomSpacing(16.0, after: privacyView)

        contentView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self)
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
