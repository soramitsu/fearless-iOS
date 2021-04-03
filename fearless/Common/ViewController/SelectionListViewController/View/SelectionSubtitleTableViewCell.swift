import UIKit

@IBDesignable
final class SelectionSubtitleTableViewCell: UITableViewCell, SelectionItemViewProtocol {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var checkmarkImageView: UIImageView!

    @IBInspectable
    var titleColor: UIColor = .black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var selectedTitleColor: UIColor = .black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var subtitleColor: UIColor = .black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var selectedSubtitleColor: UIColor = .black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var checkmarkIcon: UIImage? {
        didSet {
            updateSelectionState()
        }
    }

    private(set) var viewModel: SelectableSubtitleListViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel?.removeObserver(self)
    }

    func bind(viewModel: SelectableViewModelProtocol) {
        if let subtitleViewModel = viewModel as? SelectableSubtitleListViewModel {
            self.viewModel = subtitleViewModel

            titleLabel.text = subtitleViewModel.title
            subtitleLabel.text = subtitleViewModel.subtitle
            updateSelectionState()

            viewModel.addObserver(self)
        }
    }

    private func updateSelectionState() {
        guard let viewModel = viewModel else {
            return
        }

        if titleLabel != nil {
            titleLabel.textColor = viewModel.isSelected ? selectedTitleColor : titleColor
        }

        if subtitleLabel != nil {
            subtitleLabel.textColor = viewModel.isSelected ? selectedSubtitleColor : subtitleColor
        }

        if checkmarkImageView != nil {
            checkmarkImageView.image = viewModel.isSelected ? checkmarkIcon : nil
        }
    }
}

extension SelectionSubtitleTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
