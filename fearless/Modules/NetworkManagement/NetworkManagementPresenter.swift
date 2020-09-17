import Foundation
import RobinHood
import SoraFoundation

final class NetworkManagementPresenter {
    weak var view: NetworkManagementViewProtocol?
    var wireframe: NetworkManagementWireframeProtocol!
    var interactor: NetworkManagementInteractorInputProtocol!

    private var selectedConnectionItem: ConnectionItem?
    private var defaultConnectionItems: [ConnectionItem] = []

    private var defaultConnectionViewModels: [ManagedConnectionViewModel] = []
    private var customConnectionViewModels: [ManagedConnectionViewModel] = []

    private let listCalculator: ListDifferenceCalculator<ManagedConnectionItem> = {
        let calculator = ListDifferenceCalculator<ManagedConnectionItem>(initialItems: []) { (item1, item2) in
            item1.order < item2.order
        }

        return calculator
    }()

    let localizationManager: LocalizationManagerProtocol

    let viewModelFactory: ManagedConnectionViewModelFactoryProtocol

    init(localizationManager: LocalizationManagerProtocol,
         viewModelFactory: ManagedConnectionViewModelFactoryProtocol) {
        self.localizationManager = localizationManager
        self.viewModelFactory = viewModelFactory
    }

    private func updateViewModels() {
        defaultConnectionViewModels = defaultConnectionItems.map { item in
            let selected: Bool = item.identifier == selectedConnectionItem?.identifier

            return viewModelFactory.createViewModelFromConnectionItem(item,
                                                                      selected: selected)
        }

        customConnectionViewModels = listCalculator.allItems.map { item in
            let selected: Bool = item.identifier == selectedConnectionItem?.identifier

            return viewModelFactory.createViewModelFromManagedItem(item,
                                                                   selected: selected)
        }

        view?.reload()
    }
}

extension NetworkManagementPresenter: NetworkManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateConnectionAdd() {
        // TODO: FLW-258
    }

    func activateDefaultConnectionDetails(at index: Int) {
        // TODO: FLW-260
    }

    func activateCustomConnectionDetails(at index: Int) {
        // TODO: FLW-260
    }

    func selectDefaultItem(at index: Int) {
        // TODO: FLW-261
    }

    func selectCustomItem(at index: Int) {
        // TODO: FLW-261
    }

    func moveCustomItem(at startIndex: Int, to finalIndex: Int) {
        // TODO: FWL-259
    }

    func removeCustomItem(at index: Int) {
        // TODO: FWL-259
    }

    func defaultConnection(at index: Int) -> ManagedConnectionViewModel {
        defaultConnectionViewModels[index]
    }

    func customConnection(at index: Int) -> ManagedConnectionViewModel {
        customConnectionViewModels[index]
    }

    func numberOfDefaultConnections() -> Int {
        defaultConnectionViewModels.count
    }

    func numberOfCustomConnections() -> Int {
        customConnectionViewModels.count
    }
}

extension NetworkManagementPresenter: NetworkManagementInteractorOutputProtocol {
    func didReceiveSelectedConnection(_ item: ConnectionItem) {
        selectedConnectionItem = item
        updateViewModels()
    }

    func didReceiveDefaultConnections(_ connections: [ConnectionItem]) {
        defaultConnectionItems = connections
        updateViewModels()
    }

    func didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>]) {
        listCalculator.apply(changes: changes)
        updateViewModels()
    }

    func didReceiveCustomConnection(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}
