enum ControllerAccountActionButtonState {
    case hidden
    case enabled(Bool)
}

struct ControllerAccountViewModel {
    let rows: [ControllerAccountRow]
    let actionButtonState: ControllerAccountActionButtonState
}
