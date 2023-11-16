import UIKit

final class AssetNetworksTableCell: UITableViewCell {
    let networkIconImageView = UIImageView()

    let triangularedBackgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.backgroundColor = R.color.colorWhite4()
        view.cornerCut = [.bottomRight, .topLeft]
        return view
    }()

    let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite4()
        return view
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.numberOfLines = 2
        label.textColor = .white
        return label
    }()

    let balanceStackView = UIFactory.default.createVerticalStackView(spacing: 4)

    let cryptoBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()

    let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .right
        label.textColor = R.color.colorWhite50()
        return label
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        drawSubviews()
        setupConstraints()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
        drawSubviews()
        setupConstraints()
    }

    func bind(viewModel: AssetNetworksTableCellModel) {
        viewModel.iconViewModel?.cancel(on: networkIconImageView)
        let imageSize = networkIconImageView.frame.size
        viewModel.iconViewModel?.loadImage(on: networkIconImageView, targetSize: imageSize, animated: true)
        chainNameLabel.text = viewModel.chainNameLabelText
        cryptoBalanceLabel.text = viewModel.cryptoBalanceLabelText
        fiatBalanceLabel.text = viewModel.fiatBalanceLabelText
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }

    private func drawSubviews() {
        contentView.addSubview(triangularedBackgroundView)
        triangularedBackgroundView.addSubview(networkIconImageView)
        triangularedBackgroundView.addSubview(separatorView)
        triangularedBackgroundView.addSubview(chainNameLabel)
        triangularedBackgroundView.addSubview(balanceStackView)

        balanceStackView.addArrangedSubview(cryptoBalanceLabel)
        balanceStackView.addArrangedSubview(fiatBalanceLabel)
    }

    private func setupConstraints() {
        triangularedBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(4)
        }

        networkIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.bottom.equalToSuperview().inset(16)
            make.size.equalTo(48)
        }

        separatorView.snp.makeConstraints { make in
            make.leading.equalTo(networkIconImageView.snp.trailing).offset(8)
            make.top.bottom.equalToSuperview().inset(8)
            make.width.equalTo(1)
        }

        chainNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(separatorView.snp.trailing).offset(8)
            make.top.bottom.equalToSuperview().inset(8)
        }

        balanceStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.equalTo(chainNameLabel.snp.trailing).offset(8)
        }

        cryptoBalanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cryptoBalanceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
