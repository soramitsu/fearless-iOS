import UIKit

final class BalancePriceHorizontalView: UIView {
    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = .white
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
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

    func bind(balanceViewModel: BalanceViewModelProtocol?) {
        balanceLabel.text = balanceViewModel?.amount
        priceLabel.text = balanceViewModel?.price
    }

    // MARK: - Private

    private func setupLayout() {
        let stack = UIFactory.default.createHorizontalStackView(spacing: 4)
        addSubview(stack)

        stack.addArrangedSubview(balanceLabel)
        stack.addArrangedSubview(priceLabel)

        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
