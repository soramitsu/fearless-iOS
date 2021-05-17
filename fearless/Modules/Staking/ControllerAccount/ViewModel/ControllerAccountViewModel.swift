import SoraFoundation

struct ControllerAccountViewModel {
    let stashViewModel: LocalizableResource<AccountInfoViewModel>
    let controllerViewModel: LocalizableResource<AccountInfoViewModel>
    let currentAccountIsController: Bool
    let actionButtonIsEnabled: Bool
}

extension ControllerAccountViewModel {
    var canChooseOtherController: Bool {
        !currentAccountIsController
    }
}
