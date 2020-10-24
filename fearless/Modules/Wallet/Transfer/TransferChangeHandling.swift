import Foundation
import CommonWallet

final class TransferChangeHandling: OperationDefinitionChangeHandling {
    func updateContentForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        switch event {
        case .asset:
            return [.asset, .amount, .fee]
        case .balance:
            return [.asset]
        case .amount:
            return [.fee, .asset]
        case .metadata:
            return [.fee, .asset]
        }
    }

    func clearErrorForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        switch event {
        case .asset:
            return [.asset, .amount, .fee]
        case .balance:
            return [.asset, .amount, .fee]
        case .amount:
            return [.amount, .fee]
        case .metadata:
            return [.amount, .fee]
        }
    }

    func shouldUpdateAccessoryForChange(event: OperationDefinitionChangeEvent) -> Bool {
        false
    }
}
