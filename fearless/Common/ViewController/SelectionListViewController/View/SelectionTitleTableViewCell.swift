import UIKit

@IBDesignable
final class SelectionTitleTableViewCell: UITableViewCell, SelectionItemViewProtocol {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var checkmarkImageView: UIImageView!

    @IBInspectable
    var titleColor: UIColor = UIColor.black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var selectedTitleColor: UIColor = UIColor.black {
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

    private(set) var viewModel: SelectableTitleListViewModel?

    override func prepareForReuse() {
        viewModel?.removeObserver(self)
    }

    func bind(viewModel: SelectableViewModelProtocol) {
        if let titleViewModel = viewModel as? SelectableTitleListViewModel {
            self.viewModel = titleViewModel

            titleLabel.text = titleViewModel.title
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

        if checkmarkImageView != nil {
            checkmarkImageView.image = viewModel.isSelected ? checkmarkIcon : nil
        }
    }
}

extension SelectionTitleTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
