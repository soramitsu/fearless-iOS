import Foundation

enum FiltersViewState {
    case loading
    case empty
    case loaded(viewModel: FiltersViewModel)
}
