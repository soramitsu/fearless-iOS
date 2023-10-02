import Foundation
import BigInt
import SSFModels

final class StakingRebondSetupPresenter {
    weak var view: StakingRebondSetupViewProtocol?
    let wireframe: StakingRebondSetupWireframeProtocol!
    let interactor: StakingRebondSetupInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let logger: LoggerProtocol?

    private var inputAmount: Decimal?
    private var balance: Decimal?
    private var fee: Decimal?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var controller: ChainAccountResponse?
    private var stakingLedger: StakingLedger?
    private var activeEraInfo: ActiveEraInfo?

    var unbonding: Decimal? {
        if
            let activeEra = activeEraInfo?.index,
            let value = stakingLedger?.unbonding(inEra: activeEra) {
            return Decimal.fromSubstrateAmount(value, precision: Int16(asset.precision))
        } else {
            return nil
        }
    }

    init(
        wireframe: StakingRebondSetupWireframeProtocol,
        interactor: StakingRebondSetupInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.logger = logger
    }

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
        view?.didReceiveInput(viewModel: inputView)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
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
            )
        ]).runValidation { [weak self] in
            if let self = self, let amount = self.inputAmount {
                self.wireframe.proceed(
                    view: self.view,
                    amount: amount,
                    chainAsset: ChainAsset(chain: self.chain, asset: self.asset),
                    wallet: self.selectedAccount,
                    flow: .relaychain(variant: .custom(amount: amount))
                )

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
            if let fee = BigUInt(string: dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(asset.precision))
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
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

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEraInfo = eraInfo
            provideAssetViewModel()
        case let .failure(error):
            logger?.error("Active era subscription error: \(error)")
        }
    }

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
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
}
