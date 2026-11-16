import XCTest
@testable import fearless

final class CovCABSEPRecordingController: UIViewController {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABSEPView: ControllerBackedProtocol {
    let recorder = CovCABSEPRecordingController()
    var isSetup: Bool { true }
    var controller: UIViewController { recorder }
}

final class CovCABSEPPresenter: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    private(set) var sheetViewModels: [SheetAlertPresentableViewModel] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheetViewModels.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

final class CovCABStakingErrorPresentableTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]
    private var presenter: CovCABSEPPresenter!
    private var view: CovCABSEPView!

    override func setUp() {
        super.setUp()
        presenter = CovCABSEPPresenter()
        view = CovCABSEPView()
    }

    override func tearDown() {
        presenter = nil
        view = nil
        super.tearDown()
    }

    private func lastSheetModel(file: StaticString = #filePath, line: UInt = #line) throws -> SheetAlertPresentableViewModel {
        let presented = try XCTUnwrap(view.recorder.presentedControllers.last, file: file, line: line)
        let sheet = try XCTUnwrap(presented as? SheetAletViewController, file: file, line: line)
        let child = Mirror(reflecting: sheet).children.first { $0.label == "viewModel" }
        return try XCTUnwrap(child?.value as? SheetAlertPresentableViewModel, file: file, line: line)
    }

    private var errorTitle: String {
        R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages)
    }

    private var closeTitle: String {
        R.string.localizable.commonClose(preferredLanguages: languages)
    }

    func testAmountTooLowShowsValueInMessage() throws {
        presenter.presentAmountTooLow(value: "12.5 DOT", from: view, locale: locale)

        let model = try lastSheetModel()
        XCTAssertEqual(model.title, errorTitle)
        XCTAssertEqual(model.closeAction, closeTitle)
        XCTAssertTrue(model.message?.contains("12.5 DOT") == true)
        XCTAssertFalse(model.isInfo)
        XCTAssertTrue(model.actions.isEmpty)
    }

    func testMissingControllerAndStashMessagesContainAddress() throws {
        presenter.presentMissingController(from: view, address: "ctrl-address", locale: locale)
        let controllerModel = try lastSheetModel()
        XCTAssertEqual(controllerModel.title, errorTitle)
        XCTAssertEqual(
            controllerModel.message,
            R.string.localizable.stakingAddController("ctrl-address", preferredLanguages: languages)
        )

        presenter.presentMissingStash(from: view, address: "stash-address", locale: locale)
        let stashModel = try lastSheetModel()
        XCTAssertEqual(stashModel.title, errorTitle)
        XCTAssertEqual(
            stashModel.message,
            R.string.localizable.stakingStashMissingMessage("stash-address", preferredLanguages: languages)
        )
        XCTAssertEqual(view.recorder.presentedControllers.count, 2)
    }

    func testUnbondingAndRebondingTooHighUseInsufficientBalanceTitle() throws {
        let insufficientTitle = R.string.localizable.stakingErrorInsufficientBalanceTitle(preferredLanguages: languages)

        presenter.presentUnbondingTooHigh(from: view, locale: locale)
        let unbondModel = try lastSheetModel()
        XCTAssertEqual(unbondModel.title, insufficientTitle)
        XCTAssertEqual(unbondModel.message, R.string.localizable.stakingRedeemNoTokensMessage(preferredLanguages: languages))

        presenter.presentRebondingTooHigh(from: view, locale: locale)
        let rebondModel = try lastSheetModel()
        XCTAssertEqual(rebondModel.title, insufficientTitle)
        XCTAssertEqual(rebondModel.message, R.string.localizable.stakingRebondInsufficientBondings(preferredLanguages: languages))
        XCTAssertEqual(rebondModel.closeAction, closeTitle)
    }

    func testRewardIsLessThanFeeWarningRunsActionOnProceed() throws {
        var actionCalls = 0
        presenter.presentRewardIsLessThanFee(from: view, action: { actionCalls += 1 }, locale: locale)

        let model = try XCTUnwrap(presenter.sheetViewModels.last)
        XCTAssertEqual(model.title, R.string.localizable.commonConfirmationTitle(preferredLanguages: languages))
        XCTAssertEqual(model.message, R.string.localizable.stakingWarningTinyPayout(preferredLanguages: languages))
        XCTAssertEqual(model.closeAction, R.string.localizable.commonCancel(preferredLanguages: languages))
        XCTAssertEqual(model.actions.count, 1)
        XCTAssertEqual(model.actions.first?.title, R.string.localizable.commonProceed(preferredLanguages: languages))

        model.actions.first?.handler?()
        XCTAssertEqual(actionCalls, 1)
        XCTAssertTrue(view.recorder.presentedControllers.isEmpty)
    }

    func testControllerBalanceIsZeroWarning() throws {
        var actionCalls = 0
        presenter.presentControllerBalanceIsZero(from: view, action: { actionCalls += 1 }, locale: locale)

        let model = try XCTUnwrap(presenter.sheetViewModels.last)
        XCTAssertEqual(model.title, R.string.localizable.commonConfirmationTitle(preferredLanguages: languages))
        XCTAssertEqual(model.message, R.string.localizable.stakingControllerAccountZeroBalance(preferredLanguages: languages))
        model.actions.first?.handler?()
        XCTAssertEqual(actionCalls, 1)
    }

    func testStashKilledAfterUnbondWarning() throws {
        var actionCalls = 0
        presenter.presentStashKilledAfterUnbond(from: view, action: { actionCalls += 1 }, locale: locale)

        let model = try XCTUnwrap(presenter.sheetViewModels.last)
        XCTAssertEqual(model.title, R.string.localizable.stakingUnbondingAllTitle(preferredLanguages: languages))
        XCTAssertEqual(model.message, R.string.localizable.stakingUnbondingAllMessage(preferredLanguages: languages))
        model.actions.first?.handler?()
        XCTAssertEqual(actionCalls, 1)
    }

    func testDeselectValidatorsWarning() throws {
        var actionCalls = 0
        presenter.presentDeselectValidatorsWarning(from: view, action: { actionCalls += 1 }, locale: locale)

        let model = try XCTUnwrap(presenter.sheetViewModels.last)
        XCTAssertEqual(model.title, R.string.localizable.commonConfirmationTitle(preferredLanguages: languages))
        XCTAssertEqual(model.message, R.string.localizable.stakingCustomDeselectWarning(preferredLanguages: languages))
        model.actions.first?.handler?()
        XCTAssertEqual(actionCalls, 1)
    }

    func testUnbondingLimitNoRedeemablesAndControllerUsed() throws {
        presenter.presentUnbondingLimitReached(from: view, locale: locale)
        let limitModel = try lastSheetModel()
        XCTAssertEqual(limitModel.title, errorTitle)
        XCTAssertEqual(limitModel.message, R.string.localizable.stakingUnbondingLimitReachedTitle(preferredLanguages: languages))

        presenter.presentNoRedeemables(from: view, locale: locale)
        let redeemModel = try lastSheetModel()
        XCTAssertEqual(redeemModel.title, errorTitle)
        XCTAssertEqual(redeemModel.message, R.string.localizable.stakingRedeemNoTokensMessage(preferredLanguages: languages))

        presenter.presentControllerIsAlreadyUsed(from: view, locale: locale)
        let usedModel = try lastSheetModel()
        XCTAssertEqual(usedModel.title, errorTitle)
        XCTAssertEqual(usedModel.message, R.string.localizable.stakingAccountIsUsedAsController(preferredLanguages: languages))
        XCTAssertEqual(view.recorder.presentedControllers.count, 3)
    }

    func testOptionalViewVariantsDoNothingWithoutView() {
        presenter.presentUnbondingLimitReached(from: nil, locale: locale)
        presenter.presentNoRedeemables(from: nil, locale: locale)
        presenter.presentControllerIsAlreadyUsed(from: nil, locale: locale)
        presenter.presentMaxNumberOfNominatorsReached(from: nil, locale: locale)
        presenter.presentMissingPoolName(from: nil, locale: locale)
        presenter.presentMaximumPoolsCountReached(from: nil, locale: locale)

        XCTAssertTrue(view.recorder.presentedControllers.isEmpty)
        XCTAssertTrue(presenter.sheetViewModels.isEmpty)
    }

    func testMaxNominatorsReached() throws {
        presenter.presentMaxNumberOfNominatorsReached(from: view, locale: locale)

        let model = try lastSheetModel()
        XCTAssertEqual(model.title, R.string.localizable.stakingMaxNominatorsReachedTitle(preferredLanguages: languages))
        XCTAssertEqual(model.message, R.string.localizable.stakingMaxNominatorsReachedMessage(preferredLanguages: languages))
        XCTAssertEqual(model.closeAction, closeTitle)
    }

    func testPoolErrors() throws {
        presenter.presentMissingPoolName(from: view, locale: locale)
        let nameModel = try lastSheetModel()
        XCTAssertEqual(nameModel.title, R.string.localizable.stakingPoolCreateMissingNameTitle(preferredLanguages: languages))
        XCTAssertEqual(
            nameModel.message,
            R.string.localizable.stakingPoolCreateMissingNameDescription(preferredLanguages: languages)
        )

        presenter.presentPoolRootUnbondingTooHigh(minimalBond: "10 DOT", from: view, locale: locale)
        let rootModel = try lastSheetModel()
        XCTAssertEqual(rootModel.title, R.string.localizable.poolRootUnbondTooHighTitle(preferredLanguages: languages))
        XCTAssertEqual(rootModel.message, R.string.localizable.poolRootUnbondTooHighText("10 DOT", preferredLanguages: languages))

        presenter.presentMaximumPoolsCountReached(from: view, locale: locale)
        let poolsModel = try lastSheetModel()
        XCTAssertEqual(poolsModel.title, R.string.localizable.poolsLimitHasReachedErrorTitle(preferredLanguages: languages))
        XCTAssertEqual(poolsModel.message, R.string.localizable.poolsLimitHasReachedErrorMessage(preferredLanguages: languages))
        XCTAssertEqual(view.recorder.presentedControllers.count, 3)
    }
}
