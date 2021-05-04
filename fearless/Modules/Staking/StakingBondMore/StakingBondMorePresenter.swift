import SoraFoundation
import CommonWallet
import BigInt

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    weak var view: StakingBondMoreViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let logger: LoggerProtocol?

    var amount: Decimal = 0
    private let asset: WalletAsset
    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var electionStatus: ElectionStatus?
    private var stashItem: StashItem?
    private var stashAccount: AccountItem?

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        asset: WalletAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.asset = asset
        self.logger = logger
    }

    private func estimateFee() {
        guard fee == nil else {
            return
        }

        interactor.estimateFee()
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        )
        view?.didReceiveAsset(viewModel: viewModel)
    }
}

extension StakingBondMorePresenter: StakingBondMorePresenterProtocol {
    func setup() {
        provideAmountInputViewModel()

        interactor.setup()
    }

    func handleContinueAction() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            ),

            // TODO: fix to stash validation
            dataValidatingFactory.has(
                controller: stashAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.electionClosed(electionStatus, locale: locale)

        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.wireframe.showConfirmation(from: strongSelf.view, amount: strongSelf.amount)
        }
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
        estimateFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                amount = newAmount

                provideAmountInputViewModel()
                provideAsset()
            } else if let view = view {
                wireframe.presentAmountTooHigh(
                    from: view,
                    locale: view.localizationManager?.selectedLocale
                )
            }
        }
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case let .failure(error):
            logger?.error("Did receive election status error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: asset.precision
                )
            } else {
                balance = nil
            }

            provideAsset()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAsset()
            provideFee()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision)
            } else {
                fee = nil
            }

            provideFee()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStash(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(stashAccount):
            self.stashAccount = stashAccount
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }
}
