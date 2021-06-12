import UIKit
import FearlessUtils

final class CustomValidatorCell: UITableViewCell {
    let selectionImageView = UIImageView()

    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = R.color.colorWhite()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(
            top: 8,
            left: UIConstants.horizontalInset,
            bottom: 8,
            right: UIConstants.horizontalInset
        )
        stackView.axis = .horizontal
        stackView.spacing = 12
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        stackView.addArrangedSubview(selectionImageView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(detailsLabel)
        stackView.addArrangedSubview(infoButton)

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }

        selectionImageView.snp.makeConstraints { $0.size.equalTo(24) }
        iconView.snp.makeConstraints { $0.size.equalTo(24) }
    }

    func bind(viewModel: CustomValidatorCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.apyPercentage

        selectionImageView.image = viewModel.isSelected ? R.image.listCheckmarkIcon() : nil
    }
}
