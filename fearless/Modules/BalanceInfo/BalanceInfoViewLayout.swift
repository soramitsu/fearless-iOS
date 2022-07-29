import UIKit

final class BalanceInfoViewLayout: UIView {
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
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
    }

    private func setupLayout() {
        let vStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        vStackView.alignment = .center
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        vStackView.addArrangedSubview(priceLabel)
        vStackView.addArrangedSubview(balanceLabel)
    }
}
