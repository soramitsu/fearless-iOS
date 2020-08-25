import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?) {}

    func showAddAccount(from view: AccountManagementViewProtocol?) {}
}
