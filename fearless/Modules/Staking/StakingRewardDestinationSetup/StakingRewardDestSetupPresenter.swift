import Foundation
import BigInt

final class StakingRewardDestSetupPresenter {
    weak var view: StakingRewardDestSetupViewProtocol?

    let wireframe: StakingRewardDestSetupWireframeProtocol
    let interactor: StakingRewardDestSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var rewardDestination: RewardDestination<AccountItem> = .restake
    private var calculator: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var amount: Decimal?
    private var fee: Decimal?

    init(
        wireframe: StakingRewardDestSetupWireframeProtocol,
        interactor: StakingRewardDestSetupInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.logger = logger
    }

    // MARK: - Private functions

//    private func provideRewardDestination() {
//        do {
//            let reward: CalculatedReward?
//
//            if let calculator = calculator {
//                let restake = try calculator.calculateNetworkReturn(
//                    isCompound: true,
//                    period: .year
//                )
//
//                let payout = try calculator.calculateNetworkReturn(
//                    isCompound: false,
//                    period: .year
//                )
//
//                let curAmount = amount ?? 0.0
//                reward = CalculatedReward(
//                    restakeReturn: restake * curAmount,
//                    restakeReturnPercentage: restake,
//                    payoutReturn: payout * curAmount,
//                    payoutReturnPercentage: payout
//                )
//            } else {
//                reward = nil
//            }
//
//            switch rewardDestination {
//            case .restake:
//                let viewModel = rewardDestViewModelFactory.createRestake(from: reward)
//                view?.didReceiveRewardDestination(viewModel: viewModel)
//            case .payout:
//                let viewModel = try rewardDestViewModelFactory
//                    .createPayout(from: reward, account: payoutAccount)
//                view?.didReceiveRewardDestination(viewModel: viewModel)
//            }
//        } catch {
//            logger.error("Can't create reward destination")
//        }
//    }
//
    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupPresenterProtocol {
    func setup() {
//        provideRewardDestination()
        provideFeeViewModel()

        interactor.setup()
    }

    func selectRestakeDestination() {
        #warning("Not implemented")
    }

    func selectPayoutDestination() {
        #warning("Not implemented")
    }

    func selectPayoutAccount() {
        #warning("Not implemented")
    }

    func displayLearnMore() {
        if let view = view {
            wireframe.showWeb(
                url: applicationConfig.learnPayoutURL,
                from: view,
                style: .automatic
            )
        }
    }

    func proceed() {
        #warning("Not implemented")
//        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
//        DataValidationRunner(validators: [
//            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),
//
//            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
//                self?.interactor.estimateFee()
//            }),
//
//            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),
//
//            dataValidatingFactory.has(
//                controller: controller,
//                for: stashItem?.controller ?? "",
//                locale: locale
//            ),
//
//            dataValidatingFactory.electionClosed(electionStatus, locale: locale),
//
//            dataValidatingFactory.stashIsNotKilledAfterUnbonding(
//                amount: inputAmount,
//                bonded: bonded,
//                minimumAmount: minimalBalance,
//                locale: locale
//            )
//        ]).runValidation { [weak self] in
//            if let amount = self?.inputAmount {
//                self?.wireframe.proceed(view: self?.view, amount: amount)
//            } else {
//                self?.logger?.warning("Missing amount after validation")
//            }
//        }
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupInteractorOutputProtocol {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }
}
