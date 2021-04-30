import Foundation
import SoraFoundation
import BigInt

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    let logger: LoggerProtocol?
    let chain: Chain

    private var bonded: Decimal?
    private var balance: Decimal?
    private var inputAmount: Decimal?
    private var bondingDuration: UInt32?
    private var minimalBalance: Decimal?
    private var priceData: PriceData?

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.logger = logger
    }

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(nil)
        view?.didReceiveInput(viewModel: inputView)
    }

    private func provideFeeViewModel() {
        view?.didReceiveFee(viewModel: nil)
    }

    private func provideAssetViewModel() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: bonded,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideBondingDuration() {
        let daysCount = bondingDuration.map { Int($0) / chain.erasPerDay }
        let bondingDuration: LocalizableResource<String> = LocalizableResource { locale in
            if let daysCount = daysCount {
                return R.string.localizable.stakingMainLockupPeriodValue(
                    format: daysCount,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return ""
            }
        }

        view?.didReceiveBonding(duration: bondingDuration)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
        provideBondingDuration()
        provideAssetViewModel()

        interactor.setup()
    }

    func selectAmountPercentage(_: Float) {}
    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        provideAssetViewModel()
    }

    func proceed() {}
    func close() {
        wireframe.close(view: view)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {
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

    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            if let stakingLedger = stakingLedger {
                bonded = Decimal.fromSubstrateAmount(
                    stakingLedger.active,
                    precision: chain.addressType.precision
                )
            } else {
                bonded = nil
            }

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

    func didReceiveBondingDuration(result: Result<UInt32, Error>) {
        switch result {
        case let .success(bondingDuration):
            self.bondingDuration = bondingDuration
            provideBondingDuration()
        case let .failure(error):
            logger?.error("Boding duration fetching error: \(error)")
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: chain.addressType.precision
            )
        case let .failure(error):
            logger?.error("Minimal balance fetching error: \(error)")
        }
    }
}
