import XCTest
import BigInt
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHSendValidatingFactoryTests: XCTestCase {
    // The factory holds its view weakly; keep it alive for the whole test.
    private var retainedView: CovHSendValidationView?

    override func tearDown() {
        retainedView = nil
        super.tearDown()
    }

    private func run(_ validator: DataValidating) -> Bool {
        var passed = false
        DataValidationRunner(validators: [validator]).runValidation { passed = true }
        return passed
    }

    private func makeFactory(withView: Bool = true) -> (SendDataValidatingFactory, CovHSendValidationPresentable, CovHSendValidationView) {
        let presentable = CovHSendValidationPresentable()
        let factory = SendDataValidatingFactory(presentable: presentable)
        let view = CovHSendValidationView()
        if withView {
            factory.view = view
            retainedView = view
        }
        return (factory, presentable, view)
    }

    func testAmountAndFeeChecksReportWhatIsMissing() {
        let (factory, presentable, _) = makeFactory()
        let locale = Locale(identifier: "en")
        XCTAssertFalse(run(factory.canPayFeeAndAmount(balanceType: .utility(balance: nil), feeAndTip: 1, sendAmount: 1, locale: locale)))
        XCTAssertFalse(run(factory.canPayFeeAndAmount(balanceType: .orml(balance: 5, utilityBalance: nil), feeAndTip: 1, sendAmount: 1, locale: locale)))
        XCTAssertTrue(run(factory.canPayFeeAndAmount(balanceType: .orml(balance: 5, utilityBalance: 2), feeAndTip: 1, sendAmount: 1, locale: locale)))
        XCTAssertEqual(presentable.calls, ["amountTooHigh", "amountTooHigh"])

        var retried = 0
        XCTAssertFalse(run(factory.has(fee: nil, locale: locale) { retried += 1 }))
        XCTAssertEqual(retried, 1)
        XCTAssertEqual(presentable.calls.last, "feeNotReceived")
    }

    func testChecksWithoutAViewStayQuiet() {
        let (factory, presentable, _) = makeFactory(withView: false)
        let locale = Locale(identifier: "en")
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Quiet", assetUtility: true)
        XCTAssertFalse(run(factory.canPayFeeAndAmount(balanceType: .utility(balance: 0), feeAndTip: 1, sendAmount: 1, locale: locale)))
        var retried = 0
        XCTAssertFalse(run(factory.has(fee: nil, locale: locale) { retried += 1 }))
        XCTAssertEqual(retried, 1, "The fee is requested again even without a screen")
        XCTAssertFalse(run(factory.exsitentialDepositIsNotViolated(
            spending: 10, balance: 10, minimumBalance: 1, chainAsset: chainAsset, locale: locale,
            proceedAction: {}, setMaxAction: {}, cancelAction: {}
        )))
        XCTAssertTrue(presentable.calls.isEmpty)
    }

    func testDepositWarningCanAlsoBeAnError() {
        let (factory, presentable, _) = makeFactory()
        let locale = Locale(identifier: "en")
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Deposit", assetUtility: true)
        XCTAssertFalse(run(factory.exsitentialDepositIsNotViolated(
            spending: 10, balance: 10, minimumBalance: 1, chainAsset: chainAsset, locale: locale, canProceedIfViolated: false,
            proceedAction: {}, setMaxAction: {}, cancelAction: {}
        )))
        XCTAssertEqual(presentable.calls, ["depositError", "depositWarning"])
        XCTAssertTrue(presentable.depositValues.allSatisfy { $0.hasSuffix("AST") })

        let ethereum = ChainAsset(
            chain: CovHSendFixtures.chain(name: "Covh EVM", assets: [chainAsset.asset], options: [.ethereum]), asset: chainAsset.asset
        )
        XCTAssertTrue(run(factory.exsitentialDepositIsNotViolated(
            spending: 10, balance: 10, minimumBalance: 1, chainAsset: ethereum, locale: locale,
            proceedAction: {}, setMaxAction: {}, cancelAction: {}
        )))
        XCTAssertTrue(run(factory.destinationExistentialDepositIsNotViolated(willReceived: 0, minimumBalance: 1, locale: locale, chainAsset: ethereum)))
        XCTAssertFalse(run(factory.destinationExistentialDepositIsNotViolated(willReceived: 0, minimumBalance: 1, locale: locale, chainAsset: chainAsset)))
        XCTAssertEqual(presentable.calls.last, "destinationDeposit")
    }

    func testReviewedBridgeMinimum() throws {
        let harness = try CovHCrossChainHarness()
        let (factory, presentable, _) = makeFactory()
        let locale = Locale(identifier: "en")
        XCTAssertTrue(run(factory.reviewedBridgeMinimumIsNotViolated(
            amount: BigUInt(2_000_000_000_000), origin: harness.origin, destination: harness.sora, locale: locale
        )))
        XCTAssertFalse(run(factory.reviewedBridgeMinimumIsNotViolated(amount: 1, origin: harness.origin, destination: harness.sora, locale: locale)))
        XCTAssertEqual(presentable.lowAmounts, ["1.1 LLD"])

        XCTAssertFalse(run(factory.reviewedBridgeMinimumIsNotViolated(amount: nil, origin: harness.origin, destination: harness.sora, locale: locale)))
        XCTAssertFalse(run(factory.reviewedBridgeMinimumIsNotViolated(
            amount: BigUInt(2_000_000_000_000), origin: harness.origin, destination: nil, locale: locale
        )))
        XCTAssertEqual(presentable.sheets.count, 2, "A missing amount or destination stops the transfer with an explanation")
        XCTAssertEqual(presentable.lowAmounts, ["1.1 LLD"])
    }
}

final class CovHSendValidationView: UIViewController, ControllerBackedProtocol, Localizable {
    func applyLocalization() {}
}

final class CovHSendValidationPresentable: SheetAlertPresentable {
    var calls: [String] = []
    var depositValues: [String] = []
    var lowAmounts: [String] = []
    var sheets: [SheetAlertPresentableViewModel] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(message: String?, title: String, closeAction: String?, from _: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        sheets.append(SheetAlertPresentableViewModel(title: title, message: message, actions: actions, isInfo: false, closeAction: closeAction))
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("amountTooHigh") }
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("feeNotReceived") }
    func presentExsitentialDepositNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("depositNotReceived") }
    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("feeTooHigh") }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("failed") }
    func presentExistentialDepositWarning(
        existentianDepositValue: String, from _: ControllerBackedProtocol, action _: @escaping () -> Void, locale _: Locale?
    ) {
        calls.append("depositWarning")
        depositValues.append(existentianDepositValue)
    }

    func presentExistentialDepositWarning(
        existentianDepositValue: String, from _: ControllerBackedProtocol, proceedHandler _: @escaping () -> Void,
        setMaxHandler _: @escaping () -> Void, cancelHandler _: @escaping () -> Void, locale _: Locale?
    ) {
        calls.append("depositWarning")
        depositValues.append(existentianDepositValue)
    }

    func presentExistentialDepositError(existentianDepositValue: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        calls.append("depositError")
        depositValues.append(existentianDepositValue)
    }

    func presentSoraBridgeLowAmountError(from _: ControllerBackedProtocol, locale _: Locale, assetAmount: String) {
        lowAmounts.append(assetAmount)
    }

    func presentWarning(for _: String, message _: String, action _: @escaping () -> Void, view _: ControllerBackedProtocol, locale _: Locale?) {
        calls.append("warning")
    }

    func presentDestinationExistentialDepositError(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("destinationDeposit") }
}
