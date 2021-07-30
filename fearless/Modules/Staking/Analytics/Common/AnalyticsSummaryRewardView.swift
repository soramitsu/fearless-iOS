import UIKit

final class AnalyticsSummaryRewardView: UIView {
    let indicatorView = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
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

    private func setupLayout() {
        let stack: UIView = .hStack(
            alignment: .center,
            spacing: 8,
            [
                indicatorView,
                titleLabel,
                UIView(),
                .vStack(alignment: .trailing, [tokenAmountLabel, usdAmountLabel])
            ]
        )

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(7.5)
        }

        indicatorView.snp.makeConstraints { $0.size.equalTo(12) }
    }

    func configure(with viewModel: AnalyticsSummaryRewardViewModel) {
        titleLabel.text = viewModel.title
        tokenAmountLabel.text = viewModel.tokenAmount
        usdAmountLabel.text = viewModel.usdAmount
        indicatorView.backgroundColor = viewModel.indicatorColor
    }
}
