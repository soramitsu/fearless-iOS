import Foundation

protocol EventVisitorProtocol: class {
    func processSelectedAccountChanged(event: SelectedAccountChanged)
    func processSelectedConnectionChanged(event: SelectedConnectionChanged)
}

extension EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {}
    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {}
}
