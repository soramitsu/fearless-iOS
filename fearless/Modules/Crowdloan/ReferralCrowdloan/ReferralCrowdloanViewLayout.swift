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

    let applyAppBonusButton: GradientButton = {
        let button = GradientButton()
        button.applyDefaultStyle()
        button.applyDisabledStyle()
        button.gradientBackgroundView?.cornerRadius = Constants.applyAppButtonHeight / 2.0
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        return button
    }()

    let bonusView: TitleValueView = UIFactory.default.createTitleValueView()

    private(set) var friendBonusView: TitleValueView = UIFactory.default.createTitleValueView()
    private(set) var myBonusView: TitleValueView = UIFactory.default.createTitleValueView()

    let privacyView: UIView = {
        UIView()
    }()

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

        applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.applyFearlessWalletBonus(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        codeInputView.animatedInputField.title = R.string.localizable.commonReferralCodeTitle(
            preferredLanguages: locale.rLanguages
        )

        bonusView.titleLabel.text = R.string.localizable.commonBonus(preferredLanguages: locale.rLanguages)
        myBonusView.titleLabel.text = R.string.localizable.astarBonus(preferredLanguages: locale.rLanguages)
        friendBonusView.titleLabel.text = R.string.localizable.astarFriendBonus(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        // TODO: Move magic numbers to constants
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(codeInputView)
        codeInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(applyAppBonusButton)
        applyAppBonusButton.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: codeInputView)
        contentView.stackView.setCustomSpacing(16.0, after: applyAppBonusButton)

        contentView.stackView.addArrangedSubview(friendBonusView)
        friendBonusView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: friendBonusView)

        contentView.stackView.addArrangedSubview(myBonusView)
        myBonusView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: myBonusView)

        contentView.stackView.addArrangedSubview(bonusView)
        bonusView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: bonusView)

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
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }

    func bind(to viewModel: ReferralCrowdloanViewModel) {
        bonusView.valueLabel.text = viewModel.bonusValue
        applyAppBonusButton.isEnabled = viewModel.canApplyDefaultCode
        applyAppBonusButton.imageWithTitleView?.title = viewModel.applyAppBonusButtonTitle(for: locale.rLanguages)
        applyAppBonusButton.setEnabled(!viewModel.canApplyDefaultCode)

        applyAppBonusButton.invalidateLayout()

        termsSwitchView.isOn = viewModel.isTermsAgreed
        actionButton.imageWithTitleView?.title = viewModel.actionButtonTitle(for: locale.rLanguages)

        actionButton.invalidateLayout()

        setNeedsLayout()
    }

    func bind(to viewModel: AstarReferralCrowdloanViewModel) {
        friendBonusView.valueLabel.text = viewModel.friendBonusValue
        myBonusView.valueLabel.text = viewModel.myBonusValue
        applyAppBonusButton.isEnabled = viewModel.canApplyDefaultCode
        applyAppBonusButton.imageWithTitleView?.title = viewModel.applyAppBonusButtonTitle(for: locale.rLanguages)
        applyAppBonusButton.setEnabled(!viewModel.canApplyDefaultCode)

        applyAppBonusButton.invalidateLayout()

        actionButton.imageWithTitleView?.title = viewModel.actionButtonTitle(for: locale.rLanguages)

        actionButton.invalidateLayout()

        setNeedsLayout()
    }
}
