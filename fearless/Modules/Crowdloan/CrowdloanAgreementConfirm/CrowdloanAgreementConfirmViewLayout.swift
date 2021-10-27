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

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView()

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

    let networkFeeConfirmView: NetworkFeeConfirmView = UIFactory().createNetworkFeeConfirmView()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
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

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
    }

    func bind(accountViewModel: CrowdloanAccountViewModel?) {
        let icon = accountViewModel?.accountIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        accountView.iconImage = icon
        accountView.subtitle = accountViewModel?.accountName
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.moonbeamRegistration(preferredLanguages: locale.rLanguages)
        accountView.title = R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages)
        infoLabel.text = R.string.localizable.moonbeamRegistrationDescription(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages).capitalized
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

        bottomView.addSubview(networkFeeConfirmView)

        networkFeeConfirmView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset * 2)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
        }

        bottomView.addSubview(bottomSeparatorView)

        bottomSeparatorView.snp.makeConstraints { make in
            make.top.equalTo(networkFeeConfirmView.snp.bottom).offset(UIConstants.bigOffset)
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
    }
}
