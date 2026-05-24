import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFUtils
@testable import fearless

final class ReferralCrowdloanTests: XCTestCase {
    func testSetup_whenPresenterLoads_thenProvidesInputReferralAndLearnMoreViewModels() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertNotNil(fixture.view.inputViewModel)
        XCTAssertEqual(fixture.view.learnMoreViewModel?.title, "Learn about Karura")
        XCTAssertEqual(fixture.view.referralViewModel?.bonusValue, "0.5 KAR")
        XCTAssertEqual(fixture.view.referralViewModel?.canApplyDefaultCode, true)
        XCTAssertEqual(fixture.view.referralViewModel?.isTermsAgreed, false)
        XCTAssertEqual(fixture.view.referralViewModel?.isCodeReceived, false)
    }

    func testApplyInputCode_whenDefaultCodeAndTermsAgreed_thenSavesCodeAndCompletes() {
        let fixture = makeFixture()

        fixture.presenter.update(referralCode: "custom")
        fixture.presenter.applyDefaultCode()
        fixture.presenter.setTermsAgreed(value: true)
        fixture.presenter.applyInputCode()

        XCTAssertEqual(fixture.bonusService.referralCode, KaruraBonusService.defaultReferralCode)
        XCTAssertTrue(fixture.delegate.receivedBonusService === fixture.bonusService)
        XCTAssertTrue(fixture.wireframe.completedView === fixture.view)
        XCTAssertEqual(fixture.view.startLoadingCallCount, 1)
        XCTAssertEqual(fixture.view.stopLoadingCallCount, 1)
        XCTAssertEqual(fixture.view.referralViewModel?.canApplyDefaultCode, false)
        XCTAssertEqual(fixture.view.referralViewModel?.isTermsAgreed, true)
    }

    func testApplyInputCode_whenCodeIsEmpty_thenRequestsCodeInput() {
        let fixture = makeFixture()

        fixture.presenter.setTermsAgreed(value: true)
        fixture.presenter.applyInputCode()

        XCTAssertEqual(fixture.view.shouldInputCodeCallCount, 1)
        XCTAssertNil(fixture.bonusService.referralCode)
        XCTAssertNil(fixture.wireframe.completedView)
    }

    func testApplyInputCode_whenTermsAreMissing_thenRequestsTermsAgreement() {
        let fixture = makeFixture()

        fixture.presenter.update(referralCode: "ref-code")
        fixture.presenter.applyInputCode()

        XCTAssertEqual(fixture.view.shouldAgreeTermsCallCount, 1)
        XCTAssertNil(fixture.bonusService.referralCode)
        XCTAssertNil(fixture.wireframe.completedView)
    }

    func testPresentActions_whenUrlsAvailable_thenRoutesToWireframe() {
        let fixture = makeFixture()

        fixture.presenter.presentTerms()
        fixture.presenter.presentLearnMore()

        XCTAssertEqual(fixture.wireframe.shownURLs, [
            URL(string: "https://terms.example.com")!,
            URL(string: "https://karura.network")!
        ])
    }

    private typealias Fixture = (
        presenter: ReferralCrowdloanPresenter,
        view: ReferralCrowdloanViewSpy,
        wireframe: ReferralCrowdloanWireframeSpy,
        bonusService: ReferralBonusServiceSpy,
        delegate: CustomCrowdloanDelegateSpy
    )

    private func makeFixture(
        existingReferralCode: String? = nil,
        defaultReferralCode: String = KaruraBonusService.defaultReferralCode
    ) -> Fixture {
        let view = ReferralCrowdloanViewSpy()
        let wireframe = ReferralCrowdloanWireframeSpy()
        let bonusService = ReferralBonusServiceSpy(referralCode: existingReferralCode)
        let delegate = CustomCrowdloanDelegateSpy()
        let presenter = ReferralCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: makeDisplayInfo(),
            inputAmount: 10,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: CrowdloanContributionViewModelFactorySpy(),
            defaultReferralCode: defaultReferralCode,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view

        return (presenter, view, wireframe, bonusService, delegate)
    }

    private func makeDisplayInfo() -> CrowdloanDisplayInfo {
        CrowdloanDisplayInfo(
            paraid: "2000",
            name: "Karura",
            token: "KAR",
            description: "Karura crowdloan",
            website: "https://karura.network",
            icon: "https://karura.network/icon.svg",
            rewardRate: 12,
            endingBlock: nil,
            disabled: nil,
            flow: .karura
        )
    }
}

