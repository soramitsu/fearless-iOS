import Foundation

enum RootViewState {
    case plain
    case retry(viewModel: RootViewModel)
    case update(viewModel: RootViewModel)
}

struct RootViewModel {
    let infoText: String
    let buttonTitle: String
}
