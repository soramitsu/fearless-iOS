import Foundation
import CommonWallet

final class TransferChangeHandling: OperationDefinitionChangeHandling {
    func updateContentForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        switch event {
        case .asset:
            return [.amount, .fee]
        case .balance:
            return [.amount]
        case .amount:
            return [.fee]
        case .metadata:
            return [.amount, .fee]
        }
    }

    func clearErrorForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        return [.amount, .fee]
    }

    func shouldUpdateAccessoryForChange(event _: OperationDefinitionChangeEvent) -> Bool {
        false
    }
}
