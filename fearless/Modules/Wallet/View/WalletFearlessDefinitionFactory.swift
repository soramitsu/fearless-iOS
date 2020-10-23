import Foundation
import CommonWallet

struct WalletFearlessDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(_ binder: WalletFormViewModelBinderProtocol,
                                    itemFactory: WalletFormItemViewFactoryProtocol) -> WalletFormDefining {
        WalletFearlessDefinition(binder: binder, itemViewFactory: itemFactory)
    }
}
