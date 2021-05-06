import SoraFoundation

enum ControllerAccountActionButtonState: Equatable {
    case hidden
    case enabled(Bool)
}

struct ControllerAccountViewModel {
    let stashViewModel: LocalizableResource<AccountInfoViewModel>
    let controllerViewModel: LocalizableResource<AccountInfoViewModel>
    let actionButtonState: ControllerAccountActionButtonState
    let canChooseOtherController: Bool
}
