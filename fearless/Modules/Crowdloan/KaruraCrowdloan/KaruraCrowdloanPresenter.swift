import Foundation
import SoraFoundation

final class KaruraCrowdloanPresenter {
    weak var view: KaruraCrowdloanViewProtocol?
    let wireframe: KaruraCrowdloanWireframeProtocol

    let bonusService: CrowdloanBonusServiceProtocol
    let displayInfo: CrowdloanDisplayInfo
    let inputAmount: Decimal
    let crowdloanViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let defaultReferralCode: String

    private var currentReferralCode: String = ""
    private var isTermsAgreed: Bool = false

    weak var crowdloanDelegate: CustomCrowdloanDelegate?

    init(
        wireframe: KaruraCrowdloanWireframeProtocol,
        bonusService: CrowdloanBonusServiceProtocol,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        crowdloanDelegate: CustomCrowdloanDelegate,
        crowdloanViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        defaultReferralCode: String
    ) {
        self.wireframe = wireframe
        self.bonusService = bonusService
        self.inputAmount = inputAmount
        self.displayInfo = displayInfo
        self.crowdloanDelegate = crowdloanDelegate
        self.crowdloanViewModelFactory = crowdloanViewModelFactory
        self.defaultReferralCode = defaultReferralCode
    }

    private func handleSave(result _: Result<Void, Error>) {}

    private func provideReferralViewModel() {
        let bonusValue = crowdloanViewModelFactory.createAdditionalBonusViewModel(
            inputAmount: inputAmount,
            displayInfo: displayInfo,
            bonusRate: bonusService.bonusRate,
            locale: selectedLocale
        )

        let bonusPercentage = NumberFormatter.percentSingle.string(from: bonusService.bonusRate as NSNumber)

        let viewModel = KaruraReferralViewModel(
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

extension KaruraCrowdloanPresenter: KaruraCrowdloanPresenterProtocol {
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

        bonusService.save(referrallCode: currentReferralCode) { [weak self] result in
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

extension KaruraCrowdloanPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideReferralViewModel()
            provideLearnMoreViewModel()
        }
    }
}
