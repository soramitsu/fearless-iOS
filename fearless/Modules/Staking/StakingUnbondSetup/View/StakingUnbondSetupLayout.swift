import UIKit
import SnapKit

final class StakingUnbondSetupLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let amountInputView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: false)
        return view
    }()

    let networkFeeView = NetworkFeeView()

    let durationView = TitleValueView()

    let footerLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

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

        backgroundColor = R.color.colorBlack()!

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        networkFeeView.locale = locale

        footerLabel.text = R.string.localizable.stakingUnbondingHint(preferredLanguages: locale.rLanguages)
        durationView.titleLabel.text = R.string.localizable
            .stakingUnbondingPeriod(preferredLanguages: locale.rLanguages)

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: amountInputView)

        contentView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(durationView)
        durationView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        let footerView = createFooterView()
        contentView.stackView.addArrangedSubview(footerView)

        footerView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.bottom.equalTo(footerLabel).offset(16.0)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func createFooterView() -> UIView {
        let footerView = UIView()

        let iconView = UIImageView(image: R.image.iconInfoFilled()?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = R.color.colorGray()

        footerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().inset(16.0)
            make.size.equalTo(14.0)
        }

        footerView.addSubview(footerLabel)
        footerLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.top).offset(-1.0)
            make.leading.equalTo(iconView.snp.trailing).offset(9.0)
            make.trailing.equalToSuperview()
        }

        return footerView
    }
}
