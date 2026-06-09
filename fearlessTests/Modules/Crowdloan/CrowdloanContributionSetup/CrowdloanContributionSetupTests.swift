import BigInt
import FearlessFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CrowdloanContributionSetupTests: XCTestCase {
    func testSetup_whenInteractorDataArrives_thenProvidesViewModelsAndEstimatesInitialFee() throws {
        let fixture = try makeFixture()

        fixture.presenter.setup()
        fixture.emitReadyState()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.feeRequests.map(\.amount), [0])
        XCTAssertNotNil(fixture.view.inputViewModel)
        XCTAssertNotNil(fixture.view.assetViewModel)
        XCTAssertNotNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.crowdloanViewModel?.title, "Moonbase setup")
        XCTAssertEqual(fixture.view.estimatedRewardViewModel, "estimated:0")
        XCTAssertEqual(fixture.view.bonusViewModel, "bonus:nil:0")
    }

    func testUpdateAmountAndProceed_whenValidationPasses_thenShowsConfirmation() throws {
        let fixture = try makeFixture()
        fixture.emitReadyState()

        fixture.presenter.updateAmount(2)
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.interactor.feeRequests.last?.amount, 2_000_000_000_000)
        XCTAssertEqual(fixture.view.estimatedRewardViewModel, "estimated:2")
        XCTAssertEqual(fixture.view.bonusViewModel, "bonus:nil:2")
        XCTAssertEqual(fixture.wireframe.confirmationParaId, fixture.crowdloan.paraId)
        XCTAssertEqual(fixture.wireframe.confirmationAmount, 2)
        XCTAssertNil(fixture.wireframe.confirmationBonusService)
    }

    func testProceed_whenFeeMissing_thenRefreshesFeeAndDoesNotShowConfirmation() throws {
        let fixture = try makeFixture()
        fixture.emitReadyState(includeFee: false)

        fixture.presenter.updateAmount(3)
        fixture.interactor.feeRequests.removeAll()
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.interactor.feeRequests.map(\.amount), [3_000_000_000_000])
        XCTAssertNil(fixture.wireframe.confirmationAmount)
        XCTAssertTrue(fixture.wireframe.didPresentFeeNotReceived)
    }

    func testSelectAmountPercentage_whenFeeKnown_thenUsesBalanceMinusFee() throws {
        let fixture = try makeFixture()
        fixture.emitReadyState()

        fixture.presenter.selectAmountPercentage(0.5)

        XCTAssertEqual(fixture.view.inputViewModel?.decimalAmount, 10)
        XCTAssertEqual(fixture.view.estimatedRewardViewModel, "estimated:9.99975")
        XCTAssertEqual(fixture.interactor.feeRequests.last?.amount, 9_999_750_000_000)
    }

    func testLearnMoreAndAdditionalBonusActions_thenRouteThroughWireframe() throws {
        let fixture = try makeFixture()
        fixture.emitReadyState()

        fixture.presenter.updateAmount(4)
        fixture.presenter.presentLearnMore()
        fixture.presenter.presentAdditionalBonuses()

        XCTAssertEqual(fixture.wireframe.webURL, URL(string: "https://example.com"))
        XCTAssertEqual(fixture.wireframe.additionalBonusAmount, 4)
        XCTAssertTrue(fixture.wireframe.additionalBonusDelegate === fixture.presenter)
    }

    func testDidReceiveBonusService_thenRefreshesBonusAndUsesServiceOnConfirmation() throws {
        let fixture = try makeFixture()
        let bonusService = SetupCrowdloanBonusServiceStub(bonusRate: 0.15)
        fixture.emitReadyState()

        fixture.presenter.updateAmount(5)
        fixture.interactor.feeRequests.removeAll()
        fixture.presenter.didReceive(bonusService: bonusService)
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.view.bonusViewModel, "bonus:0.15:5")
        XCTAssertTrue(fixture.interactor.feeRequests.last?.bonusService === bonusService)
        XCTAssertTrue(fixture.wireframe.confirmationBonusService === bonusService)
    }

    private func makeFixture() throws -> CrowdloanContributionSetupFixture {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            hasCrowdloans: true
        )
        let asset = ChainModelGenerator.generateAssetWithId(
            "unit",
            symbol: "UNIT",
            assetPresicion: 12
        )
        chain.assets = [asset]

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let interactor = CrowdloanContributionSetupInteractorInputSpy()
        let wireframe = CrowdloanContributionSetupWireframeSpy()
        let validatorFactory = CrowdloanDataValidatorFactorySpy(basePresentable: wireframe)
        let viewModelFactory = CrowdloanContributionViewModelFactorySpy()
        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            contributionViewModelFactory: viewModelFactory,
            dataValidatingFactory: validatorFactory,
            assetInfo: asset.displayInfo(with: chain.icon),
            localizationManager: LocalizationManager.shared,
            logger: LoggerSpy(),
            chainAsset: chainAsset,
            selectedCurrency: Currency.defaultCurrency()
        )
        let view = CrowdloanContributionSetupViewSpy()
        presenter.view = view
        validatorFactory.view = view

        return CrowdloanContributionSetupFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            chainAsset: chainAsset,
            crowdloan: try makeCrowdloan()
        )
    }

    private func makeCrowdloan() throws -> Crowdloan {
        let depositor = Data(repeating: 2, count: 32)
        let payload = """
        {
          "depositor": "\(depositor.base64EncodedString())",
          "deposit": "100",
          "raised": "1000000000000",
          "end": "1000",
          "cap": "9000000000000000",
          "lastContribution": ["Never", null],
          "firstPeriod": "2",
          "lastPeriod": "4",
          "trieIndex": "1"
        }
        """
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let fundInfo = try JSONDecoder().decode(CrowdloanFunds.self, from: data)

        return Crowdloan(paraId: 2_000, fundInfo: fundInfo)
    }
}

