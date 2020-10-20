import Foundation

protocol EventVisitorProtocol: class {
    func processSelectedAccountChanged(event: SelectedAccountChanged)
    func processSelectedConnectionChanged(event: SelectedConnectionChanged)
    func processBalanceChanged(event: WalletBalanceChanged)
    func processStakingChanged(event: WalletStakingInfoChanged)
}

extension EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {}
    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {}
    func processBalanceChanged(event: WalletBalanceChanged) {}
    func processStakingChanged(event: WalletStakingInfoChanged) {}
}
