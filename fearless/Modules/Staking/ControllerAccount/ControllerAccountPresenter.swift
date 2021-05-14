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
    private var stashAccount: AccountItem?
    private var stashItem: StashItem?
    private var chosenAccountItem: AccountItem?
    private var accounts: [AccountItem]?
    private var canChooseOtherController = false
    private var fee: Decimal?
    private var balance: Decimal?
    private var stakingLedger: StakingLedger?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        chain: Chain,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    private func updateView() {
        guard
            let stashItem = stashItem,
            let stashAccountItem = stashAccount
        else { return }
        let viewModel = viewModelFactory.createViewModel(
            stashItem: stashItem,
            stashAccountItem: stashAccountItem,
            chosenAccountItem: chosenAccountItem
        )
        canChooseOtherController = viewModel.canChooseOtherController
        view?.reload(with: viewModel)
    }

    func refreshFeeIfNeeded() {
        guard fee == nil else { return }

        if let stashAccount = stashAccount {
            interactor.estimateFee(for: stashAccount)
        } else if let chosenAccountItem = chosenAccountItem {
            interactor.estimateFee(for: chosenAccountItem)
        }
    }

    func refreshLedgerIfNeeded() {
        guard let chosenControllerAddress = chosenAccountItem?.address else {
            return
        }
        if chosenControllerAddress != stashItem?.controller {
            stakingLedger = nil
            interactor.fetchLedger(controllerAddress: chosenControllerAddress)
        }
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

        guard let accounts = accounts else {
            return
        }
        let context = PrimitiveContextWrapper(value: accounts)
        let title = LocalizableResource<String> { locale in
            R.string.localizable
                .stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
        }
        wireframe.presentAccountSelection(
            accounts,
            selectedAccountItem: chosenAccountItem,
            title: title,
            delegate: self,
            from: view,
            context: context
        )
    }

    func handleStashAction() {
        presentAccountOptions(for: stashAccount?.address)
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
            ),
            dataValidatingFactory.ledgerNotExist(
                stakingLedger: stakingLedger,
                addressType: chain.addressType,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard
                let self = self,
                let controllerAccountItem = self.chosenAccountItem
            else { return }

            self.wireframe.showConfirmation(
                from: self.view,
                controllerAccountItem: controllerAccountItem
            )
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
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveStashAccount(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(accountItem):
            stashAccount = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
        }
    }

    func didReceiveControllerAccount(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(accountItem):
            chosenAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveAccounts(result: Result<[AccountItem], Error>) {
        switch result {
        case let .success(accounts):
            self.accounts = accounts
        case let .failure(error):
            logger?.error("Did receive accounts error: \(error)")
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: chain.addressType.precision
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }
}

extension ControllerAccountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let accounts = (context as? PrimitiveContextWrapper<[AccountItem]>)?.value else {
            return
        }

        chosenAccountItem = accounts[index]
        refreshLedgerIfNeeded()
        updateView()
    }
}
