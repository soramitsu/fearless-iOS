import Foundation
import RobinHood
import IrohaCrypto
import SoraFoundation

final class AccountManagementPresenter {
    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    let viewModelFactory: ManagedAccountViewModelFactoryProtocol

    private var viewModels: [ManagedAccountViewModelItem] = []

    private let listCalculator: ListDifferenceCalculator<ManagedMetaAccountModel> = {
        let calculator = ListDifferenceCalculator<ManagedMetaAccountModel>(
            initialItems: []
        ) { item1, item2 in
            item1.order < item2.order
        }

        return calculator
    }()

    init(viewModelFactory: ManagedAccountViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func updateViewModels() {
        let viewModels = listCalculator.allItems.map { model in
            viewModelFactory.createViewModelFromItem(model)
        }

        if viewModels != self.viewModels {
            self.viewModels = viewModels
            view?.reload()
        }
    }
}

extension AccountManagementPresenter: AccountManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateDetails(at index: Int) {
        let viewModel = viewModels[index]

        if let item = listCalculator.allItems.first(
            where: { $0.identifier == viewModel.identifier }
        ) {
            wireframe.showAccountDetails(from: view, metaAccount: item.info)
        }
    }

    func activateAddAccount() {
        wireframe.showAddAccount(from: view)
    }

    func numberOfItems() -> Int {
        viewModels.count
    }

    func item(at index: Int) -> ManagedAccountViewModelItem {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        let viewModel = viewModels[index]

        if let item = listCalculator.allItems.first(where: { $0.identifier == viewModel.identifier }),
           !item.isSelected {
            interactor.select(item: item)
        }
    }

    func moveItem(at startIndex: Int, to finalIndex: Int) {
        guard startIndex != finalIndex else {
            return
        }

        var newItems = viewModels

        var saveItems: [ManagedMetaAccountModel]

        if startIndex > finalIndex {
            saveItems = newItems[finalIndex ... startIndex].map { viewModel in
                listCalculator.allItems.first { $0.identifier == viewModel.identifier }!
            }
        } else {
            saveItems = newItems[startIndex ... finalIndex].map { viewModel in
                listCalculator.allItems.first { $0.identifier == viewModel.identifier }!
            }.reversed()
        }

        let targetViewModel = newItems.remove(at: startIndex)
        newItems.insert(targetViewModel, at: finalIndex)

        let initialOrder = saveItems[0].order

        for index in 0 ..< saveItems.count - 1 {
            saveItems[index] = saveItems[index].replacingOrder(saveItems[index + 1].order)
        }

        let lastIndex = saveItems.count - 1
        saveItems[lastIndex] = saveItems[lastIndex].replacingOrder(initialOrder)

        interactor.save(items: saveItems)
    }

    func removeItem(at index: Int) {
        askAndPerformRemoveItem(at: index) { [weak self] result in
            if result {
                self?.view?.didRemoveItem(at: index)
            }
        }
    }

    private func askAndPerformRemoveItem(at index: Int, completion: @escaping (Bool) -> Void) {
        let locale = localizationManager?.selectedLocale

        let removeTitle = R.string.localizable
            .accountDeleteConfirm(preferredLanguages: locale?.rLanguages)

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive) { [weak self] in
            self?.performRemoveItem(at: index)

            completion(true)
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let cancelAction = AlertPresentableAction(title: cancelTitle, style: .cancel) {
            completion(false)
        }

        let title = R.string.localizable
            .accountDeleteConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let details = R.string.localizable
            .accountDeleteConfirmationDescription(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: details,
            actions: [cancelAction, removeAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    private func performRemoveItem(at index: Int) {
        let viewModel = viewModels.remove(at: index)

        if let item = listCalculator.allItems.first(where: { $0.identifier == viewModel.identifier }) {
            interactor.remove(item: item)
        }
    }
}

extension AccountManagementPresenter: AccountManagementInteractorOutputProtocol {
    func didCompleteSelection(of _: MetaAccountModel) {
        wireframe.complete(from: view)
    }

    func didReceive(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        listCalculator.apply(changes: changes)
        updateViewModels()
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager?.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager?.selectedLocale
            )
        }
    }
}

extension AccountManagementPresenter: Localizable {
    func applyLocalization() {
        guard let view = view else {
            return
        }

        if view.isSetup {
            updateViewModels()
        }
    }
}
