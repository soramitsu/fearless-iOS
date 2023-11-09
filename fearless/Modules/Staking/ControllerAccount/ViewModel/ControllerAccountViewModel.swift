import SoraFoundation
import SSFModels

struct ControllerAccountViewModel {
    let chainAsset: ChainAsset
    let stashViewModel: LocalizableResource<AccountInfoViewModel>
    let controllerViewModel: LocalizableResource<AccountInfoViewModel>
    let currentAccountIsController: Bool
    let actionButtonIsEnabled: Bool
}

extension ControllerAccountViewModel {
    var canChooseOtherController: Bool {
        !(chainAsset.chain.isWestend || chainAsset.chain.isPolkadotOrKusama)
    }
}
