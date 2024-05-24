import UIKit
import SSFModels

protocol AssetNetworksTableCellDelegate: AnyObject {
    func resolveIssue(for chainAsset: ChainAsset)
}

final class AssetNetworksTableCell: UITableViewCell {
    weak var delegate: AssetNetworksTableCellDelegate?

    let networkIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

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

    let warningButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconWarning(), for: .normal)
        return button
    }()

    private var viewModel: AssetNetworksTableCellModel?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        drawSubviews()
        setupConstraints()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
        bindActions()
        drawSubviews()
        setupConstraints()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
    }

    func bind(viewModel: AssetNetworksTableCellModel) {
        self.viewModel = viewModel
        viewModel.iconViewModel?.cancel(on: networkIconImageView)
        let imageSize = networkIconImageView.frame.size
        viewModel.iconViewModel?.loadImage(on: networkIconImageView, targetSize: imageSize, animated: true)
        chainNameLabel.text = viewModel.chainNameLabelText
        cryptoBalanceLabel.text = viewModel.cryptoBalanceLabelText
        fiatBalanceLabel.text = viewModel.fiatBalanceLabelText

        set(hasIssue: viewModel.hasIssues)
    }

    private func set(hasIssue: Bool) {
        cryptoBalanceLabel.isHidden = hasIssue
        fiatBalanceLabel.isHidden = hasIssue
        warningButton.isHidden = !hasIssue
    }

    private func bindActions() {
        warningButton.addAction { [weak self] in
            guard let chainAsset = self?.viewModel?.chainAsset else {
                return
            }
            self?.delegate?.resolveIssue(for: chainAsset)
        }
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
        balanceStackView.addArrangedSubview(warningButton)
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
