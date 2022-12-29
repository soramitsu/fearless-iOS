import Foundation
import UIKit
import SoraUI

protocol WalletsManagmentTableCellDelegate: AnyObject {
    func didTapOptionsCell(with indexPath: IndexPath?)
}

final class WalletsManagmentTableCell: UITableViewCell {
    private enum Constants {
        static let cellHeight: CGFloat = 72
        static let conentEdgeInstets = UIEdgeInsets(
            top: 8, left: 12, bottom: 8, right: 12
        )
        static let optionsButtonSize = CGSize(width: 44, height: 44)
    }

    private let backgroundTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = .clear
        view.highlightedStrokeColor = R.color.colorPink()!
        view.strokeWidth = 0.5
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private let walletNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()!
        return label
    }()

    private let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    private let dayChangeLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        return label
    }()

    private let optionsButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconHorMore(), for: .normal)
        return button
    }()

    weak var delegate: WalletsManagmentTableCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to viewModel: WalletsManagmentCellViewModel) {
        iconImageView.image = R.image.iconBirdGreen()
        walletNameLabel.text = viewModel.walletName
        fiatBalanceLabel.text = viewModel.fiatBalance
        dayChangeLabel.attributedText = viewModel.dayChange
        backgroundTriangularedView.set(highlighted: viewModel.isSelected, animated: false)
    }

    private func configure() {
        optionsButton.addTarget(self, action: #selector(optionsDidTap), for: .touchUpInside)
    }

    @objc private func optionsDidTap() {
        delegate?.didTapOptionsCell(with: indexPath)
    }

    private func setupLayout() {
        selectionStyle = .none
        backgroundColor = R.color.colorBlack()!

        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.conentEdgeInstets)
            make.height.equalTo(Constants.cellHeight)
        }

        backgroundTriangularedView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(UIConstants.normalAddressIconSize)
        }

        let vStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        vStackView.distribution = .fillProportionally
        backgroundTriangularedView.addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.defaultOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        vStackView.addArrangedSubview(walletNameLabel)
        vStackView.addArrangedSubview(fiatBalanceLabel)
        vStackView.addArrangedSubview(dayChangeLabel)

        backgroundTriangularedView.addSubview(optionsButton)
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.optionsButtonSize)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalTo(vStackView.snp.trailing).offset(UIConstants.defaultOffset)
        }
    }
}
