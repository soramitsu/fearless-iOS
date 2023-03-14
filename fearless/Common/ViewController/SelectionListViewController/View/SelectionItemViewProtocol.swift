import Foundation
import UIKit

protocol SelectionItemViewDelegate: AnyObject {
    func didTapAdditionalButton(at indexPath: IndexPath)
}

extension SelectionItemViewDelegate {
    func didTapAdditionalButton(at _: IndexPath) {}
}

protocol SelectionItemViewProtocol: AnyObject {
    var delegate: SelectionItemViewDelegate? { get set }
    func bind(viewModel: SelectableViewModelProtocol)
}

extension SelectionItemViewProtocol {
    var delegate: SelectionItemViewDelegate? {
        get { nil }
        set {}
    }
}
