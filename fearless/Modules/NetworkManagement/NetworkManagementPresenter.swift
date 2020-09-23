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
        wireframe.presentConnectionAdd(from: view)
    }

    func activateDefaultConnectionDetails(at index: Int) {
        let connection = defaultConnectionItems[index]

        wireframe.presentConnectionInfo(connection,
                                        readOnly: true,
                                        from: view)
    }

    func activateCustomConnectionDetails(at index: Int) {
        let connection = ConnectionItem(managedConnectionItem: listCalculator.allItems[index])

        wireframe.presentConnectionInfo(connection,
                                        readOnly: false,
                                        from: view)
    }

    func selectDefaultItem(at index: Int) {
        let connection = defaultConnectionItems[index]

        if selectedConnectionItem != connection {
            interactor.select(connection: connection)
        }
    }

    func selectCustomItem(at index: Int) {
        let connection = ConnectionItem(managedConnectionItem: listCalculator.allItems[index])

        if connection != selectedConnectionItem {
            interactor.select(connection: connection)
        }
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

    func didFindMultiple(accounts: [AccountItem], for connection: ConnectionItem) {
        let context = PrimitiveContextWrapper(value: (accounts, connection))

        wireframe.presentAccountSelection(accounts,
                                          addressType: connection.type,
                                          delegate: self,
                                          from: view,
                                          context: context)
    }

    func didFindNoAccounts(for connection: ConnectionItem) {
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
