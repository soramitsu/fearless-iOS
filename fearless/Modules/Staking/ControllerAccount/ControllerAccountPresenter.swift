import Foundation
import SoraFoundation
import BigInt
import SSFModels

final class ControllerAccountPresenter {
    private let wireframe: ControllerAccountWireframeProtocol
    private let interactor: ControllerAccountInteractorInputProtocol
    private let viewModelFactory: ControllerAccountViewModelFactoryProtocol
    private let applicationConfig: ApplicationConfigProtocol
    private let chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    weak var view: ControllerAccountViewProtocol?
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let logger: LoggerProtocol?
    private var stashAccountItem: ChainAccountResponse?
    private var stashItem: StashItem?
    private var chosenAccountItem: ChainAccountResponse?
    private var accounts: [ChainAccountResponse]?
    private var canChooseOtherController = false
    private var fee: Decimal?
    private var balance: Decimal?
    private var controllerBalance: Decimal?
    private var stakingLedger: StakingLedger?
    private var priceData: PriceData?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol? = nil,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func updateView() {
        guard let stashItem = stashItem else {
            return
        }
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

        if let stashAccountItem = stashAccountItem {
            interactor.estimateFee(for: stashAccountItem)
        } else if let chosenAccountItem = chosenAccountItem {
            interactor.estimateFee(for: chosenAccountItem)
        }
    }

    private func refreshControllerInfoIfNeeded() {
        guard let chosenControllerAddress = chosenAccountItem?.toAddress() else {
            return
        }
        if chosenControllerAddress != stashItem?.controller {
            stakingLedger = nil
            controllerBalance = nil
            interactor.fetchLedger(controllerAddress: chosenControllerAddress)
            interactor.fetchControllerAccountInfo(controllerAddress: chosenControllerAddress)
        }
    }

    private func provideFeeViewModel() {
        guard let fee = fee else {
            return
        }
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
        view?.didReceive(feeViewModel: feeViewModel)
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func didLoad(view: ControllerAccountViewProtocol) {
        interactor.setup()
        view.didReceive(chainName: chain.name)
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
            ),
            dataValidatingFactory.controllerBalanceIsNotZero(controllerBalance, locale: locale),
            dataValidatingFactory.ledgerNotExist(
                stakingLedger: stakingLedger,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard
                let self = self,
                let controllerAccountItem = self.chosenAccountItem
            else { return }

            self.wireframe.showConfirmation(
                from: self.view,
                controllerAccountItem: controllerAccountItem,
                asset: self.asset,
                chain: self.chain,
                selectedAccount: self.selectedAccount
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

    func didReceiveStashAccount(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            stashAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
        }
    }

    func didReceiveControllerAccount(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            chosenAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveAccounts(result: Result<[ChainAccountResponse], Error>) {
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
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(asset.precision))
                provideFeeViewModel()
            }
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                let amount = Decimal.fromSubstrateAmount(
                    accountInfo.data.stakingAvailable,
                    precision: Int16(asset.precision)
                )
                if address == stashItem?.stash {
                    balance = amount
                }
                if address == chosenAccountItem?.toAddress() {
                    controllerBalance = amount
                }
            } else if chosenAccountItem?.toAddress() == address {
                controllerBalance = nil
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
        guard let accounts = (context as? PrimitiveContextWrapper<[ChainAccountResponse]>)?.value else {
            return
        }

        chosenAccountItem = accounts[index]
        refreshControllerInfoIfNeeded()
        updateView()
    }
}
