import BigInt
import FearlessFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CrowdloanContributionConfirmTests: XCTestCase {
    func testSetup_whenInteractorDataArrives_thenProvidesViewModelsAndEstimatesFee() throws {
        let fixture = try makeFixture(inputAmount: 1.25, bonusRate: 0.1)

        fixture.presenter.setup()
        fixture.emitReadyState()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.interactor.estimatedFeeAmounts, [1_250_000_000_000])
        XCTAssertNotNil(fixture.view.assetViewModel)
        XCTAssertNotNil(fixture.view.feeViewModel)
        XCTAssertEqual(fixture.view.estimatedRewardViewModel, "estimated reward")
        XCTAssertEqual(fixture.view.bonusViewModel, "bonus")
        XCTAssertEqual(fixture.view.crowdloanViewModel?.senderName, "Alice")
        XCTAssertEqual(fixture.viewModelFactory.confirmViewModelInputs.first?.paraId, fixture.crowdloan.paraId)
    }

    func testConfirm_whenValidationPasses_thenStartsLoadingAndSubmitsContribution() throws {
        let fixture = try makeFixture(inputAmount: 2)
        fixture.emitReadyState()

        fixture.presenter.confirm()

        XCTAssertTrue(fixture.view.didStartLoadingCalled)
        XCTAssertEqual(fixture.interactor.submittedContributions, [2_000_000_000_000])
    }

    func testConfirm_whenFeeMissing_thenRefreshesFeeAndDoesNotSubmit() throws {
        let fixture = try makeFixture(inputAmount: 3)
        fixture.emitReadyState(includeFee: false)

        fixture.presenter.confirm()

        XCTAssertTrue(fixture.interactor.submittedContributions.isEmpty)
        XCTAssertEqual(fixture.interactor.estimatedFeeAmounts, [3_000_000_000_000])
        XCTAssertTrue(fixture.wireframe.didPresentFeeNotReceived)
    }

    func testSubmissionResult_whenSuccess_thenStopsLoadingAndCompletes() throws {
        let fixture = try makeFixture()

        fixture.presenter.didSubmitContribution(result: .success("0xhash"))

        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertTrue(fixture.wireframe.completedView === fixture.view)
    }

    func testSubmissionResult_whenUnhandledFailure_thenPresentsFallbackError() throws {
        let fixture = try makeFixture()
        fixture.wireframe.shouldHandlePresentedError = false

        fixture.presenter.didSubmitContribution(result: .failure(TestError.expected))

        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertTrue(fixture.wireframe.presentedError is TestError)
        XCTAssertTrue(fixture.wireframe.didPresentExtrinsicFailed)
    }

    func testPresentAccountOptions_whenAddressKnown_thenRoutesToWireframe() throws {
        let fixture = try makeFixture()

        fixture.presenter.presentAccountOptions()
        XCTAssertNil(fixture.wireframe.accountOptionsAddress)

        fixture.presenter.didReceiveDisplayAddress(
            result: .success(DisplayAddress(address: "5Alice", username: "Alice"))
        )
        fixture.presenter.presentAccountOptions()

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, "5Alice")
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
    }

    private func makeFixture(
        inputAmount: Decimal = 1,
        bonusRate: Decimal? = nil
    ) throws -> CrowdloanContributionConfirmFixture {
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
        let interactor = CrowdloanContributionConfirmInteractorInputSpy()
        let wireframe = CrowdloanContributionConfirmWireframeSpy()
        let validatorFactory = CrowdloanDataValidatorFactorySpy(basePresentable: wireframe)
        let viewModelFactory = CrowdloanContributionViewModelFactorySpy()
        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            contributionViewModelFactory: viewModelFactory,
            dataValidatingFactory: validatorFactory,
            inputAmount: inputAmount,
            bonusRate: bonusRate,
            assetInfo: asset.displayInfo(with: chain.icon),
            localizationManager: LocalizationManager.shared,
            logger: LoggerSpy(),
            chainAsset: chainAsset,
            selectedCurrency: Currency.defaultCurrency()
        )
        let view = CrowdloanContributionConfirmViewSpy()
        presenter.view = view
        validatorFactory.view = view

        return CrowdloanContributionConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            crowdloan: try makeCrowdloan()
        )
    }

    private func makeCrowdloan() throws -> Crowdloan {
        let depositor = Data(repeating: 1, count: 32)
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

private struct CrowdloanContributionConfirmFixture {
    let presenter: CrowdloanContributionConfirmPresenter
    let interactor: CrowdloanContributionConfirmInteractorInputSpy
    let wireframe: CrowdloanContributionConfirmWireframeSpy
    let view: CrowdloanContributionConfirmViewSpy
    let viewModelFactory: CrowdloanContributionViewModelFactorySpy
    let chainAsset: ChainAsset
    let crowdloan: Crowdloan

    func emitReadyState(includeFee: Bool = true) {
        presenter.didReceiveDisplayAddress(
            result: .success(DisplayAddress(address: "5Alice", username: "Alice"))
        )
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
                    flow: nil
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

private final class CrowdloanContributionConfirmInteractorInputSpy: CrowdloanContributionConfirmInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimatedFeeAmounts: [BigUInt] = []
    private(set) var submittedContributions: [BigUInt] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(for amount: BigUInt, bonusService _: CrowdloanBonusServiceProtocol?) {
        estimatedFeeAmounts.append(amount)
    }

    func estimateFee(for contribution: BigUInt) {
        estimatedFeeAmounts.append(contribution)
    }

    func submit(contribution: BigUInt) {
        submittedContributions.append(contribution)
    }
}

private final class CrowdloanContributionConfirmViewSpy: CrowdloanContributionConfirmViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var assetViewModel: AssetBalanceViewModelProtocol?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var crowdloanViewModel: CrowdloanContributeConfirmViewModel?
    private(set) var estimatedRewardViewModel: String?
    private(set) var bonusViewModel: String?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        feeViewModel = viewModel
    }

    func didReceiveCrowdloan(viewModel: CrowdloanContributeConfirmViewModel) {
        crowdloanViewModel = viewModel
    }

    func didReceiveEstimatedReward(viewModel: String?) {
        estimatedRewardViewModel = viewModel
    }

    func didReceiveBonus(viewModel: String?) {
        bonusViewModel = viewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class CrowdloanContributionConfirmWireframeSpy: CrowdloanContributionConfirmWireframeProtocol {
    weak var completedView: CrowdloanContributionConfirmViewProtocol?
    private(set) var presentedError: Error?
    private(set) var didPresentExtrinsicFailed = false
    private(set) var didPresentFeeNotReceived = false
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?
    var shouldHandlePresentedError = true

    func complete(on view: CrowdloanContributionConfirmViewProtocol?) {
        completedView = view
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return shouldHandlePresentedError
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionsAddress = address
        accountOptionsChainId = chain.chainId
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentFeeNotReceived = true
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentExtrinsicFailed = true
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentExsitentialDepositNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
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
    private(set) var confirmViewModelInputs: [(paraId: ParaId, contribution: Decimal)] = []

    func createContributionSetupViewModel(
        from _: Crowdloan,
        displayInfo _: CrowdloanDisplayInfo?,
        metadata _: CrowdloanMetadata,
        locale _: Locale
    ) -> CrowdloanContributionSetupViewModel {
        CrowdloanContributionSetupViewModel(
            title: "",
            leasingPeriod: "",
            leasingCompletionDate: "",
            raisedProgress: "",
            raisedPercentage: "",
            remainedTime: "",
            learnMore: nil
        )
    }

    func createContributionConfirmViewModel(
        from crowdloan: Crowdloan,
        metadata _: CrowdloanMetadata,
        confirmationData: CrowdloanContributionConfirmData,
        locale _: Locale
    ) throws -> CrowdloanContributeConfirmViewModel {
        confirmViewModelInputs.append((crowdloan.paraId, confirmationData.contribution))

        return CrowdloanContributeConfirmViewModel(
            senderIcon: DrawableIconStub(),
            senderName: confirmationData.displayAddress.username,
            inputAmount: "\(confirmationData.contribution)",
            leasingPeriod: "90 days",
            leasingCompletionDate: "Till May 30, 2026"
        )
    }

    func createEstimatedRewardViewModel(
        inputAmount _: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> String? {
        "estimated reward"
    }

    func createAdditionalBonusViewModel(
        inputAmount _: Decimal,
        displayInfo _: CrowdloanDisplayInfo,
        bonusRate _: Decimal?,
        locale _: Locale
    ) -> String? {
        "bonus"
    }

    func createLearnMoreViewModel(
        from _: CrowdloanDisplayInfo,
        locale _: Locale
    ) -> LearnMoreViewModel {
        LearnMoreViewModel(iconViewModel: nil, title: "")
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

private enum TestError: Error {
    case expected
}
