import Foundation
import RobinHood
import SoraFoundation
import IrohaCrypto

final class NetworkManagementPresenter {
    weak var view: NetworkManagementViewProtocol?
    var wireframe: NetworkManagementWireframeProtocol!
    var interactor: NetworkManagementInteractorInputProtocol!

    private var selectedConnectionItem: ConnectionItem?
    private var defaultConnectionItems: [ConnectionItem] = []

    private var defaultConnectionViewModels: [ManagedConnectionViewModel] = []
    private var customConnectionViewModels: [ManagedConnectionViewModel] = []

    private var pendingCompletion: Bool = false

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
        let newDefaultConnectionViewModels: [ManagedConnectionViewModel] = defaultConnectionItems.map { item in
            let selected: Bool = item.identifier == selectedConnectionItem?.identifier

            return viewModelFactory.createViewModelFromConnectionItem(item,
                                                                      selected: selected)
        }

        let newCustomConnectionViewModels: [ManagedConnectionViewModel] = listCalculator.allItems.map { item in
            let selected: Bool = item.identifier == selectedConnectionItem?.identifier

            return viewModelFactory.createViewModelFromManagedItem(item,
                                                                   selected: selected)
        }

        if
            defaultConnectionViewModels != newDefaultConnectionViewModels ||
                customConnectionViewModels != newCustomConnectionViewModels  {
            defaultConnectionViewModels = newDefaultConnectionViewModels
            customConnectionViewModels = newCustomConnectionViewModels

            view?.reload()
        }
    }

    private func checkPendingCompletion() {
        if pendingCompletion {
            pendingCompletion = false

            wireframe.complete(from: view)
        }
    }
}

extension NetworkManagementPresenter: NetworkManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateConnectionAdd() {
        wireframe.presentConnectionAdd(from: view)
    }

    func activateDefaultConnectionDetails(at index: Int) {
        let connection = defaultConnectionItems[index]

        wireframe.presentConnectionInfo(connection,
                                        mode: .none,
                                        from: view)
    }

    func activateCustomConnectionDetails(at index: Int) {
        let connection = ConnectionItem(managedConnectionItem: listCalculator.allItems[index])

        var mode: NetworkInfoMode = .name

        if connection.identifier != selectedConnectionItem?.identifier {
            mode.formUnion(.node)
        }

        wireframe.presentConnectionInfo(connection,
                                        mode: mode,
                                        from: view)
    }

    func selectDefaultItem(at index: Int) {
        let connection = defaultConnectionItems[index]

        if selectedConnectionItem != connection {
            pendingCompletion = true

            interactor.select(connection: connection)
        }
    }

    func selectCustomItem(at index: Int) {
        let connection = ConnectionItem(managedConnectionItem: listCalculator.allItems[index])

        if connection != selectedConnectionItem {
            pendingCompletion = true

            interactor.select(connection: connection)
        }
    }

    func moveCustomItem(at startIndex: Int, to finalIndex: Int) {
        guard startIndex != finalIndex else {
            return
        }

        var saveItems: [ManagedConnectionItem]

        if startIndex > finalIndex {
            saveItems = customConnectionViewModels[finalIndex...startIndex].map { viewModel in
                listCalculator.allItems.first { $0.identifier == viewModel.identifier }!
            }
        } else {
            saveItems = customConnectionViewModels[startIndex...finalIndex].map { viewModel in
                listCalculator.allItems.first { $0.identifier == viewModel.identifier }!
            }.reversed()
        }

        let targetViewModel = customConnectionViewModels.remove(at: startIndex)
        customConnectionViewModels.insert(targetViewModel, at: finalIndex)

        let initialOrder = saveItems[0].order

        for index in (0..<saveItems.count - 1) {
            saveItems[index] = saveItems[index].replacingOrder(saveItems[index+1].order)
        }

        let lastIndex = saveItems.count - 1
        saveItems[lastIndex] = saveItems[lastIndex].replacingOrder(initialOrder)

        interactor.save(items: saveItems)
    }

    func removeCustomItem(at index: Int) {
        let viewModel = customConnectionViewModels.remove(at: index)

        if let item = listCalculator.allItems.first(where: { $0.identifier == viewModel.identifier }) {
            interactor.remove(item: item)
        }
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

        checkPendingCompletion()
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

    func didFindMultiple(accounts: [AccountItem], for connection: ConnectionItem) {
        pendingCompletion = false

        let context = PrimitiveContextWrapper(value: (accounts, connection))

        wireframe.presentAccountSelection(accounts,
                                          addressType: connection.type,
                                          delegate: self,
                                          from: view,
                                          context: context)
    }

    func didFindNoAccounts(for connection: ConnectionItem) {
        pendingCompletion = false

        let title = R.string.localizable
            .accountNeededTitle(preferredLanguages: localizationManager.selectedLocale.rLanguages)
        let message = R.string.localizable
            .accountNeededMessage(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        let proceedTitle = R.string.localizable
            .commonProceed(preferredLanguages: localizationManager.selectedLocale.rLanguages)
        let proceedAction = AlertPresentableAction(title: proceedTitle) { [weak self] in
            self?.wireframe.presentAccountCreation(for: connection, from: self?.view)
        }

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        let viewModel = AlertPresentableViewModel(title: title,
                                                  message: message,
                                                  actions: [proceedAction],
                                                  closeAction: closeTitle)

        wireframe.present(viewModel: viewModel,
                          style: .alert,
                          from: view)
    }

    func didReceiveConnection(selectionError: Error) {
        if !wireframe.present(error: selectionError,
                              from: view,
                              locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}

extension NetworkManagementPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let (accounts, connection) =
            (context as? PrimitiveContextWrapper<([AccountItem], ConnectionItem)>)?.value else {
            return
        }

        pendingCompletion = true

        interactor.select(connection: connection, account: accounts[index])
    }

    func modalPickerDidSelectAction(context: AnyObject?) {
        guard
            let (_, connection) =
            (context as? PrimitiveContextWrapper<([AccountItem], ConnectionItem)>)?.value else {
            return
        }

        wireframe.presentAccountCreation(for: connection, from: view)
    }
}
