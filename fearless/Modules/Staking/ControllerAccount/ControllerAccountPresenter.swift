import Foundation
import SoraFoundation
import BigInt

final class ControllerAccountPresenter {
    let wireframe: ControllerAccountWireframeProtocol
    let interactor: ControllerAccountInteractorInputProtocol
    let viewModelFactory: ControllerAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    weak var view: ControllerAccountViewProtocol?

    private let logger: LoggerProtocol?
    private var stashItem: StashItem?
    private var loadingAccounts = false
    private let initialSelectedAccount: AccountItem
    private var selectedAccount: AccountItem
    private var accounts: [AccountItem]?
    private var canChooseOtherController = false
    private var fee: Decimal?
    private var balance: Decimal?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        selectedAccount: AccountItem,
        chain: Chain,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
        initialSelectedAccount = selectedAccount
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    private func updateView() {
        guard
            let stashItem = stashItem,
            let accounts = accounts
        else { return }
        let viewModel = viewModelFactory.createViewModel(
            stashItem: stashItem,
            selectedAccountItem: selectedAccount,
            accounts: accounts
        )
        canChooseOtherController = viewModel.canChooseOtherController
        view?.reload(with: viewModel)
    }

    func refreshFeeIfNeeded() {
        guard fee == nil, selectedAccount.address != stashItem?.stash else {
            return
        }

        interactor.estimateFee(controllerAddress: selectedAccount.address)
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleControllerAction() {
        guard canChooseOtherController else {
            presentAccountOptions(for: stashItem?.controller)
            return
        }

        guard let accounts = accounts else { return }
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
    }

    func handleStashAction() {
        presentAccountOptions(for: stashItem?.stash)
    }

    private func presentAccountOptions(for address: AccountAddress?) {
        guard
            let view = view,
            let address = address
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
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showConfirmation(from: self?.view)
        }
    }
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
            updateView()
            if stashItem == nil {
                wireframe.close(view: view)
            }
        case let .failure(error):
            print(error)
        }
    }

    func didReceiveAccounts(result: Result<[AccountItem], Error>) {
        loadingAccounts = false

        switch result {
        case let .success(accounts):
            self.accounts = accounts

            updateView()
        case let .failure(error):
            print(error)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
            }
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
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
        refreshFeeIfNeeded()
        updateView()
    }
}
