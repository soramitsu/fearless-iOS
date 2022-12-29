import UIKit

protocol StakingPoolListTableCellDelegate {
    func didTapInfoButton()
    func didTapCell()
}

class StakingPoolListTableCell: UITableViewCell {
    private var delegate: StakingPoolListTableCellDelegate?

    private enum LayoutConstants {
        static let selectionImageViewSize = CGSize(width: 20, height: 20)
    }

    let selectionIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    let poolNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let membersCountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let stakedAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconInfoGrayFilled(), for: .normal)
        return button
    }()

    private let labelsStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(
            spacing: UIConstants.minimalOffset
        )
        stackView.isUserInteractionEnabled = false
        return stackView
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(cellClicked))
        gesture.cancelsTouchesInView = false
        return gesture
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

    func bind(to viewModel: StakingPoolListTableCellModel) {
        delegate = viewModel

        poolNameLabel.text = viewModel.poolName
        membersCountLabel.text = viewModel.membersCountString
        stakedAmountLabel.attributedText = viewModel.stakedAmountAttributedString

        let selectionImage = viewModel.isSelected ? R.image.iconListSelectionOn() : R.image.iconListSelectionOff()
        selectionIconImageView.image = selectionImage
    }

    @objc private func infoButtonClicked() {
        delegate?.didTapInfoButton()
    }

    @objc private func cellClicked() {
        delegate?.didTapCell()
    }

    private func setupLayout() {
        addSubview(selectionIconImageView)
        addSubview(labelsStackView)
        addSubview(infoButton)

        labelsStackView.addArrangedSubview(poolNameLabel)
        labelsStackView.addArrangedSubview(membersCountLabel)
        labelsStackView.addArrangedSubview(stakedAmountLabel)

        selectionIconImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.selectionImageViewSize)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        infoButton.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.standardButtonSize)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        labelsStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(selectionIconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalTo(infoButton.snp.leading).inset(UIConstants.bigOffset)
        }
    }

    private func configure() {
        contentView.addGestureRecognizer(tapGesture)
        backgroundColor = R.color.colorAlmostBlack()
        selectionStyle = .none

        infoButton.addTarget(
            self,
            action: #selector(infoButtonClicked),
            for: .touchUpInside
        )
    }
}
