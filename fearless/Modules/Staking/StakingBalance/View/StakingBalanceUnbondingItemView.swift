import UIKit

final class StakingBalanceUnbondingItemView: UIView {
    private enum Constants {
        static let verticalInset: CGFloat = 11
        static let iconSize: CGFloat = 32
    }

    private let transactionTypeView: UIView = {
        UIImageView(image: R.image.iconStakingTransactionType())
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let daysLeftLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
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
        label.textColor = R.color.colorLightGray()
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
        addSubview(transactionTypeView)
        transactionTypeView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.equalTo(Constants.iconSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2)
            make.top.equalToSuperview().inset(Constants.verticalInset)
        }

        addSubview(daysLeftLabel)
        daysLeftLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
        }

        addSubview(tokenAmountLabel)
        tokenAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset / 2)
        }

        addSubview(usdAmountLabel)
        usdAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(tokenAmountLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
        }
    }
}

extension StakingBalanceUnbondingItemView {
    func bind(model: UnbondingItemViewModel) {
        titleLabel.text = model.addressOrName
        daysLeftLabel.attributedText = model.daysLeftText
        tokenAmountLabel.text = model.tokenAmountText
        usdAmountLabel.text = model.usdAmountText
    }
}
