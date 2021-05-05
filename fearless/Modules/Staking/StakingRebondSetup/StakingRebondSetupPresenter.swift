import Foundation
import BigInt

final class StakingRebondSetupPresenter {
    weak var view: StakingRebondSetupViewProtocol?
    let wireframe: StakingRebondSetupWireframeProtocol!
    let interactor: StakingRebondSetupInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var inputAmount: Decimal?
    private var balance: Decimal?
    private var fee: Decimal?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var controller: AccountItem?
    private var stakingLedger: DyStakingLedger?
    private var electionStatus: ElectionStatus?
    private var activeEraInfo: ActiveEraInfo?

    var unbonding: Decimal? {
        if
            let activeEra = activeEraInfo?.index,
            let value = stakingLedger?.unbounding(inEra: activeEra) {
            return Decimal.fromSubstrateAmount(value, precision: chain.addressType.precision)
        } else {
            return nil
        }
    }

    init(
        wireframe: StakingRebondSetupWireframeProtocol,
        interactor: StakingRebondSetupInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.logger = logger
    }

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
        view?.didReceiveInput(viewModel: inputView)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAssetViewModel() {
        guard let unbonding = unbonding else {
            return
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: unbonding,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }
}

extension StakingRebondSetupPresenter: StakingRebondSetupPresenterProtocol {
    func selectAmountPercentage(_ percentage: Float) {
        if let unbonding = unbonding {
            inputAmount = unbonding * Decimal(Double(percentage))
            provideInputViewModel()
            provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        provideAssetViewModel()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.canRebond(amount: inputAmount, unbonding: unbonding, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.electionClosed(electionStatus, locale: locale)
        ]).runValidation { [weak self] in
            if let amount = self?.inputAmount {
                self?.wireframe.proceed(view: self?.view, amount: amount)
            } else {
                self?.logger?.warning("Missing amount after validation")
            }
        }
    }

    func close() {
        wireframe.close(view: view)
    }

    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
        provideAssetViewModel()

        interactor.setup()
    }
}

extension StakingRebondSetupPresenter: StakingRebondSetupInteractorOutputProtocol {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
            provideAssetViewModel()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideAssetViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(status):
            electionStatus = status
        case let .failure(error):
            logger?.error("Election status subscription error: \(error)")
        }
    }

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEraInfo = eraInfo
            provideAssetViewModel()
        case let .failure(error):
            logger?.error("Active era subscription error: \(error)")
        }
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(accountItem):
            controller = accountItem
        case let .failure(error):
            logger?.error("Received controller account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Received stash item error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>) {
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
}
