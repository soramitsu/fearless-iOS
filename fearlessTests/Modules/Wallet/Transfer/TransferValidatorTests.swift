import UIKit
import XCTest
import FearlessFoundation
import SSFModels
@testable import fearless

final class SendDataValidatingFactoryTests: XCTestCase {
    private let testLocale = Locale(identifier: "en_US")

    func testUtilityBalance_whenAmountAndFeeFit_thenValidationSucceeds() {
        let fixture = makeFixture()
        let validator = fixture.factory.canPayFeeAndAmount(
            balanceType: .utility(balance: 10),
            feeAndTip: 1,
            sendAmount: 9,
            locale: testLocale
        )

        assertValidation(validator, succeedsNotifying: DataValidatingDelegateSpy())
        XCTAssertTrue(fixture.presentable.presentations.isEmpty)
    }

    func testUtilityBalance_whenAmountAndFeeExceedBalance_thenShowsAmountError() {
        let fixture = makeFixture()
        let validator = fixture.factory.canPayFeeAndAmount(
            balanceType: .utility(balance: 10),
            feeAndTip: 1,
            sendAmount: 9.01,
            locale: testLocale
        )

        assertValidation(validator, failsWith: .error)
        XCTAssertEqual(fixture.presentable.presentations, [.amountTooHigh])
    }

    func testOrmlBalance_whenTokenAmountAndUtilityFeeFit_thenValidationSucceeds() {
        let fixture = makeFixture()
        let validator = fixture.factory.canPayFeeAndAmount(
            balanceType: .orml(balance: 5, utilityBalance: 0.5),
            feeAndTip: 0.5,
            sendAmount: 5,
            locale: testLocale
        )

        assertValidation(validator, succeedsNotifying: DataValidatingDelegateSpy())
        XCTAssertTrue(fixture.presentable.presentations.isEmpty)
    }

    func testOrmlBalance_whenUtilityFeeExceedsUtilityBalance_thenShowsAmountError() {
        let fixture = makeFixture()
        let validator = fixture.factory.canPayFeeAndAmount(
            balanceType: .orml(balance: 5, utilityBalance: 0.49),
            feeAndTip: 0.5,
            sendAmount: 5,
            locale: testLocale
        )

        assertValidation(validator, failsWith: .error)
        XCTAssertEqual(fixture.presentable.presentations, [.amountTooHigh])
    }

    func testMissingFee_whenValidated_thenShowsFeeErrorAndRunsRefreshHook() {
        let fixture = makeFixture()
        var didRequestFeeRefresh = false
        let validator = fixture.factory.has(fee: nil, locale: testLocale) {
            didRequestFeeRefresh = true
        }

        assertValidation(validator, failsWith: .error)
        XCTAssertTrue(didRequestFeeRefresh)
        XCTAssertEqual(fixture.presentable.presentations, [.feeNotReceived])
    }

    func testExistingFee_whenValidated_thenValidationSucceeds() {
        let fixture = makeFixture()
        var didRequestFeeRefresh = false
        let validator = fixture.factory.has(fee: 0.01, locale: testLocale) {
            didRequestFeeRefresh = true
        }

        assertValidation(validator, succeedsNotifying: DataValidatingDelegateSpy())
        XCTAssertFalse(didRequestFeeRefresh)
        XCTAssertTrue(fixture.presentable.presentations.isEmpty)
    }

    func testExistentialDeposit_whenRemainingBalanceBelowMinimum_thenWarnsAndOffersActions() {
        let fixture = makeFixture()
        var didProceed = false
        var didSetMax = false
        var didCancel = false
        let validator = fixture.factory.exsitentialDepositIsNotViolated(
            spending: 8,
            balance: 10,
            minimumBalance: 3,
            chainAsset: fixture.chainAsset,
            locale: testLocale,
            proceedAction: { didProceed = true },
            setMaxAction: { didSetMax = true },
            cancelAction: { didCancel = true }
        )

        assertValidation(validator, failsWith: .warning)
        XCTAssertEqual(fixture.presentable.presentations, [.existentialDepositWarning("3 DOT")])

        fixture.presentable.proceedHandler?()
        fixture.presentable.setMaxHandler?()
        fixture.presentable.cancelHandler?()

        XCTAssertTrue(didProceed)
        XCTAssertTrue(didSetMax)
        XCTAssertTrue(didCancel)
    }

