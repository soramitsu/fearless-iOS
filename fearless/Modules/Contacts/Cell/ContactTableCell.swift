import UIKit

protocol ContactTableCellDelegate: AnyObject {
    func didTapAddButton()
    func didTapAccountScore()
}

class ContactTableCell: UITableViewCell {
    enum LayoutConstants {
        static let contactImageViewSize = CGSize(width: 32, height: 32)
        static let addContactButtonSize = CGSize(width: 41, height: 32)
    }

    private weak var delegate: ContactTableCellDelegate?

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
        label.textColor = R.color.colorWhite()
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

    private let hStackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView()
        stackView.distribution = .fill
        return stackView
    }()

    let addButton: TriangularedButton = {
        let button = TriangularedButton()
        button.isHidden = false
        button.imageWithTitleView?.iconImage = R.image.iconAddContact()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.highlightedFillColor = R.color.colorBlack1()!
        button.triangularedView?.strokeColor = .clear
        button.triangularedView?.highlightedStrokeColor = .clear

        button.contentOpacityWhenDisabled = 1
        return button
    }()

    let accountScoreView: AccountScoreView = {
        let view = AccountScoreView()
        view.isHidden = true
        return view
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
        accountScoreView.bind(viewModel: viewModel.accountScoreViewModel)
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

        accountScoreView.starView.didFinishTouchingCosmos = { [weak self] _ in
            self?.delegate?.didTapAccountScore()
        }
    }

    @objc private func addButtonClicked() {
        delegate?.didTapAddButton()
    }

    private func setupLayout() {
        contentView.addSubview(contactImageView)
        contentView.addSubview(addButton)
        contentView.addSubview(labelsStackView)

        labelsStackView.addArrangedSubview(hStackView)
        labelsStackView.addArrangedSubview(addressLabel)

        hStackView.addArrangedSubview(nameLabel)
        hStackView.addArrangedSubview(accountScoreView)

        accountScoreView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        hStackView.snp.makeConstraints { make in
            make.trailing.leading.equalToSuperview()
        }

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
