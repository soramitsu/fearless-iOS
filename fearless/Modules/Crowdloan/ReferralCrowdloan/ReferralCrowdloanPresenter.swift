import Foundation
import SoraFoundation

final class ReferralCrowdloanPresenter {
    weak var view: ReferralCrowdloanViewProtocol?
    let wireframe: ReferralCrowdloanWireframeProtocol

    let bonusService: CrowdloanBonusServiceProtocol
    let displayInfo: CrowdloanDisplayInfo
    let inputAmount: Decimal
    let crowdloanViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let defaultReferralCode: String

    private var currentReferralCode: String = ""
    private var isTermsAgreed: Bool = false

    weak var crowdloanDelegate: CustomCrowdloanDelegate?

    init(
        wireframe: ReferralCrowdloanWireframeProtocol,
        bonusService: CrowdloanBonusServiceProtocol,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        crowdloanDelegate: CustomCrowdloanDelegate,
        crowdloanViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        defaultReferralCode: String,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.bonusService = bonusService
        self.inputAmount = inputAmount
        self.displayInfo = displayInfo
        self.crowdloanDelegate = crowdloanDelegate
        self.crowdloanViewModelFactory = crowdloanViewModelFactory
        self.defaultReferralCode = defaultReferralCode
        self.localizationManager = localizationManager
        currentReferralCode = bonusService.referralCode ?? ""
        isTermsAgreed = !currentReferralCode.isEmpty
    }

    private func handleSave(result: Result<Void, Error>) {
        switch result {
        case .success:
            crowdloanDelegate?.didReceive(bonusService: bonusService)
            wireframe.complete(on: view)
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    private func provideReferralViewModel() {
        let bonusValue = crowdloanViewModelFactory.createAdditionalBonusViewModel(
            inputAmount: inputAmount,
            displayInfo: displayInfo,
            bonusRate: bonusService.bonusRate,
            locale: selectedLocale
        )

        let bonusPercentage = NumberFormatter.percentSingle.string(from: bonusService.bonusRate as NSNumber)

        let viewModel = ReferralCrowdloanViewModel(
            bonusPercentage: bonusPercentage ?? "",
            bonusValue: bonusValue ?? "",
            canApplyDefaultCode: currentReferralCode != defaultReferralCode,
            isTermsAgreed: isTermsAgreed,
            isCodeReceived: !currentReferralCode.isEmpty
        )

        view?.didReceiveReferral(viewModel: viewModel)
    }

    private func provideLearnMoreViewModel() {
        let learnMoreViewModel = crowdloanViewModelFactory.createLearnMoreViewModel(
            from: displayInfo,
            locale: selectedLocale
        )

        view?.didReceiveLearnMore(viewModel: learnMoreViewModel)
    }

    private func provideInputViewModel() {
        let inputHandling = InputHandler(value: currentReferralCode, maxLength: 1024, predicate: NSPredicate.notEmpty)
        let viewModel = InputViewModel(inputHandler: inputHandling)
        view?.didReceiveInput(viewModel: viewModel)
    }
}

extension ReferralCrowdloanPresenter: ReferralCrowdloanPresenterProtocol {
    func setup() {
        provideInputViewModel()
        provideReferralViewModel()
        provideLearnMoreViewModel()
    }

    func update(referralCode: String) {
        currentReferralCode = referralCode
        provideReferralViewModel()
    }

    func applyDefaultCode() {
        currentReferralCode = defaultReferralCode
        provideReferralViewModel()
        provideInputViewModel()
    }

    func applyInputCode() {
        if currentReferralCode.isEmpty {
            view?.didReceiveShouldInputCode()
            return
        }

        if !isTermsAgreed {
            view?.didReceiveShouldAgreeTerms()
            return
        }

        view?.didStartLoading()

        bonusService.save(referralCode: currentReferralCode) { [weak self] result in
            self?.view?.didStopLoading()
            self?.handleSave(result: result)
        }
    }

    func setTermsAgreed(value: Bool) {
        isTermsAgreed = value
        provideReferralViewModel()
    }

    func presentTerms() {
        guard let view = view else {
            return
        }

        wireframe.showWeb(url: bonusService.termsURL, from: view, style: .automatic)
    }

    func presentLearnMore() {
        guard let view = view, let url = URL(string: displayInfo.website) else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }
}

extension ReferralCrowdloanPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideReferralViewModel()
            provideLearnMoreViewModel()
        }
    }
}
