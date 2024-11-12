import UIKit

final class BridgeListTableCell: UITableViewCell {
    private enum Constants {
        static let dexLogoImageSize: CGFloat = 24
    }

    private let triangularedBackgroundView: GradientBorderedTriangularedView = {
        let view = GradientBorderedTriangularedView()
        view.fillColor = UIColor(hex: "1C1A1B")!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = .clear
        view.highlightedStrokeColor = R.color.colorPink()!
        view.strokeWidth = 1
        view.shadowOpacity = 0
        view.gradientBorderColors = UIColor.walletBorderGradientColors
        return view
    }()

    let mainStackView = UIFactory.default.createVerticalStackView(spacing: 8)
    let routeStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
    let informationStackView = UIFactory.default.createHorizontalStackView(spacing: 8)

    let txTimeView: IconDetailsView = {
        let view = IconDetailsView()
        view.imageView.image = R.image.iconTransactionTime()
        view.detailsLabel.textColor = R.color.colorWhite50()
        view.detailsLabel.font = .p1Paragraph
        return view
    }()

    let txComissionView: IconDetailsView = {
        let view = IconDetailsView()
        view.imageView.image = R.image.iconTransactionComission()
        view.detailsLabel.textColor = R.color.colorWhite50()
        view.detailsLabel.font = .p1Paragraph
        return view
    }()

    let routeTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let routeDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    let routeLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let detailsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconArrowRightNormal()
        return imageView
    }()

    let dexLogoImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        setupConstraints()
        backgroundColor = R.color.colorBlack19()
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dexLogoImageView.image = nil
    }

    func bind(viewModel: BridgeListTableCellModel?) {
        if let imageViewModel = viewModel?.dexIcon {
            imageViewModel.loadImage(on: dexLogoImageView, targetSize: CGSize(width: Constants.dexLogoImageSize, height: Constants.dexLogoImageSize), animated: true)
        }

        routeTitleLabel.text = viewModel?.routeTitle
        routeDescriptionLabel.attributedText = viewModel?.routeDescription
        amountLabel.text = viewModel?.amount
        routeLabel.text = viewModel?.route
        txTimeView.detailsLabel.text = viewModel?.txTime
        txComissionView.detailsLabel.text = viewModel?.txCommission

        dexLogoImageView.isHidden = viewModel?.dexIcon == nil
        txComissionView.isHidden = viewModel?.txCommission == nil
        txTimeView.isHidden = viewModel?.txTime == nil
        routeLabel.isHidden = viewModel?.route == nil
        amountLabel.isHidden = viewModel?.amount == nil
        routeDescriptionLabel.isHidden = viewModel?.routeDescription == nil
        routeTitleLabel.isHidden = viewModel?.routeTitle == nil

        triangularedBackgroundView.gradientBorder.isHidden = viewModel?.isSelected != true
    }

    private func setupSubviews() {
        contentView.addSubview(triangularedBackgroundView)
        triangularedBackgroundView.addSubview(mainStackView)
        triangularedBackgroundView.addSubview(detailsImageView)

        mainStackView.addArrangedSubview(routeStackView)
        mainStackView.addArrangedSubview(amountLabel)
        mainStackView.addArrangedSubview(informationStackView)

        routeStackView.addArrangedSubview(dexLogoImageView)
        routeStackView.addArrangedSubview(routeTitleLabel)
        routeStackView.addArrangedSubview(routeDescriptionLabel)

        informationStackView.addArrangedSubview(txTimeView)
        informationStackView.addArrangedSubview(txComissionView)
        informationStackView.addArrangedSubview(routeLabel)
    }

    private func setupConstraints() {
        triangularedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        mainStackView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(12)
        }

        detailsImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
            make.leading.equalTo(mainStackView.snp.trailing).offset(8)
        }

        dexLogoImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.dexLogoImageSize)
        }
    }
}
