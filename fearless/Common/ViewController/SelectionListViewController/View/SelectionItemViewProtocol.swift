import Foundation
import Rswift

protocol SelectionItemViewDelegate: AnyObject {
    func didTapInfoButton(at index: Int)
}

extension SelectionItemViewDelegate {
    func didTapInfoButton(at _: Int) {}
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
