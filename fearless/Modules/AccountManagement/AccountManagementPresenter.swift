import Foundation
import RobinHood
import IrohaCrypto
import SoraFoundation

final class AccountManagementPresenter {
    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    private var selectedAccountItem: AccountItem?

    let viewModelFactory: ManagedAccountViewModelFactoryProtocol
    let supportedNetworks: [SNAddressType]

    private var sections: [ManagedAccountViewModelSection] = []

    private let listCalculator: ListDifferenceCalculator<ManagedAccountItem> = {
        let calculator = ListDifferenceCalculator<ManagedAccountItem>(initialItems: []) { item1, item2 in
            item1.order < item2.order
        }

        return calculator
    }()

    init(viewModelFactory: ManagedAccountViewModelFactoryProtocol, supportedNetworks: [SNAddressType]) {
        self.viewModelFactory = viewModelFactory
        self.supportedNetworks = supportedNetworks
    }

    private func updateViewModels() {
        let groups = listCalculator.allItems
            .reduce(into: [SNAddressType: [ManagedAccountViewModelItem]]()) { result, item in
                let selected = (item.address == selectedAccountItem?.address)
                let viewModel = viewModelFactory.createViewModelFromItem(item, selected: selected)

                var viewModels = result[item.networkType] ?? []
                viewModels.append(viewModel)
                result[item.networkType] = viewModels
            }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let newSections: [ManagedAccountViewModelSection] = supportedNetworks.compactMap { addressType in
            guard let items = groups[addressType] else {
                return nil
            }

            let sectionTitle = addressType.titleForLocale(locale).uppercased()
            let icon = addressType.icon

            return ManagedAccountViewModelSection(
                title: sectionTitle,
                icon: icon,
                items: items
            )
        }

        if newSections != sections {
            sections = newSections
            view?.reload()
        }
    }
}

extension AccountManagementPresenter: AccountManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func numberOfSections() -> Int {
        sections.count
    }

    func section(at index: Int) -> ManagedAccountViewModelSection {
        sections[index]
    }

    func activateDetails(at index: Int, in section: Int) {
        let viewModel = sections[section].items[index]

        if let item = listCalculator.allItems.first(where: { $0.address == viewModel.address }) {
            wireframe.showAccountDetails(item, from: view)
        }
    }

    func activateAddAccount() {
        wireframe.showAddAccount(from: view)
    }

    func selectItem(at index: Int, in section: Int) {
        let viewModel = sections[section].items[index]

        if
            let item = listCalculator.allItems.first(where: { $0.address == viewModel.address }),
            item.address != selectedAccountItem?.address {
            interactor.select(item: item)

            wireframe.complete(from: view)
        }
    }

    func moveItem(at startIndex: Int, to finalIndex: Int, in section: Int) {
        guard startIndex != finalIndex else {
            return
        }

        var newItems = sections[section].items

        var saveItems: [ManagedAccountItem]

        if startIndex > finalIndex {
            saveItems = newItems[finalIndex ... startIndex].map { viewModel in
                listCalculator.allItems.first { $0.address == viewModel.address }!
            }
        } else {
            saveItems = newItems[startIndex ... finalIndex].map { viewModel in
                listCalculator.allItems.first { $0.address == viewModel.address }!
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

    func removeItem(at index: Int, in section: Int) {
        askAndPerformRemoveItem(at: index, in: section) { [weak self] result in
            if result {
                self?.view?.didRemoveItem(at: index, in: section)
            }
        }
    }

    func removeSection(at index: Int) {
        askAndPerformRemoveItem(at: 0, in: index) { [weak self] result in
            if result {
                self?.view?.didRemoveSection(at: index)
            }
        }
    }

    private func askAndPerformRemoveItem(at index: Int, in section: Int, completion: @escaping (Bool) -> Void) {
        let locale = localizationManager?.selectedLocale

        let removeTitle = R.string.localizable
            .accountDeleteConfirm(preferredLanguages: locale?.rLanguages)

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive) { [weak self] in
            self?.performRemoveItem(at: index, in: section)

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

    private func performRemoveItem(at index: Int, in section: Int) {
        var newItems = sections[section].items
        let viewModel = newItems.remove(at: index)

        if !newItems.isEmpty {
            let newSection = ManagedAccountViewModelSection(
                title: sections[section].title,
                icon: sections[section].icon,
                items: newItems
            )
            sections[section] = newSection
        } else {
            sections.remove(at: section)
        }

        if let item = listCalculator.allItems.first(where: { $0.address == viewModel.address }) {
            interactor.remove(item: item)
        }
    }
}

extension AccountManagementPresenter: AccountManagementInteractorOutputProtocol {
    func didReceive(changes: [DataProviderChange<ManagedAccountItem>]) {
        listCalculator.apply(changes: changes)
        updateViewModels()
    }

    func didReceiveSelected(item: AccountItem) {
        selectedAccountItem = item
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
        if view?.isSetup == true {
            updateViewModels()
        }
    }
}