private struct CrowdloanContributionSetupFixture {
    let presenter: CrowdloanContributionSetupPresenter
    let interactor: CrowdloanContributionSetupInteractorInputSpy
    let wireframe: CrowdloanContributionSetupWireframeSpy
    let view: CrowdloanContributionSetupViewSpy
    let chainAsset: ChainAsset
    let crowdloan: Crowdloan

    func emitReadyState(includeFee: Bool = true) {
        presenter.didReceiveCrowdloan(result: .success(crowdloan))
        presenter.didReceiveDisplayInfo(
            result: .success(
                CrowdloanDisplayInfo(
                    paraid: "\(crowdloan.paraId)",
                    name: "Moonbase",
                    token: "UNIT",
                    description: "Test crowdloan",
                    website: "https://example.com",
                    icon: "https://example.com/icon.png",
                    rewardRate: 5,
                    endingBlock: nil,
                    disabled: nil,
                    flow: .bifrost
                )
            )
        )
        presenter.didReceiveAccountInfo(
            result: .success(
                AccountInfo(
                    nonce: 0,
                    consumers: 0,
                    providers: 1,
                    data: AccountData(
                        free: 20_000_000_000_000,
                        reserved: 0,
                        frozen: 0
                    )
                )
            )
        )
        presenter.didReceiveBlockNumber(result: .success(10))
        presenter.didReceiveBlockDuration(result: .success(6))
        presenter.didReceiveLeasingPeriod(result: .success(100))
        presenter.didReceiveLeasingOffset(result: .success(0))
        presenter.didReceiveMinimumBalance(result: .success(1_000_000_000))
        presenter.didReceiveMinimumContribution(result: .success(1_000_000_000))

        if includeFee {
            presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 500_000_000)))
        }
    }
}

private final class CrowdloanContributionSetupInteractorInputSpy: CrowdloanContributionSetupInteractorInputProtocol {
    private(set) var didSetup = false
    var feeRequests: [(amount: BigUInt, bonusService: CrowdloanBonusServiceProtocol?)] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(for amount: BigUInt, bonusService: CrowdloanBonusServiceProtocol?) {
        feeRequests.append((amount, bonusService))
    }
}

