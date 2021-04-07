import Foundation

final class WalletHistoryFilterPresenter {
    weak var view: WalletHistoryFilterViewProtocol?
    var wireframe: WalletHistoryFilterWireframeProtocol!
    var interactor: WalletHistoryFilterInteractorInputProtocol!

    let initialFilter = WalletHistoryFilter.all

    private(set) var currentFilter = WalletHistoryFilter.all

    private func updateView() {
        let viewModel = WalletHistoryFilterViewModel(
            filter: currentFilter,
            canApply: currentFilter != initialFilter,
            canReset: currentFilter != .all
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension WalletHistoryFilterPresenter: WalletHistoryFilterPresenterProtocol {
    func setup() {
        updateView()
    }

    func toggleTransfers() {
        currentFilter = currentFilter.symmetricDifference(.transfers)
        updateView()
    }

    func toggleRewardsAndSlashes() {
        currentFilter = currentFilter.symmetricDifference(.rewardsAndSlashes)
        updateView()
    }

    func toggleExtrinisics() {
        currentFilter = currentFilter.symmetricDifference(.extrinsics)
        updateView()
    }

    func apply() {}

    func reset() {
        currentFilter = .all
        updateView()
    }
}

extension WalletHistoryFilterPresenter: WalletHistoryFilterInteractorOutputProtocol {}
