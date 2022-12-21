import Foundation
import UIKit

final class SelectionTitleWithInfoButton: UITableViewCell, SelectionItemViewProtocol {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 20.0, height: 20.0)
    }

    weak var delegate: SelectionItemViewDelegate?

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h4Title
        return label
    }()

    var viewModel: SelectableTitleListViewModel?

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
        guard let viewModel = viewModel as? SelectableTitleListViewModel else {
            return
        }

        self.viewModel = viewModel
        titleLabel.text = viewModel.title
    }

    // MARK: - Private actions

    @objc private func handleInfoButtonTapped() {
        guard let indexPath = indexPath else {
            return
        }
        delegate?.didTapInfoButton(at: indexPath.row)
    }

    // MARK: - Private methods

    private func setupLayout() {
        let hStackView = UIFactory.default.createHorizontalStackView()
        contentView.addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview()
        }

        hStackView.addArrangedSubview(titleLabel)
        hStackView.addArrangedSubview(infoButton)
    }
}
