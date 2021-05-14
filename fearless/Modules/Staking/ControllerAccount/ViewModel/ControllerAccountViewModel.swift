import SoraFoundation

struct ControllerAccountViewModel {
    let stashViewModel: LocalizableResource<AccountInfoViewModel>
    let controllerViewModel: LocalizableResource<AccountInfoViewModel>
    let canChooseOtherController: Bool
    let currentAccountIsController: Bool
    let actionButtonIsEnabled: Bool
}
