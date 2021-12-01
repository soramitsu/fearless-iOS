import UIKit
import Kingfisher

class ChainAccountBalanceTableCell: UITableViewCell {
    enum LayoutConstants {
        static let cellHeight: CGFloat = 80
        static let assetImageTopOffset: CGFloat = 11
        static let stackViewVerticalOffset: CGFloat = 6
    }

    private var backgroundTriangularedView = TriangularedBlurView()

    private var assetIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        return view
    }()

    private var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 0
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
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

        selectionStyle = .none
    }

    func setupLayout() {
        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview()
            make.height.equalTo(LayoutConstants.cellHeight)
        }

        backgroundTriangularedView.addSubview(assetIconImageView)

        assetIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(CrowdloanViewConstants.iconSize)
            make.centerY.equalToSuperview()
        }

        backgroundTriangularedView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.width.equalTo(UIConstants.separatorHeight)
            make.leading.equalTo(assetIconImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
        }

        backgroundTriangularedView.addSubview(contentStackView)

        contentStackView.snp.makeConstraints { make in
            make.leading.equalTo(separatorView.snp.trailing).offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(separatorView.snp.top)
            make.bottom.equalTo(separatorView.snp.bottom)
        }

        contentStackView.addArrangedSubview(chainNameLabel)
        chainNameLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentStackView.addArrangedSubview(balanceView)
        balanceView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentStackView.addArrangedSubview(priceView)
        priceView.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    func bind(to viewModel: ChainAccountBalanceCellViewModel) {
        viewModel.imageViewModel?.cancel(on: assetIconImageView)

        chainNameLabel.text = viewModel.chainName
        balanceView.keyLabel.text = viewModel.assetInfo?.symbol
        balanceView.valueLabel.text = viewModel.balanceString
        priceView.keyLabel.attributedText = viewModel.priceAttributedString
        priceView.valueLabel.text = viewModel.totalAmountString

        let iconSize = assetIconImageView.frame.size.height
        viewModel.imageViewModel?.loadImage(
            on: assetIconImageView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
    }
}