private final class ReferralCrowdloanViewSpy: ReferralCrowdloanViewProtocol {
    let controller = UIViewController()
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    var isSetup = true

    private(set) var learnMoreViewModel: LearnMoreViewModel?
    private(set) var referralViewModel: ReferralCrowdloanViewModel?
    private(set) var inputViewModel: InputViewModelProtocol?
    private(set) var shouldInputCodeCallCount = 0
    private(set) var shouldAgreeTermsCallCount = 0
    private(set) var startLoadingCallCount = 0
    private(set) var stopLoadingCallCount = 0

    func didReceiveLearnMore(viewModel: LearnMoreViewModel) {
        learnMoreViewModel = viewModel
    }

    func didReceiveReferral(viewModel: ReferralCrowdloanViewModel) {
        referralViewModel = viewModel
    }

    func didReceiveInput(viewModel: InputViewModelProtocol) {
        inputViewModel = viewModel
    }

    func didReceiveShouldInputCode() {
        shouldInputCodeCallCount += 1
    }

    func didReceiveShouldAgreeTerms() {
        shouldAgreeTermsCallCount += 1
    }

    func didStartLoading() {
        startLoadingCallCount += 1
    }

    func didStopLoading() {
        stopLoadingCallCount += 1
    }
}

private final class ReferralCrowdloanWireframeSpy: ReferralCrowdloanWireframeProtocol {
    private(set) var completedView: ReferralCrowdloanViewProtocol?
    private(set) var shownURLs: [URL] = []
    private(set) var presentedErrors: [Error] = []

    func complete(on view: ReferralCrowdloanViewProtocol?) {
        completedView = view
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        shownURLs.append(url)
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class ReferralBonusServiceSpy: CrowdloanBonusServiceProtocol {
    let bonusRate: Decimal = 0.05
    let termsURL: URL? = URL(string: "https://terms.example.com")
    private(set) var referralCode: String?

    init(referralCode: String?) {
        self.referralCode = referralCode
    }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode
        closure(.success(()))
    }

    func applyOffchainBonusForContribution(
        amount _: BigUInt?,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt?,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        builder
    }
}

private final class CustomCrowdloanDelegateSpy: CustomCrowdloanDelegate {
    private(set) var receivedBonusService: CrowdloanBonusServiceProtocol?

    func didReceive(bonusService: CrowdloanBonusServiceProtocol) {
        receivedBonusService = bonusService
    }
}

private final class CrowdloanContributionViewModelFactorySpy: CrowdloanContributionViewModelFactoryProtocol {
    func createContributionSetupViewModel(
        from _: Crowdloan,
        displayInfo _: CrowdloanDisplayInfo?,
        metadata _: CrowdloanMetadata,
        locale _: Locale
    ) -> CrowdloanContributionSetupViewModel {
        fatalError("Unused in ReferralCrowdloanTests")
    }

    func createContributionConfirmViewModel(
        from _: Crowdloan,
        metadata _: CrowdloanMetadata,
        confirmationData _: CrowdloanContributionConfirmData,
        locale _: Locale
    ) throws -> CrowdloanContributeConfirmViewModel {
        fatalError("Unused in ReferralCrowdloanTests")
    }

    func createEstimatedRewardViewModel(
        inputAmount _: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> String? {
        fatalError("Unused in ReferralCrowdloanTests")
    }

    func createAdditionalBonusViewModel(
        inputAmount _: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        bonusRate _: Decimal?,
        locale _: Locale
    ) -> String? {
        "0.5 KAR"
    }

    func createLearnMoreViewModel(
        from displayInfo: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> LearnMoreViewModel {
        LearnMoreViewModel(
            iconViewModel: nil,
            title: "Learn about \(displayInfo.name)",
            subtitle: displayInfo.description
        )
    }
}