    func testExistentialDeposit_whenSendAllIsEnabled_thenValidationSucceeds() {
        let fixture = makeFixture()
        let validator = fixture.factory.exsitentialDepositIsNotViolated(
            spending: 10,
            balance: 10,
            minimumBalance: 3,
            chainAsset: fixture.chainAsset,
            locale: testLocale,
            sendAllEnabled: true,
            proceedAction: {},
            setMaxAction: {},
            cancelAction: {}
        )

        assertValidation(validator, succeedsNotifying: DataValidatingDelegateSpy())
        XCTAssertTrue(fixture.presentable.presentations.isEmpty)
    }

    func testDestinationExistentialDeposit_whenReceivedAmountIsTooLow_thenShowsRecipientError() {
        let fixture = makeFixture()
        let validator = fixture.factory.destinationExistentialDepositIsNotViolated(
            willReceived: 0.9,
            minimumBalance: 1,
            locale: testLocale,
            chainAsset: fixture.chainAsset
        )

        assertValidation(validator, failsWith: .warning)
        XCTAssertEqual(fixture.presentable.presentations, [.destinationExistentialDepositError])
    }

    func testSoraBridgeFeeWarning_whenSoraToKusamaAmountDoesNotCoverFee_thenWarnsAndResumes() {
        let fixture = makeFixture()
        let validator = fixture.factory.soraBridgeAmountLessFeeViolated(
            originCHainId: Chain.soraMain.genesisHash,
            destChainId: Chain.kusama.genesisHash,
            amount: 0.9,
            fee: 1,
            locale: testLocale
        )

        let delegate = DataValidatingDelegateSpy()
        assertValidation(validator, failsWith: .warning, notifying: delegate)
        XCTAssertEqual(fixture.presentable.presentations, [.warning])
        fixture.presentable.warningAction?()
        XCTAssertTrue(delegate.didCompleteWarningHandlingCalled)
    }

    private func makeFixture() -> SendDataValidatingFactoryFixture {
        let presentable = BaseErrorPresentableSpy()
        let factory = SendDataValidatingFactory(presentable: presentable)
        let view = TransferValidationViewSpy()
        factory.view = view

        return SendDataValidatingFactoryFixture(
            factory: factory,
            presentable: presentable,
            view: view,
            chainAsset: Self.makeChainAsset()
        )
    }

    private static func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            id: "dot",
            name: "DOT",
            symbol: "dot",
            precision: 10,
            isUtility: true,
            isNative: true,
            type: .normal
        )

        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: Chain.polkadot.genesisHash,
            paraId: nil,
            name: Chain.polkadot.rawValue,
            assets: [asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "wss://polkadot.example")!,
                    name: "Polkadot",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func assertValidation(
        _ validator: DataValidating,
        succeedsNotifying delegate: DataValidatingDelegate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let problem = validator.validate(notifying: delegate)
        guard problem == nil else {
            XCTFail("Expected validation to succeed, got \(String(describing: problem))", file: file, line: line)
            return
        }
    }

    private func assertValidation(
        _ validator: DataValidating,
        failsWith expectedProblem: DataValidationProblem,
        notifying delegate: DataValidatingDelegate = DataValidatingDelegateSpy(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let problem = validator.validate(notifying: delegate)

        switch (problem, expectedProblem) {
        case (.error?, .error), (.warning?, .warning):
            return
        default:
            XCTFail(
                "Expected \(expectedProblem), got \(String(describing: problem))",
                file: file,
                line: line
            )
        }
    }
}

final class ErrorViolationTests: XCTestCase {
    func testErrorConditionViolation_whenConditionIsPreserved_thenSucceedsWithoutCallingError() {
        var didCallError = false
        let validator = ErrorConditionViolation(
            onError: { didCallError = true },
            preservesCondition: { true }
        )

        XCTAssertNil(validator.validate(notifying: DataValidatingDelegateSpy()))
        XCTAssertFalse(didCallError)
    }

