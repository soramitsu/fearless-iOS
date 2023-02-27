import Foundation
import UIKit

final class ExpandableSubtitleCell: UITableViewCell, SelectionItemViewProtocol {
    private enum Constants {
        static let cellHeight: CGFloat = 50.0
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 20.0, height: 20.0)
    }

    weak var delegate: SelectionItemViewDelegate?

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconExpandable(), for: .normal)
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h4Title
        return label
    }()

    let subtitle: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    var viewModel: SelectableSubtitleListViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

        setupLayout()

        infoButton.addTarget(
            self,
            action: #selector(handleInfoButtonTapped),
            for: .touchUpInside
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SelectableViewModelProtocol) {
        guard let viewModel = viewModel as? SelectableSubtitleListViewModel else {
            return
        }

        self.viewModel = viewModel
        subtitle.isHidden = !viewModel.isExpand
        titleLabel.text = viewModel.title
        subtitle.text = viewModel.subtitle

        let buttonImage = viewModel.isExpand ? R.image.iconExpandableInverted() : R.image.iconExpandable()
        infoButton.setImage(buttonImage, for: .normal)
    }

    // MARK: - Private actions

    @objc private func handleInfoButtonTapped() {
        guard let indexPath = indexPath else {
            return
        }
        delegate?.didTapAdditionalButton(at: indexPath)
    }

    // MARK: - Private methods

    private func setupLayout() {
        contentView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.cellHeight)
            make.edges.equalToSuperview()
        }

        let textVStackView = UIFactory.default.createVerticalStackView()
        contentView.addSubview(textVStackView)
        textVStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview()
        }

        textVStackView.addArrangedSubview(titleLabel)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textVStackView.addArrangedSubview(subtitle)
        subtitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        contentView.addSubview(infoButton)
        infoButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        infoButton.snp.makeConstraints { make in
            make.leading.equalTo(textVStackView.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(titleLabel.snp.centerY)
            make.width.equalTo(44)
        }
    }
}
