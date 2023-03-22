import UIKit
import SoraSwiftUI

final class KYCMainViewLayout: UIView {
    private enum LayoutConstants {
        static let buttonHeight: CGFloat = 30
    }

    private let scrollView = UIScrollView()

    private var containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 16
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let iconView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.picture = .logo(image: R.image.soraCardFront()!)
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private var feeContainerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 16
        view.sora.cornerRadius = .medium
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let feeLabel: SCFeeLabelView = {
        let view = SCFeeLabelView()
        view.iconView.sora.picture = .icon(image: R.image.listCheckmarkIcon()!, color: .statusSuccess)
        return view
    }()

    private var detailsContainerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 16
        view.sora.cornerRadius = .medium
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let detailsTitleLabel: SCFeeLabelView = {
        let view = SCFeeLabelView()
        view.iconView.sora.picture = .icon(image: R.image.cross()!, color: .statusError)
        return view
    }()

    private let detailsDescriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private let balanceProgressView: SCBalanceProgressView = {
        let view = SCBalanceProgressView()
        view.configure(progressPercentage: 0, title: "checking balance ...")
        return view
    }()

    private let detailsFeeLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.isHidden = true
        return label
    }()

    private let unsupportedCountriesDisclaimerLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center

        return label
    }()

    lazy var unsupportedCountriesButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .text(.primary))
        return button
    }()

    lazy var actionButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.primary))
        button.sora.cornerRadius = .custom(28)
        return button
    }()

    lazy var issueCardButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .outlined(.primary))
        button.sora.cornerRadius = .custom(28)
        return button
    }()

    lazy var haveCardButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .bleached(.primary))
        button.sora.cornerRadius = .custom(28)
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateHaveCardButton(isHidden: Bool) {
        haveCardButton.isHidden = isHidden
    }

    func set(viewModel: KYCMainViewModel) {
        balanceProgressView.configure(progressPercentage: viewModel.percentage, title: viewModel.title)

        if viewModel.hasFreeAttempts {
            if viewModel.hasEnoughBalance {
                detailsTitleLabel.iconView.sora.picture = .icon(image: R.image.listCheckmarkIcon()!, color: .statusSuccess)
                detailsTitleLabel.titleLabel.sora.text = R.string.localizable.soraCardFreeCardIssuance(preferredLanguages: locale.rLanguages)
                actionButton.sora.title = R.string.localizable.detailsIssueCard(preferredLanguages: locale.rLanguages)
            } else {
                actionButton.sora.title = R.string.localizable.detailsGetMoreXor(preferredLanguages: locale.rLanguages)
            }
        } else {
            detailsTitleLabel.iconView.sora.picture = .icon(image: R.image.exclamation()!, color: .statusWarning)
            detailsTitleLabel.titleLabel.sora.text = R.string.localizable.soraCardNoFreeAttempts(preferredLanguages: locale.rLanguages)
            actionButton.isHidden = true
//            Phase2 TODO:
//            actionButton.sora.title = R.string.localizable.soraCardIssueCardTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func show(error: String) {
        titleLabel.sora.text = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale.rLanguages)
        textLabel.sora.text = "\(error)"
    }
}

private extension KYCMainViewLayout {
    func setupLayout() {
        addSubview(scrollView)

        detailsContainerView.addArrangedSubviews([
            detailsTitleLabel,
            detailsDescriptionLabel,
            balanceProgressView,
            detailsFeeLabel
        ])

        feeContainerView.addArrangedSubview(feeLabel)

        containerView.addArrangedSubviews([
            iconView,
            titleLabel,
            textLabel,
            feeContainerView,
            detailsContainerView,
            unsupportedCountriesDisclaimerLabel,
            unsupportedCountriesButton,
            actionButton,
            haveCardButton
        ])

        scrollView.addSubview(containerView)

        scrollView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalTo(self).inset(16)
        }

        unsupportedCountriesButton.snp.makeConstraints {
            $0.height.equalTo(LayoutConstants.buttonHeight)
        }
    }

    func applyLocalization() {
        titleLabel.sora.text = R.string.localizable.soraCardTitle(preferredLanguages: locale.rLanguages)
        textLabel.sora.text = R.string.localizable.soraCardDescription(preferredLanguages: locale.rLanguages)
        feeLabel.titleLabel.sora.text =
            R.string.localizable.soraCardAnnualServiceFee(preferredLanguages: locale.rLanguages)
        detailsTitleLabel.titleLabel.sora.text =
            R.string.localizable.soraCardFreeCardIssuance(preferredLanguages: locale.rLanguages)
        detailsDescriptionLabel.sora.text =
            R.string.localizable.soraCardFreeCardIssuanceConditionsXor(preferredLanguages: locale.rLanguages)
        detailsFeeLabel.sora.text =
            R.string.localizable.soraCardFreeCardIssuanceConditionsEuro(preferredLanguages: locale.rLanguages)
        unsupportedCountriesDisclaimerLabel.sora.text =
            R.string.localizable.unsupportedCountriesDisclaimer(preferredLanguages: locale.rLanguages)
        let unsupportedCountriesLinkText =
            R.string.localizable.unsupportedCountriesLink(preferredLanguages: locale.rLanguages)
        unsupportedCountriesButton.sora.attributedText = SoramitsuTextItem(
            text: unsupportedCountriesLinkText,
            fontData: FontType.paragraphXS,
            textColor: .accentPrimary,
            alignment: .center,
            underline: .single
        )
        actionButton.sora.title = R.string.localizable.detailsGetMoreXor(preferredLanguages: locale.rLanguages)
        issueCardButton.sora.title = R.string.localizable.soraCardIssueCardTitle(preferredLanguages: locale.rLanguages)
        haveCardButton.sora.title =
            R.string.localizable.detailsAlreadyHaveCard(preferredLanguages: locale.rLanguages)
    }
}
