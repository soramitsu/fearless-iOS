import Foundation
import Rswift

protocol SelectionItemViewProtocol: AnyObject {
    func bind(viewModel: SelectableViewModelProtocol)
}
