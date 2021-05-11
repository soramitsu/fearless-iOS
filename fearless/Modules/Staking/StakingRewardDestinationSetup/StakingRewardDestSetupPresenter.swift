import Foundation

final class StakingRewardDestSetupPresenter {
    weak var view: StakingRewardDestSetupViewProtocol?

    let wireframe: StakingRewardDestSetupWireframeProtocol
    let interactor: StakingRewardDestSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    let logger: LoggerProtocol?

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
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupPresenterProtocol {
    func setup() {
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

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupInteractorOutputProtocol {}
