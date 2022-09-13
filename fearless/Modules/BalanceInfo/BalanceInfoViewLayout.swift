import UIKit

final class BalanceInfoViewLayout: UIView {
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let balanceContainerView: UIView = {
        let view = UIView()
        return view
    }()

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfoGrayFilled(), for: .normal)
        button.isHidden = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: BalanceInfoViewModel) {
        infoButton.isHidden = !viewModel.infoButtonEnabled
        priceLabel.attributedText = viewModel.dayChangeAttributedString
        balanceLabel.text = viewModel.balanceString
    }

    private func setupLayout() {
        balanceContainerView.addSubview(balanceLabel)
        balanceContainerView.addSubview(infoButton)
        balanceLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.leading.equalTo(balanceLabel.snp.trailing).offset(UIConstants.minimalOffset)
            make.centerY.equalTo(balanceLabel)
        }

        let vStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        vStackView.alignment = .center
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        vStackView.addArrangedSubview(priceLabel)
        vStackView.addArrangedSubview(balanceContainerView)
    }
}
