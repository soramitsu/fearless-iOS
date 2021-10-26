import UIKit
import FearlessUtils

final class CrowdloanAgreementConfirmViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .leading
        view.stackView.spacing = UIConstants.verticalInset
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .left
        label.numberOfLines = 2
        return label
    }()

    let accountView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        return view
    }()

    let accountViewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    let accountViewIconImageView: PolkadotIconView = {
        PolkadotIconView()
    }()

    let accountViewNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    let infoIconImageView: UIImageView = {
        UIImageView()
    }()

    let infoContainer: UIView = {
        UIView()
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    let bottomView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorAlmostBlack()
        return view
    }()

    let networkFeeTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    let networkFeeDotLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let networkFeeUsdLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let feeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        return stackView
    }()

    let feeCurrenciesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let bottomSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        return view
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

        backgroundColor = R.color.colorBlack()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.moonbeamRegistration(preferredLanguages: locale.rLanguages)
        accountViewTitleLabel.text = R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages)
        infoLabel.text = R.string.localizable.moonbeamRegistrationDescription(preferredLanguages: locale.rLanguages)
        networkFeeTitleLabel.text = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages).uppercased()
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.width.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(accountView)

        accountView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset)
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        accountView.addSubview(accountViewTitleLabel)

        accountViewTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
        }

        accountView.addSubview(accountViewIconImageView)

        accountViewIconImageView.snp.makeConstraints { make in
            make.width.equalTo(UIConstants.triangularedIconSmallRadius * 2)
            make.height.equalTo(UIConstants.triangularedIconSmallRadius * 2)
            make.leading.equalTo(accountViewTitleLabel.snp.leading)
            make.top.equalTo(accountViewTitleLabel.snp.bottom).offset(UIConstants.minimalOffset)
        }

        accountView.addSubview(accountViewNameLabel)

        accountViewNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(accountViewIconImageView.snp.trailing).offset(UIConstants.minimalOffset)
            make.top.equalTo(accountViewIconImageView.snp.top)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        contentView.stackView.addArrangedSubview(infoContainer)

        infoContainer.addSubview(infoIconImageView)

        infoIconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview()
            make.width.equalTo(14)
            make.height.equalTo(14)
        }

        infoContainer.addSubview(infoLabel)

        infoLabel.snp.makeConstraints { make in
            make.leading.equalTo(infoIconImageView.snp.trailing).offset(UIConstants.defaultOffset)
            make.top.equalTo(infoIconImageView.snp.top)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview()
        }

        addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        bottomView.addSubview(feeStackView)

        feeStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset * 2)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
        }
        feeStackView.addArrangedSubview(networkFeeTitleLabel)
        feeStackView.addArrangedSubview(feeCurrenciesStackView)
        feeCurrenciesStackView.addArrangedSubview(networkFeeDotLabel)
        feeCurrenciesStackView.addArrangedSubview(networkFeeUsdLabel)

        bottomView.addSubview(bottomSeparatorView)

        bottomSeparatorView.snp.makeConstraints { make in
            make.top.equalTo(feeStackView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalTo(UIConstants.bigOffset * 2)
            make.centerX.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }

        bottomView.addSubview(confirmButton)

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(bottomSeparatorView.snp.bottom).offset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
            make.bottom.equalToSuperview().inset(UIConstants.hugeOffset)
        }

        confirmButton.applyEnabledStyle()

//        contentView.stackView.addArrangedSubview(textView)
//
//        let privacyView = UIView()
//        contentView.stackView.addArrangedSubview(privacyView)
//        privacyView.snp.makeConstraints { make in
//            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
//            make.height.equalTo(48.0)
//        }
//
//        privacyView.addSubview(termsSwitchView)
//        termsSwitchView.snp.makeConstraints { make in
//            make.leading.centerY.equalToSuperview()
//        }
//
//        privacyView.addSubview(termsLabel)
//        termsLabel.snp.makeConstraints { make in
//            make.leading.equalTo(termsSwitchView.snp.trailing).offset(16.0)
//            make.trailing.centerY.equalToSuperview()
//        }
//
//        contentView.stackView.setCustomSpacing(16.0, after: privacyView)
//
//        addSubview(confirmAgreementButton)
//        confirmAgreementButton.snp.makeConstraints { make in
//            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
//            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
//            make.height.equalTo(UIConstants.actionHeight)
//        }
//
//        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }
}
