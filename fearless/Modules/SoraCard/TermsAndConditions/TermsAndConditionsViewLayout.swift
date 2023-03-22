import UIKit
import SoraSwiftUI
import SoraUI

final class TermsAndConditionsViewLayout: UIView {
    private enum LayoutConstants {
        static let acceptVerticalOffset: CGFloat = 32
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        bar.backgroundColor = R.color.colorBlack()
        bar.backButton.isHidden = true
        return bar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClosePinkBold(), for: .normal)
        return button
    }()

    private let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private let warningLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldM
        label.sora.textColor = .fgPrimary
        label.sora.contentInsets = .init(all: UIConstants.bigOffset)
        label.sora.backgroundColor = .bgSurface
        label.sora.cornerRadius = .small
        label.sora.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .small
        view.spacing = 0
        view.sora.cornerRadius = .small
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(
            top: 0,
            left: UIConstants.hugeOffset,
            bottom: 0,
            right: UIConstants.hugeOffset
        )
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let generalTermsButton = TermsConditionsButton()
    let privacyButton = TermsConditionsButton()

    private let acceptDesriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgTertiary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    let acceptButton: RoundedButton = {
        let button = RoundedButton()
        button.applySoraSecondaryStyle()
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
        backgroundColor = R.color.bgPage()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TermsAndConditionsViewLayout {
    func setupLayout() {
        navigationBar.setRightViews([closeButton])

        addSubview(navigationBar)
        addSubview(contentView)

        containerView.addArrangedSubviews(generalTermsButton, privacyButton)

        contentView.stackView.addArrangedSubviews([
            titleLabel,
            textLabel,
            warningLabel,
            containerView,
            acceptDesriptionLabel,
            acceptButton
        ])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.stackView.subviews.forEach { view in
            view.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.bottom.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        acceptButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.soraCardButtonHeight)
        }

        contentView.stackView.setCustomSpacing(
            LayoutConstants.acceptVerticalOffset,
            after: containerView
        )
        contentView.stackView.setCustomSpacing(
            0,
            after: generalTermsButton
        )
    }

    func applyLocalization() {
        let warningLabelTextMain = SoramitsuTextItem(
            text: R.string.localizable.termsAndConditionsSoraCommunityAlertMain(preferredLanguages: locale.rLanguages),
            fontData: FontType.textBoldM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelTextSecondary = SoramitsuTextItem(
            text: R.string.localizable
                .termsAndConditionsSoraCommunityAlertSecondary(preferredLanguages: locale.rLanguages),
            fontData: FontType.textM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelText = NSMutableAttributedString()
        warningLabelText.append(warningLabelTextMain.attributedString)
        warningLabelText.append(warningLabelTextSecondary.attributedString)
        warningLabel.sora.attributedText = warningLabelText

        titleLabel.sora.text = R.string.localizable
            .termsAndConditionsTitle(preferredLanguages: locale.rLanguages)
        textLabel.sora.text = R.string.localizable
            .termsAndConditionsDescription(preferredLanguages: locale.rLanguages)
        generalTermsButton.titleLable.sora.text = R.string.localizable
            .termsAndConditionsGeneralTerms(preferredLanguages: locale.rLanguages)
        privacyButton.titleLable.sora.text = R.string.localizable
            .termsAndConditionsPrivacyPolicy(preferredLanguages: locale.rLanguages)
        acceptDesriptionLabel.sora.text = R.string.localizable
            .termsAndConditionsConfirmDescription(preferredLanguages: locale.rLanguages)
        acceptButton.imageWithTitleView?.title = R.string.localizable
            .termsAndConditionsAcceptAndContinue(preferredLanguages: locale.rLanguages).uppercased()
    }
}
