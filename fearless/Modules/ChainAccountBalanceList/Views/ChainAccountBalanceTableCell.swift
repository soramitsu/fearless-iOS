import UIKit
import Kingfisher

class ChainAccountBalanceTableCell: UITableViewCell {
    private var assetIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    private var chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    private var balanceView: HorizontalKeyValueView = {
        let view = HorizontalKeyValueView()
        let style = HorizontalKeyValueView.Style()
        view.apply(style: style)
        return view
    }()

    private var priceView: HorizontalKeyValueView = {
        let view = HorizontalKeyValueView()
        let style = HorizontalKeyValueView.Style(
            keyLabelFont: .p2Paragraph,
            valueLabelFont: .p2Paragraph,
            keyLabelTextColor: R.color.colorAlmostWhite(),
            valueLabelTextColor: R.color.colorAlmostWhite()
        )
        view.apply(style: style)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    func setupLayout() {
        contentView.addSubview(assetIconImageView)

        assetIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(CrowdloanViewConstants.iconSize)
            make.top.equalToSuperview().inset(11)
        }

        contentView.addSubview(contentStackView)

        contentStackView.snp.makeConstraints { make in
            make.leading.equalTo(assetIconImageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(6.0)
            make.bottom.equalToSuperview().inset(12.0)
        }

        contentStackView.addArrangedSubview(chainNameLabel)
        contentStackView.addArrangedSubview(balanceView)
        contentStackView.addArrangedSubview(priceView)
    }

    func bind(to viewModel: ChainAccountBalanceCellViewModel) {
        chainNameLabel.text = viewModel.chainName
        balanceView.keyLabel.text = viewModel.assetInfo?.symbol
        balanceView.valueLabel.text = viewModel.balanceString
        priceView.keyLabel.attributedText = viewModel.priceAttributedString
        priceView.valueLabel.text = viewModel.totalAmountString

        assetIconImageView.kf.setImage(with: viewModel.assetInfo?.icon)
    }
}
