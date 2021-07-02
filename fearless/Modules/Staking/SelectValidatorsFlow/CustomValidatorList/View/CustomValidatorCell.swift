import UIKit
import FearlessUtils

protocol CustomValidatorCellDelegate: AnyObject {
    func didTapInfoButton(in cell: CustomValidatorCell)
}

class CustomValidatorCell: UITableViewCell {
    weak var delegate: CustomValidatorCellDelegate?

    let selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

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
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .right
        label.textColor = R.color.colorWhite()
        return label
    }()

    let detailsAuxLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .right
        label.textColor = R.color.colorGray()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        return button
    }()

    let detailsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stackView
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
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!

        infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
    }

    private func setupLayout() {
        contentView.addSubview(selectionImageView)
        selectionImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(selectionImageView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.bottom.equalToSuperview().inset(16)
        }

        detailsStackView.addArrangedSubview(detailsLabel)
        detailsStackView.addArrangedSubview(detailsAuxLabel)

        contentView.addSubview(detailsStackView)
        detailsStackView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalTo(infoButton.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }

    func bind(viewModel: CustomValidatorCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        detailsLabel.text = viewModel.details

        if let auxDetailsText = viewModel.auxDetails {
            detailsAuxLabel.text = auxDetailsText
            detailsAuxLabel.isHidden = false
        } else {
            detailsAuxLabel.isHidden = true
        }

        selectionImageView.image = viewModel.isSelected ? R.image.listCheckmarkIcon() : nil
    }

    func bind(viewModel: ValidatorSearchCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        detailsLabel.text = viewModel.details

        detailsAuxLabel.isHidden = true

        selectionImageView.image = viewModel.isSelected ? R.image.listCheckmarkIcon() : nil
    }
}
