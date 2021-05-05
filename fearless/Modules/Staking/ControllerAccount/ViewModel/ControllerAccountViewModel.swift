enum ControllerAccountActionButtonState {
    case hidden
    case enabled(Bool)
}

struct ControllerAccountViewModel {
    let stashViewModel: AccountInfoViewModel?
    let controllerViewModel: AccountInfoViewModel?
    let actionButtonState: ControllerAccountActionButtonState
}
