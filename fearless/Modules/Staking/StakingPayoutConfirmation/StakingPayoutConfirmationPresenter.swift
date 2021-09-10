import Foundation
import BigInt
import CommonWallet

final class StakingPayoutConfirmationPresenter {
    weak var view: StakingPayoutConfirmationViewProtocol?
    var wireframe: StakingPayoutConfirmationWireframeProtocol!
    var interactor: StakingPayoutConfirmationInteractorInputProtocol!

    private var balance: Decimal?
    private var fee: Decimal?
    private var rewardAmount: Decimal = 0.0
    private var priceData: PriceData?
    private var account: AccountItem?
    private var rewardDestination: RewardDestination<DisplayAddress>?

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let payoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let chain: Chain
    private let asset: WalletAsset
    private let logger: LoggerProtocol?

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        payoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: Chain,
        asset: WalletAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.payoutConfirmViewModelFactory = payoutConfirmViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.asset = asset
        self.logger = logger
    }

    // MARK: - Private functions

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceive(feeViewModel: viewModel)
        } else {
            view?.didReceive(feeViewModel: nil)
        }
    }

    private func provideViewModel() {
        guard let account = self.account else { return }

        let viewModel = payoutConfirmViewModelFactory.createPayoutConfirmViewModel(
            with: account,
            rewardAmount: rewardAmount,
            rewardDestination: rewardDestination,
            priceData: priceData
        )

        view?.didRecieve(viewModel: viewModel)
    }

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
            logger?.error("Did receive error: \(error)")
        }
    }
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationPresenterProtocol {
    func setup() {
        provideFee()
        interactor.setup()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.interactor.estimateFee()
            },

            dataValidatingFactory.rewardIsHigherThanFee(
                reward: rewardAmount,
                fee: fee,
                locale: locale
            ),

            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.interactor.submitPayout()
        }
    }

    func presentAccountOptions(for viewModel: AccountInfoViewModel) {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let view = view,
           let chain = WalletAssetId(rawValue: asset.identifier)?.chain {
            wireframe.presentAccountOptions(
                from: view,
                address: viewModel.address,
                chain: chain,
                locale: locale
            )
        }
    }
}

// MARK: - StakingPayoutConfirmationInteractorOutputProtocol

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationInteractorOutputProtocol {
    func didReceiveFee(result: Result<Decimal, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
            provideFee()

        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFee()
            provideViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.available {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: asset.precision
                )
            } else {
                balance = 0.0
            }

        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveRewardDestination(result: Result<RewardDestination<DisplayAddress>?, Error>) {
        switch result {
        case let .success(rewardDestination):
            self.rewardDestination = rewardDestination
            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive reward destination error: \(error)")
        }
    }

    func didStartPayout() {
        view?.didStartLoading()
    }

    func didCompletePayout(txHashes: [String]) {
        txHashes.forEach { txHash in
            logger?.info("Did send payouts: \(txHash)")
        }

        view?.didStopLoading()

        wireframe.complete(from: view)
    }

    func didFailPayout(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }

    func didRecieve(account: AccountItem, rewardAmount: Decimal) {
        self.account = account
        self.rewardAmount = rewardAmount

        provideViewModel()
    }
}
