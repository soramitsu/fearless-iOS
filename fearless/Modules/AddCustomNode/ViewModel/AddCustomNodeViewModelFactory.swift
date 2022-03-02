import Foundation

protocol AddCustomNodeViewModelFactoryProtocol {
    func buildViewState(with name: String?, address: String?) -> AddCustomNodeViewState
}

class AddCustomNodeViewModelFactory: AddCustomNodeViewModelFactoryProtocol {
    func buildViewState(with name: String?, address: String?) -> AddCustomNodeViewState {
        if name?.isEmpty == true {
            return .needsName
        }

        if address?.isEmpty == true {
            return .needsUrl
        }

        return .done
    }
}
