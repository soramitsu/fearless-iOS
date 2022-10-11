import UIKit

protocol ContactTableCellDelegate {
    func didTapAddButton()
}

class ContactTableCell: UITableViewCell {
    enum LayoutConstants {
        static let contactImageViewSize = CGSize(width: 32, height: 32)
        static let addContactButtonSize = CGSize(width: 73, height: 32)
    }

    private var delegate: ContactTableCellDelegate?

    private let contactImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.image = R.image.iconBirdGreen()
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = UIColor.white
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let labelsStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(
            spacing: UIConstants.minimalOffset
        )
        stackView.isUserInteractionEnabled = false
        return stackView
    }()

    let addButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        button.isHidden = false
        button.isUserInteractionEnabled = true
        button.imageWithTitleView?.title = "ADD"
        button.imageWithTitleView?.titleFont = .capsTitle
        button.imageWithTitleView?.iconImage = R.image.iconAddFilled()
        return button
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

    func bind(to viewModel: ContactTableCellModel) {
        delegate = viewModel
        switch viewModel.contactType {
        case let .saved(contact):
            nameLabel.text = contact.name
            addressLabel.text = contact.address
            addButton.isHidden = true
        case let .unsaved(address):
            nameLabel.text = "Undefined"
            addressLabel.text = address
            addButton.isHidden = false
        }
    }

    @objc private func addButtonClicked() {
        delegate?.didTapAddButton()
    }

    private func setupLayout() {
        contentView.addSubview(contactImageView)
        contentView.addSubview(addButton)
        contentView.addSubview(labelsStackView)

        labelsStackView.addArrangedSubview(nameLabel)
        labelsStackView.addArrangedSubview(addressLabel)

        contactImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.contactImageViewSize)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        addButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.addContactButtonSize)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        labelsStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(contactImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalTo(addButton.snp.leading).offset(-UIConstants.bigOffset)
        }
    }

    private func configure() {
        backgroundColor = R.color.colorBlack19()
        selectionStyle = .none

        addButton.addTarget(
            self,
            action: #selector(addButtonClicked),
            for: .touchUpInside
        )
    }
}
