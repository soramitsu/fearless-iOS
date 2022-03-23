import UIKit
import Kingfisher
import simd

class ChainAccountBalanceTableCell: UITableViewCell {
    enum LayoutConstants {
        static let cellHeight: CGFloat = 80
        static let assetImageTopOffset: CGFloat = 11
        static let stackViewVerticalOffset: CGFloat = 6
        static let iconSize: CGFloat = 48
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
        stackView.alignment = .leading
        return stackView
    }()

    private var chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    let chainInfoView = UIView()

    let chainOptionsView: ScrollableContainerView = {
        let containerView = ScrollableContainerView()
        containerView.stackView.axis = .horizontal
        containerView.stackView.distribution = .fillProportionally
        containerView.stackView.alignment = .fill
        containerView.stackView.spacing = UIConstants.defaultOffset
        return containerView
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

    override func prepareForReuse() {
        super.prepareForReuse()

        assetIconImageView.kf.cancelDownloadTask()

        chainOptionsView.stackView.arrangedSubviews.forEach { subview in
            chainOptionsView.stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
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
            make.size.equalTo(LayoutConstants.iconSize)
            make.centerY.equalToSuperview()
        }

        backgroundTriangularedView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.width.equalTo(UIConstants.separatorHeight)
            make.leading.equalTo(assetIconImageView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        backgroundTriangularedView.addSubview(contentStackView)

        contentStackView.snp.makeConstraints { make in
            make.leading.equalTo(separatorView.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(separatorView.snp.top)
            make.bottom.equalTo(separatorView.snp.bottom)
        }

        contentStackView.addArrangedSubview(chainInfoView)
        chainNameLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentStackView.addArrangedSubview(balanceView)
        balanceView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        balanceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        contentStackView.addArrangedSubview(priceView)
        priceView.setContentHuggingPriority(.defaultLow, for: .vertical)
        priceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        chainInfoView.addSubview(chainNameLabel)
        chainNameLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        chainInfoView.addSubview(chainOptionsView)
        chainOptionsView.snp.makeConstraints { make in
            make.trailing.greaterThanOrEqualToSuperview()
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(chainNameLabel.snp.trailing).offset(UIConstants.defaultOffset)
        }

        chainOptionsView.stackView.snp.makeConstraints { make in
            make.height.equalToSuperview()
        }

        chainNameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    func bind(to viewModel: ChainAccountBalanceCellViewModel) {
        viewModel.imageViewModel?.cancel(on: assetIconImageView)

        chainNameLabel.text = viewModel.assetName?.uppercased()
        balanceView.keyLabel.text = viewModel.assetInfo?.symbol.uppercased()
        balanceView.valueLabel.text = viewModel.balanceString
        priceView.keyLabel.attributedText = viewModel.priceAttributedString
        priceView.valueLabel.text = viewModel.totalAmountString

        viewModel.imageViewModel?.loadBalanceListIcon(
            on: assetIconImageView,
            animated: false
        )

        if let options = viewModel.options {
            options.forEach { option in
                let view = ChainOptionsView()
                view.bind(to: option)

                chainOptionsView.stackView.addArrangedSubview(view)
            }
        }

        setDeactivated(!viewModel.chain.isSupported)
    }
}

extension ChainAccountBalanceTableCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [assetIconImageView, chainNameLabel, balanceView, priceView]
    }
}
