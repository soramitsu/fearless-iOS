import Foundation
import CommonWallet

struct TransferConfirmDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(_ binder: WalletFormViewModelBinderProtocol,
                                    itemFactory: WalletFormItemViewFactoryProtocol) -> WalletFormDefining {
        TransferConfirmDefinition(binder: binder,
                                  itemViewFactory: itemFactory)
    }
}
