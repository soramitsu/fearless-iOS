import Foundation

protocol EventVisitorProtocol: class {
    func processSelectedAccountChanged(event: SelectedAccountChanged)
}

extension EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {}
}
