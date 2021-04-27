import UIKit

final class StakingBalanceWidgetView: UIView {
    let backgroundView: UIView = TriangularedBlurView()

    let balanceTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(balanceTitleLabel)
        balanceTitleLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(balanceTitleLabel.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8)
        }
    }
}

extension StakingBalanceWidgetView {
    func bind(viewModel: StakingBalanceWidgetViewModel) {
        balanceTitleLabel.text = viewModel.title

        let itemViews = viewModel.itemViewModels.map { viewModel -> UIView in
            let itemView = StakingBalanceWidgetItemView()
            itemView.titleLabel.text = viewModel.title
            itemView.tokenAmountLabel.text = viewModel.tokenAmountText
            itemView.usdAmountLabel.text = viewModel.usdAmountText
            return itemView
        }

        let separators = (0 ..< itemViews.count).map { _ -> UIView in
            UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))
        }

        let itemViewsWithSeparators = zip(itemViews, separators).map { [$0, $1] }
            .flatMap { $0 }
            .dropLast()

        let stackView = UIStackView(arrangedSubviews: Array(itemViewsWithSeparators))
        stackView.axis = .vertical

        separators.dropLast().forEach { separator in
            separator.snp.makeConstraints {
                $0.height.equalTo(0.75 / UIScreen.main.scale)
                $0.width.equalToSuperview()
            }
        }

        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private final class StakingBalanceWidgetItemView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
        return label
    }()

    let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.5)
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

    func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(tokenAmountLabel)
        tokenAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(7.5)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing)
        }

        addSubview(usdAmountLabel)
        usdAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalTo(tokenAmountLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(7.5)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing)
        }
    }
}
