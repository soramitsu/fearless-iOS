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

    let applyAppBonusButton: RoundedButton = {
        let button = RoundedButton()
        button.roundedBackgroundView?.fillColor = R.color.colorBonusBackground()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorBonusBackground()!
        button.imageWithTitleView?.titleColor = R.color.colorWhite()
        button.changesContentOpacityWhenHighlighted = true
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        button.roundedBackgroundView?.cornerRadius = Constants.applyAppButtonHeight / 2.0
        return button
    }()

    let bonusView: TitleValueView = UIFactory.default.createTitleValueView()

    let signView: UISwitch = {
        let switchView = UISwitch()
        switchView.tintColor = R.color.colorAccent()
        return switchView
    }()

    let privacyLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        return label
    }()

    let learnMoreView = UIFactory.default.createLearnMoreView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.stackView.addArrangedSubview(codeInputView)
        codeInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: codeInputView)

        contentView.stackView.addArrangedSubview(applyAppBonusButton)
        applyAppBonusButton.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(Constants.applyAppButtonHeight)
        }

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
    }
}
