import Foundation

protocol AddCustomNodeViewModelFactoryProtocol {
    func buildViewState(with name: String?, address: String?) -> AddCustomNodeViewState
}

class AddCustomNodeViewModelFactory: AddCustomNodeViewModelFactoryProtocol {
    
    func buildViewState(with name: String?, address: String?) -> AddCustomNodeViewState {
        if name?.count == 0 {
            return .needsName
        }
        
        if address?.count == 0 {
            return .needsUrl
        }
        
        return .done
    }
}
