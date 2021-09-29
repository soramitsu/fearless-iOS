import Foundation
import CommonWallet
import SoraFoundation

struct WalletFearlessDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(
        _ binder: WalletFormViewModelBinderProtocol,
        itemFactory: WalletFormItemViewFactoryProtocol
    ) -> WalletFormDefining {
        WalletFearlessDefinition(
            binder: binder,
            itemViewFactory: itemFactory
        )
    }
}
