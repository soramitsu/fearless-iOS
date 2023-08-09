import Foundation
import UIKit

final class BackupSelectWalletTableCell: UITableViewCell {
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
        view.strokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconBirdGreen()
        return imageView
    }()

    private let walletNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()!
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(name: String?) {
        walletNameLabel.text = name
    }

    private func setupLayout() {
        selectionStyle = .none
        backgroundColor = R.color.colorBlack19()

        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.conentEdgeInstets)
            make.height.equalTo(Constants.cellHeight)
        }

        iconImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        backgroundTriangularedView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(UIConstants.normalAddressIconSize)
        }

        contentView.addSubview(walletNameLabel)
        walletNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }
}
