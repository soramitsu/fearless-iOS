import Foundation
import IrohaCrypto
import RobinHood

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(password: String, strength: IRMnemonicStrength) -> BaseOperation<Void>
    func deriveAccountOperation(mnemonic: String, password: String) -> BaseOperation<Void>
}

extension AccountOperationFactoryProtocol {
    func newAccountOperation(password: String) -> BaseOperation<Void> {
        newAccountOperation(password: password, strength: .entropy128)
    }

    func newAccountOperation() -> BaseOperation<Void> {
        newAccountOperation(password: "", strength: .entropy128)
    }

    func deriveAccountOperation(mnemonic: String) -> BaseOperation<Void> {
        deriveAccountOperation(mnemonic: mnemonic, password: "")
    }
}
