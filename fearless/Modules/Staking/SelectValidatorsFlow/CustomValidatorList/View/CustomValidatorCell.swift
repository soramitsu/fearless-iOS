import UIKit
import FearlessUtils

protocol CustomValidatorCellDelegate: AnyObject {
    func didTapInfoButton(in cell: CustomValidatorCell)
}

class CustomValidatorCell: UITableViewCell {
    weak var delegate: CustomValidatorCellDelegate?

    let iconView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconListSelectionOn()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let detailsAuxLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        return button
    }()

    let statusStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 2.0
        stackView.alignment = .center
        stackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stackView
    }()

    let detailsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
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
        backgroundColor = R.color.colorBlack19()
        infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.size.equalTo(14)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(statusStackView)
        statusStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.greaterThanOrEqualTo(infoButton.snp.leading).offset(-16)
        }

        detailsStackView.addArrangedSubview(titleLabel)
        detailsStackView.addArrangedSubview(detailsLabel)
        detailsStackView.addArrangedSubview(detailsAuxLabel)

        contentView.addSubview(detailsStackView)
        detailsStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalTo(infoButton.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }

    func bind(viewModel: CustomValidatorCellViewModel) {
        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        clearStatusView()
        setupStatus(for: viewModel.shouldShowWarning, shouldShowError: viewModel.shouldShowError)

        detailsLabel.attributedText = viewModel.details

        if let auxDetailsText = viewModel.auxDetails {
            detailsAuxLabel.text = auxDetailsText
            detailsAuxLabel.isHidden = false
        } else {
            detailsAuxLabel.isHidden = true
        }

        iconView.image = viewModel.isSelected ? R.image.iconListSelectionOn() : R.image.iconListSelectionOff()
    }

    func bind(viewModel: ValidatorSearchCellViewModel) {
        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        clearStatusView()
        setupStatus(for: viewModel.shouldShowWarning, shouldShowError: viewModel.shouldShowError)

        detailsLabel.attributedText = viewModel.details
        detailsAuxLabel.text = viewModel.detailsAux

        iconView.image = viewModel.isSelected ? R.image.iconListSelectionOn() : R.image.iconListSelectionOff()
    }

    func bind(viewModel: RecommendedValidatorViewModelProtocol) {
        iconView.image = R.image.iconListSelectionOn()

        titleLabel.text = viewModel.title
        detailsLabel.attributedText = viewModel.details
        detailsAuxLabel.text = viewModel.detailsAux

        selectionStyle = .none
    }

    func bind(viewModel: SelectedValidatorCellViewModel) {
        iconView.image = R.image.iconListSelectionOn()

        titleLabel.text = viewModel.name
        detailsLabel.attributedText = viewModel.details
        detailsAuxLabel.text = viewModel.detailsAux

        selectionStyle = .none
    }

    private func clearStatusView() {
        let arrangedSubviews = statusStackView.arrangedSubviews

        arrangedSubviews.forEach {
            statusStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func setupStatus(for shouldShowWarning: Bool, shouldShowError: Bool) {
        if shouldShowWarning {
            statusStackView.addArrangedSubview(UIImageView(image: R.image.iconWarning()))
        }

        if shouldShowError {
            statusStackView.addArrangedSubview(UIImageView(image: R.image.iconErrorFilled()))
        }
    }
}
