import UIKit

class NodeSelectionTableCell: UITableViewCell {
    let selectedIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.listCheckmarkIcon()
        imageView.tintColor = .white
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
        button.setImage(R.image.iconInfo(), for: .normal)
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
    }

    private func setupLayout() {
        contentView.addSubview(selectedIconImageView)
        contentView.addSubview(nodeNameLabel)
        contentView.addSubview(nodeUrlLabel)
        contentView.addSubview(infoButton)

        selectedIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(30)
        }

        nodeNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(selectedIconImageView.snp.trailing).offset(UIConstants.defaultOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
        }

        nodeUrlLabel.snp.makeConstraints { make in
            make.leading.equalTo(nodeNameLabel.snp.leading)
            make.top.equalTo(nodeNameLabel.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.leading.equalTo(nodeUrlLabel.snp.trailing).offset(UIConstants.defaultOffset)
            make.size.equalTo(22)
        }
    }

    func bind(to viewModel: NodeSelectionTableCellViewModel) {
        nodeNameLabel.text = viewModel.node.name
        nodeUrlLabel.text = viewModel.node.url.absoluteString
        selectedIconImageView.isHidden = !viewModel.selected
    }
}
