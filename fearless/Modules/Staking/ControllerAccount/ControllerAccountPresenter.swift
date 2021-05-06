import Foundation
import SoraFoundation

final class ControllerAccountPresenter {
    let wireframe: ControllerAccountWireframeProtocol
    let interactor: ControllerAccountInteractorInputProtocol
    let viewModelFactory: ControllerAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    weak var view: ControllerAccountViewProtocol?

    private var stashItem: StashItem?
    private var loadingAccounts = false
    private let initialSelectedAccount: AccountItem
    private var selectedAccount: AccountItem

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        selectedAccount: AccountItem,
        chain: Chain
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
        initialSelectedAccount = selectedAccount
        self.selectedAccount = selectedAccount
        self.chain = chain
    }

    private func updateView() {
        guard let stashItem = stashItem else { return }
        let viewModel = viewModelFactory.createViewModel(
            stashAddress: stashItem.stash,
            controllerAddress: stashItem.controller
        )
        view?.reload(with: viewModel)
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleControllerAction() {
        guard !loadingAccounts else {
            return
        }

        loadingAccounts = true

        interactor.fetchAccounts()
    }

    func handleStashAction() {
        guard
            let view = view,
            let address = stashItem?.stash
        else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: view.localizationManager?.selectedLocale ?? .current
        )
    }

    func selectLearnMore() {
        guard let view = view else { return }
        wireframe.showWeb(
            url: applicationConfig.learnControllerAccountURL,
            from: view,
            style: .automatic
        )
    }

    func proceed() {
        wireframe.showConfirmation(from: view)
    }
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
            updateView()
        case let .failure(error):
            print(error)
        }
    }

    func didReceiveAccounts(result: Result<[AccountItem], Error>) {
        loadingAccounts = false

        switch result {
        case let .success(accounts):
            let context = PrimitiveContextWrapper(value: accounts)
            let title = LocalizableResource<String> { locale in
                R.string.localizable
                    .stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
            }
            wireframe.presentAccountSelection(
                accounts,
                selectedAccountItem: selectedAccount,
                title: title,
                delegate: self,
                from: view,
                context: context
            )
        case let .failure(error):
            print(error)
        }
    }
}

extension ControllerAccountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[AccountItem]>)?.value
        else {
            return
        }

        selectedAccount = accounts[index]
        updateView()
    }
}
