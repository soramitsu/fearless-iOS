import Foundation
import CommonWallet

final class WalletHistoryFilterPresenter {
    weak var view: WalletHistoryFilterViewProtocol?
    var wireframe: WalletHistoryFilterWireframeProtocol!

    let initialFilter: WalletHistoryFilter

    private(set) var currentFilter: WalletHistoryFilter

    init(filter: WalletHistoryFilter) {
        initialFilter = filter
        currentFilter = filter
    }

    private func createViewModel() -> WalletHistoryFilterViewModel {
        let items = WalletHistoryFilterRow.allCases.map { row in
            WalletHistoryFilterItemViewModel(title: row.title, isOn: currentFilter.contains(row.filter))
        }

        return WalletHistoryFilterViewModel(
            items: items,
            canApply: currentFilter != initialFilter,
            canReset: currentFilter != .all
        )
    }
}

extension WalletHistoryFilterPresenter: WalletHistoryFilterPresenterProtocol {
    func setup() {
        view?.didReceive(viewModel: createViewModel())
    }

    func toggleFilterItem(at index: Int) {
        guard let filter = WalletHistoryFilterRow(rawValue: index)?.filter else {
            return
        }

        let newFilter = currentFilter.symmetricDifference(filter)

        if newFilter != [] {
            currentFilter = newFilter

            view?.didConfirm(viewModel: createViewModel())
        } else {
            view?.didReceive(viewModel: createViewModel())
        }
    }

    func apply() {
        wireframe.proceed(from: view, applying: currentFilter)
    }

    func reset() {
        currentFilter = .all
        view?.didReceive(viewModel: createViewModel())
    }
}
