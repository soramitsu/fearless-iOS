import UIKit

protocol NodeSelectionTableCellDelegate: AnyObject {
    func didTapDeleteButton()
    func didTapInfoButton()
}

class NodeSelectionTableCell: UITableViewCell {
    weak var delegate: NodeSelectionTableCellDelegate?

    let mainStackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)
        stackView.alignment = .center
        return stackView
    }()

    let textInfoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)

    let selectedIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.listCheckmarkIcon()
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

    let nodeNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let nodeUrlLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconHorMore(), for: .normal)
        return button
    }()

    let deleteButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconDelete(), for: .normal)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none

        deleteButton.addTarget(self, action: #selector(deleteButtonClicked), for: .touchUpInside)
        infoButton.addTarget(self, action: #selector(infoButtonClicked), for: .touchUpInside)
    }

    private func setupLayout() {
        contentView.addSubview(mainStackView)

        mainStackView.addArrangedSubview(deleteButton)
        mainStackView.addArrangedSubview(selectedIconImageView)
        mainStackView.addArrangedSubview(textInfoStackView)
        textInfoStackView.addArrangedSubview(nodeNameLabel)
        textInfoStackView.addArrangedSubview(nodeUrlLabel)
        mainStackView.addArrangedSubview(infoButton)

        mainStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        deleteButton.snp.makeConstraints { make in
            make.size.equalTo(30)
        }

        selectedIconImageView.snp.makeConstraints { make in
            make.size.equalTo(30)
        }

        infoButton.snp.makeConstraints { make in
            make.size.equalTo(22)
        }
    }

    func bind(to viewModel: NodeSelectionTableCellViewModel, tableState: NodeSelectionTableState) {
        delegate = viewModel

        nodeNameLabel.text = viewModel.node.name
        nodeUrlLabel.text = viewModel.node.clearUrlString
        selectedIconImageView.isHidden = !viewModel.selected

        let deleteEnabled = (tableState == .editing && viewModel.editable && !viewModel.selected)
        deleteButton.alpha = deleteEnabled ? 1 : 0
        deleteButton.isHidden = viewModel.selected

        let textColor = viewModel.selectable ? R.color.colorWhite() : R.color.colorGray()

        nodeNameLabel.textColor = textColor
        nodeUrlLabel.textColor = textColor
    }

    @objc private func deleteButtonClicked() {
        delegate?.didTapDeleteButton()
    }

    @objc private func infoButtonClicked() {
        delegate?.didTapInfoButton()
    }
}
