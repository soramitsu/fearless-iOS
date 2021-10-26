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
        label.font = .h5Title
        label.textAlignment = .left
        label.numberOfLines = 2
        return label
    }()

    let accountView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorDarkGray()!
        view.highlightedStrokeColor = R.color.colorDarkGray()!
        view.strokeWidth = 1.0
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
        label.font = .p1Paragraph
        return label
    }()

    let bottomView: UIView = {
        let view = UIView()
        return view
    }()

    let networkFeeTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
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
        return label
    }()

    let confirmButton: TriangularedButton = {
        TriangularedButton()
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

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
//        termsLabel.text = R.string.localizable.crowdloanPrivacyPolicy(preferredLanguages: locale.rLanguages)
//
//        confirmAgreementButton.imageWithTitleView?.title = R.string.localizable.commonApply(
//            preferredLanguages: locale.rLanguages
//        ).uppercased()
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        contentView.stackView.addArrangedSubview(titleLabel)

        contentView.stackView.addArrangedSubview(accountView)

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

        contentView.stackView.addSubview(infoContainer)

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
        bottomView.addSubview(feeStackView)
        feeStackView.addArrangedSubview(networkFeeTitleLabel)
        feeStackView.addArrangedSubview(feeCurrenciesStackView)
        feeCurrenciesStackView.addArrangedSubview(networkFeeDotLabel)
        feeCurrenciesStackView.addArrangedSubview(networkFeeUsdLabel)
        bottomView.addSubview(confirmButton)

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
