import UIKit

final class BalanceInfoViewLayout: UIView {
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .center
        return label
    }()

    private let balanceContainerView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.lineBreakMode = .byTruncatingMiddle
        return label
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
        priceLabel.attributedText = viewModel.dayChangeAttributedString
        balanceLabel.text = viewModel.balanceString

        balanceLabel.layoutIfNeeded()
        priceLabel.layoutIfNeeded()
    }

    private func setupLayout() {
        balanceContainerView.addArrangedSubview(balanceLabel)

        let vStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        vStackView.alignment = .fill
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        vStackView.addArrangedSubview(priceLabel)
        vStackView.addArrangedSubview(balanceContainerView)

        balanceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