    func testErrorConditionViolation_whenConditionFails_thenCallsErrorAndReturnsError() {
        var didCallError = false
        let validator = ErrorConditionViolation(
            onError: { didCallError = true },
            preservesCondition: { false }
        )

        XCTAssertEqual(validator.validate(notifying: DataValidatingDelegateSpy()), .error)
        XCTAssertTrue(didCallError)
    }

    func testErrorThrowingViolation_whenNoErrorText_thenSucceedsWithoutCallingError() {
        var receivedErrorText: String?
        let validator = ErrorThrowingViolation(
            onError: { receivedErrorText = $0 },
            preservesCondition: { nil }
        )

        XCTAssertNil(validator.validate(notifying: DataValidatingDelegateSpy()))
        XCTAssertNil(receivedErrorText)
    }

    func testErrorThrowingViolation_whenErrorTextExists_thenPassesTextAndReturnsError() {
        var receivedErrorText: String?
        let validator = ErrorThrowingViolation(
            onError: { receivedErrorText = $0 },
            preservesCondition: { "Invalid amount" }
        )

        XCTAssertEqual(validator.validate(notifying: DataValidatingDelegateSpy()), .error)
        XCTAssertEqual(receivedErrorText, "Invalid amount")
    }
}

private struct SendDataValidatingFactoryFixture {
    let factory: SendDataValidatingFactory
    let presentable: BaseErrorPresentableSpy
    let view: TransferValidationViewSpy
    let chainAsset: ChainAsset
}

private final class TransferValidationViewSpy: ControllerBackedProtocol, Localizable {
    let controller = UIViewController()
    let isSetup = true

    func applyLocalization() {}
}

private final class BaseErrorPresentableSpy: BaseErrorPresentable {
    enum Presentation: Equatable {
        case amountTooHigh
        case feeNotReceived
        case existentialDepositWarning(String)
        case existentialDepositError(String)
        case destinationExistentialDepositError
        case warning
        case other
    }

    private(set) var presentations: [Presentation] = []
    private(set) var warningAction: (() -> Void)?
    private(set) var proceedHandler: (() -> Void)?
    private(set) var setMaxHandler: (() -> Void)?
    private(set) var cancelHandler: (() -> Void)?

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        presentations.append(.amountTooHigh)
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        presentations.append(.feeNotReceived)
    }

    func presentExsitentialDepositNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        presentations.append(.other)
    }

    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        presentations.append(.other)
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        presentations.append(.other)
    }

    func presentExistentialDepositWarning(
        existentianDepositValue: String,
        from _: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale _: Locale?
    ) {
        presentations.append(.existentialDepositWarning(existentianDepositValue))
        warningAction = action
    }

    func presentExistentialDepositWarning(
        existentianDepositValue: String,
        from _: ControllerBackedProtocol,
        proceedHandler: @escaping () -> Void,
        setMaxHandler: @escaping () -> Void,
        cancelHandler: @escaping () -> Void,
        locale _: Locale?
    ) {
        presentations.append(.existentialDepositWarning(existentianDepositValue))
        self.proceedHandler = proceedHandler
        self.setMaxHandler = setMaxHandler
        self.cancelHandler = cancelHandler
    }

    func presentExistentialDepositError(
        existentianDepositValue: String,
        from _: ControllerBackedProtocol,
        locale _: Locale?
    ) {
        presentations.append(.existentialDepositError(existentianDepositValue))
    }

    func presentSoraBridgeLowAmountError(
        from _: ControllerBackedProtocol,
        locale _: Locale,
        assetAmount _: String
    ) {
        presentations.append(.other)
    }

    func presentWarning(
        for _: String,
        message _: String,
        action: @escaping () -> Void,
        view _: ControllerBackedProtocol,
        locale _: Locale?
    ) {
        presentations.append(.warning)
        warningAction = action
    }

    func presentDestinationExistentialDepositError(
        from _: ControllerBackedProtocol,
        locale _: Locale?
    ) {
        presentations.append(.destinationExistentialDepositError)
    }
}

private final class DataValidatingDelegateSpy: DataValidatingDelegate {
    private(set) var didCompleteWarningHandlingCalled = false

    func didCompleteWarningHandling() {
        didCompleteWarningHandlingCalled = true
    }
}