private final class CrowdloanContributionSetupViewSpy: CrowdloanContributionSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var assetViewModel: AssetBalanceViewModelProtocol?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var inputViewModel: IAmountInputViewModel?
    private(set) var crowdloanViewModel: CrowdloanContributionSetupViewModel?
    private(set) var estimatedRewardViewModel: String?
    private(set) var bonusViewModel: String?

    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        feeViewModel = viewModel
    }

    func didReceiveInput(viewModel: IAmountInputViewModel) {
        inputViewModel = viewModel
    }

    func didReceiveCrowdloan(viewModel: CrowdloanContributionSetupViewModel) {
        crowdloanViewModel = viewModel
    }

    func didReceiveEstimatedReward(viewModel: String?) {
        estimatedRewardViewModel = viewModel
    }

    func didReceiveBonus(viewModel: String?) {
        bonusViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class CrowdloanContributionSetupWireframeSpy: CrowdloanContributionSetupWireframeProtocol {
    private(set) var confirmationParaId: ParaId?
    private(set) var confirmationAmount: Decimal?
    private(set) weak var confirmationBonusService: CrowdloanBonusServiceProtocol?
    private(set) var didPresentFeeNotReceived = false
    private(set) var webURL: URL?
    private(set) var webStyle: WebPresentableStyle?
    private(set) var additionalBonusAmount: Decimal?
    private(set) weak var additionalBonusDelegate: CustomCrowdloanDelegate?
    private(set) weak var additionalBonusExistingService: CrowdloanBonusServiceProtocol?
    var shouldHandlePresentedError = true

    func showConfirmation(
        from _: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    ) {
        confirmationParaId = paraId
        confirmationAmount = inputAmount
        confirmationBonusService = bonusService
    }

    func showAdditionalBonus(
        from _: CrowdloanContributionSetupViewProtocol?,
        for _: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        additionalBonusAmount = inputAmount
        additionalBonusDelegate = delegate
        additionalBonusExistingService = existingService
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style: WebPresentableStyle) {
        webURL = url
        webStyle = style
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        shouldHandlePresentedError
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentFeeNotReceived = true
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentExsitentialDepositNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentExistentialDepositError(
        existentianDepositValue _: String,
        from _: ControllerBackedProtocol,
        locale _: Locale?
    ) {}

    func presentExistentialDepositWarning(
        existentianDepositValue _: String,
        from _: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale _: Locale?
    ) {
        action()
    }

    func presentExistentialDepositWarning(
        existentianDepositValue _: String,
        from _: ControllerBackedProtocol,
        proceedHandler: @escaping () -> Void,
        setMaxHandler _: @escaping () -> Void,
        cancelHandler _: @escaping () -> Void,
        locale _: Locale?
    ) {
        proceedHandler()
    }

    func presentSoraBridgeLowAmountError(
        from _: ControllerBackedProtocol,
        locale _: Locale,
        assetAmount _: String
    ) {}

    func presentWarning(
        for _: String,
        message _: String,
        action: @escaping () -> Void,
        view _: ControllerBackedProtocol,
        locale _: Locale?
    ) {
        action()
    }

    func presentDestinationExistentialDepositError(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentMinimalBalanceContributionError(_: String, from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentCapReachedError(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentAmountExceedsCapError(_: String, from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentCrowdloanEnded(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentCrowdloanPrivateNotSupported(from _: ControllerBackedProtocol, locale _: Locale?) {}

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

private final class CrowdloanDataValidatorFactorySpy: CrowdloanDataValidatorFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?
    let basePresentable: BaseErrorPresentable

    init(basePresentable: BaseErrorPresentable) {
        self.basePresentable = basePresentable
    }

    func contributesAtLeastMinContribution(
        contribution _: BigUInt?,
        minimumBalance _: BigUInt?,
        locale _: Locale
    ) -> DataValidating {
        SucceedDataValidating()
    }

    func capNotExceeding(
        contribution _: BigUInt?,
        raised _: BigUInt?,
        cap _: BigUInt?,
        locale _: Locale
    ) -> DataValidating {
        SucceedDataValidating()
    }

    func crowdloanIsNotCompleted(
        crowdloan _: Crowdloan?,
        metadata _: CrowdloanMetadata?,
        displayInfo _: CrowdloanDisplayInfo?,
        locale _: Locale
    ) -> DataValidating {
        SucceedDataValidating()
    }

    func crowdloanIsNotPrivate(
        crowdloan _: Crowdloan?,
        locale _: Locale
    ) -> DataValidating {
        SucceedDataValidating()
    }
}

private final class CrowdloanContributionViewModelFactorySpy: CrowdloanContributionViewModelFactoryProtocol {
    func createContributionSetupViewModel(
        from _: Crowdloan,
        displayInfo _: CrowdloanDisplayInfo?,
        metadata _: CrowdloanMetadata,
        locale _: Locale
    ) -> CrowdloanContributionSetupViewModel {
        CrowdloanContributionSetupViewModel(
            title: "Moonbase setup",
            leasingPeriod: "90 days",
            leasingCompletionDate: "Till May 30, 2026",
            raisedProgress: "1 / 9",
            raisedPercentage: "11%",
            remainedTime: "7 days",
            learnMore: LearnMoreViewModel(iconViewModel: nil, title: "Learn")
        )
    }

    func createContributionConfirmViewModel(
        from _: Crowdloan,
        metadata _: CrowdloanMetadata,
        confirmationData _: CrowdloanContributionConfirmData,
        locale _: Locale
    ) throws -> CrowdloanContributeConfirmViewModel {
        CrowdloanContributeConfirmViewModel(
            senderIcon: DrawableIconStub(),
            senderName: "",
            inputAmount: "",
            leasingPeriod: "",
            leasingCompletionDate: ""
        )
    }

    func createEstimatedRewardViewModel(
        inputAmount: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> String? {
        "estimated:\(inputAmount)"
    }

    func createAdditionalBonusViewModel(
        inputAmount: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        bonusRate: Decimal?,
        locale _: Locale
    ) -> String? {
        "bonus:\(bonusRate?.description ?? "nil"):\(inputAmount)"
    }

    func createLearnMoreViewModel(
        from _: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> LearnMoreViewModel {
        LearnMoreViewModel(iconViewModel: nil, title: "")
    }
}

private final class SetupCrowdloanBonusServiceStub: CrowdloanBonusServiceProtocol {
    let bonusRate: Decimal
    let termsURL: URL? = URL(string: "https://example.com/terms")
    private(set) var referralCode: String?

    init(bonusRate: Decimal) {
        self.bonusRate = bonusRate
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

private struct DrawableIconStub: DrawableIcon {
    func drawInContext(_: CGContext, fillColor _: UIColor, size _: CGSize) {}
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
