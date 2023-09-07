import Foundation
import UIKit

final class WalletConnectActiveSessionsTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
        static let arrowSize = CGSize(width: 6, height: 12)
    }

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Digits
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let hostLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        separatorInset = .zero
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletConnectActiveSessionsViewModel) {
        nameLabel.text = viewModel.name
        hostLabel.text = viewModel.host
        viewModel.icon?.loadImage(
            on: iconImageView,
            placholder: R.image.iconOpenWeb(),
            targetSize: Constants.iconSize,
            animated: true
        )
    }

    // MARK: - Private methods

    private func setupLayout() {
        let generalStack = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)
        generalStack.distribution = .fillProportionally
        generalStack.alignment = .center
        contentView.addSubview(generalStack)
        generalStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        let textStack = UIFactory.default.createVerticalStackView()
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(hostLabel)

        generalStack.addArrangedSubview(iconImageView)
        generalStack.addArrangedSubview(textStack)
        generalStack.addArrangedSubview(arrowImageView)

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.equalTo(12)
        }
    }
}
