import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

final class ControllerAccountConfirmationPresenter {
    weak var view: ControllerAccountConfirmationViewProtocol?
    var wireframe: ControllerAccountConfirmationWireframeProtocol!
    var interactor: ControllerAccountConfirmationInteractorInputProtocol!

    private let iconGenerator: IconGenerating
    private let controllerAccountItem: ChainAccountResponse
    private let chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol?
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var stashAccountItem: ChainAccountResponse?
    private var fee: Decimal?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var stakingLedger: StakingLedger?

    init(
        controllerAccountItem: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.controllerAccountItem = controllerAccountItem
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    private func updateView() {
        guard let stashAccountItem = stashAccountItem else { return }

        let viewModel = LocalizableResource<ControllerAccountConfirmationVM> { locale in
            let stashViewModel = self.createAccountInfoViewModel(
                stashAccountItem,
                title: R.string.localizable.stackingStashAccount(preferredLanguages: locale.rLanguages)
            )
            let controllerViewModel = self.createAccountInfoViewModel(
                self.controllerAccountItem,
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
            )

            return ControllerAccountConfirmationVM(
                stashViewModel: stashViewModel,
                controllerViewModel: controllerViewModel
            )
        }
        view?.reload(with: viewModel)
    }

    private func createAccountInfoViewModel(
        _ accountItem: ChainAccountResponse,
        title: String
    ) -> AccountInfoViewModel {
        let address = accountItem.toAddress() ?? ""
        let icon = try? iconGenerator
            .generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return AccountInfoViewModel(
            title: title,
            address: address,
            name: accountItem.name,
            icon: icon
        )
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func refreshFeeIfNeeded() {
        guard fee == nil else { return }
        interactor.estimateFee()
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationPresenterProtocol {
    func setup() {
        provideFeeViewModel()
        interactor.setup()
    }

    func handleStashAction() {
        presentAccountOptions(for: stashAccountItem?.toAddress())
    }

    func handleControllerAction() {
        presentAccountOptions(for: controllerAccountItem.toAddress())
    }

    func confirm() {
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
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.confirm()
        }
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
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            if let stashItem = stashItem {
                interactor.fetchStashAccountItem(for: stashItem.stash)
            } else {
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

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(asset.precision))
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.stakingAvailable,
                    precision: Int16(asset.precision)
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didConfirmed(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }
}
