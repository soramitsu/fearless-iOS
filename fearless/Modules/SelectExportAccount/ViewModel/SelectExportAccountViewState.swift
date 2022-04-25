import Foundation

enum SelectExportAccountViewState {
    case loading(viewModel: SelectExportAccountViewModel)
    case loaded(viewModel: SelectExportAccountViewModel)
}
