import Foundation

protocol ModalPickerCellProtocol {
    associatedtype Model

    var checkmarked: Bool { get set }

    func bind(model: Model)
}
