import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAValidatorInfoViewStub: UIViewController, ValidatorInfoViewProtocol {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }

    private(set) var states: [ValidatorInfoState] = []

    func didRecieve(state: ValidatorInfoState) {
        states.append(state)
    }

    func applyLocalization() {}
}

final class CovAValidatorInfoWireframeStub: ValidatorInfoWireframeProtocol {
    var emailResult = false
    private(set) var webURLs: [URL] = []
    private(set) var emails: [SocialMessage] = []
    private(set) var messages: [(message: String?, title: String)] = []
    private(set) var infos: [String?] = []
    private(set) var accountOptionAddresses: [String] = []
    private(set) var stakingAmounts: [[LocalizableResource<StakingAmountViewModel>]] = []

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webURLs.append(url)
    }

    func writeEmail(
        with message: SocialMessage,
        from _: ControllerBackedProtocol,
        completionHandler _: EmailComposerCompletion?
    ) -> Bool {
        emails.append(message)
        return emailResult
    }

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append((message, title))
    }

    func presentInfo(message: String?, title _: String, from _: ControllerBackedProtocol?) {
        infos.append(message)
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain _: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionAddresses.append(address)
    }

    func showStakingAmounts(from _: ValidatorInfoViewProtocol?, items: [LocalizableResource<StakingAmountViewModel>]) {
        stakingAmounts.append(items)
    }
}

final class CovAValidatorInfoStrategySpy: ValidatorInfoStrategy {
    private(set) var setupCount = 0
    private(set) var reloadCount = 0

    func setup() {
        setupCount += 1
    }

    func reload() {
        reloadCount += 1
    }
}

final class CovAValidatorInfoPresenterSpy: ValidatorInfoPresenterProtocol {
    private(set) var calls: [String] = []
    private(set) var identityValues: [ValidatorInfoViewModel.IdentityItemValue] = []

    func setup() {
        calls.append("setup")
    }

    func reload() {
        calls.append("reload")
    }

    func presentAccountOptions() {
        calls.append("account")
    }

    func presentTotalStake() {
        calls.append("total")
    }

    func presentMinStake() {
        calls.append("min")
    }

    func presentIdentityItem(_ value: ValidatorInfoViewModel.IdentityItemValue) {
        calls.append("identity")
        identityValues.append(value)
    }
}

final class CovAValidatorInfoStateListenerSpy: ValidatorInfoModelStateListener {
    private(set) var changes = 0
    private(set) var loadings = 0
    private(set) var errors: [Error] = []

    func modelStateDidChanged(viewModelState _: ValidatorInfoViewModelState) {
        changes += 1
    }

    func didStartLoading() {
        loadings += 1
    }

    func didReceiveError(error: Error) {
        errors.append(error)
    }
}

final class CovAValidatorInfoTests: XCTestCase {
    private let locale = CovAFixtures.locale

    private func relaychainState(_ info: ValidatorInfoProtocol?) -> ValidatorInfoRelaychainViewModelState {
        let state = ValidatorInfoRelaychainViewModelState()
        if let info = info {
            state.didReceiveValidatorInfo(info)
        }
        return state
    }

    private func poolState(_ info: ValidatorInfoProtocol?) -> ValidatorInfoPoolViewModelState {
        let state = ValidatorInfoPoolViewModelState()
        if let info = info {
            state.didReceiveValidatorInfo(info)
        }
        return state
    }

    private func factories() -> [ValidatorInfoViewModelFactoryProtocol] {
        let balance = CovAFixtures.balanceFactory()
        return [
            ValidatorInfoRelaychainViewModelFactory(iconGenerator: UniversalIconGenerator(), balanceViewModelFactory: balance),
            ValidatorInfoPoolViewModelFactory(iconGenerator: UniversalIconGenerator(), balanceViewModelFactory: balance)
        ]
    }

    private func states(_ info: ValidatorInfoProtocol?) -> [ValidatorInfoViewModelState] {
        [relaychainState(info), poolState(info)]
    }

    // MARK: - View model factories

    func testElectedValidatorBuildsExposureIdentityAndAccount() throws {
        let identity = CovAFixtures.identity(parent: "Parent")
        let validator = CovAFixtures.validator(
            1,
            identity: identity,
            myNomination: .active(allocation: ValidatorTokenAllocation(amount: 5, isRewarded: false)),
            commission: 0.1,
            hasSlashes: true
        )
        for (factory, state) in zip(factories(), states(validator)) {
            let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: locale))
            XCTAssertEqual(viewModel.account.address, validator.address)
            XCTAssertEqual(viewModel.account.name, "Parent / Validator One")
            XCTAssertNotNil(viewModel.account.icon)
            XCTAssertTrue(viewModel.staking.slashed)
            XCTAssertFalse(viewModel.title.isEmpty)
            guard case let .elected(exposure) = viewModel.staking.status else {
                return XCTFail("expected elected")
            }
            XCTAssertTrue(exposure.nominators.contains("3"))
            XCTAssertTrue(exposure.nominators.contains("2"))
            XCTAssertEqual(exposure.myNomination?.isRewarded, false)
            XCTAssertTrue(exposure.oversubscribed)
            XCTAssertTrue(exposure.totalStake.amount.contains("100"))
            XCTAssertTrue(exposure.estimatedReward.contains("15"))
            if factory is ValidatorInfoRelaychainViewModelFactory {
                XCTAssertTrue(exposure.comission.contains("10.00"), exposure.comission)
            } else {
                XCTAssertFalse(exposure.comission.isEmpty)
            }
            // the two best nominators are rewarded; the smaller of them is the minimum stake
            XCTAssertTrue(try XCTUnwrap(exposure.minStakeToGetRewards).amount.contains("20"))
            let items = try XCTUnwrap(viewModel.identity)
            XCTAssertEqual(items.count, 5)
            guard case let .text(legal) = items[0].value else { return XCTFail("legal is text") }
            XCTAssertEqual(legal, "Legal Name")
            guard case let .link(email, emailTag) = items[1].value else { return XCTFail("email is a link") }
            XCTAssertEqual(email, "validator@example.com")
            XCTAssertEqual(emailTag, .email)
            guard case let .link(_, webTag) = items[2].value, case let .link(_, twitterTag) = items[3].value,
                  case let .link(_, riotTag) = items[4].value else {
                return XCTFail("links expected")
            }
            XCTAssertEqual(webTag, .web)
            XCTAssertEqual(twitterTag, .twitter)
            XCTAssertEqual(items[3].title, "Twitter")
            XCTAssertEqual(riotTag, .riot)
        }
    }

    func testValidatorWithoutStakeInfoIsUnelectedWithCommission() throws {
        let validator = CovAFixtures.validator(2, stakeInfo: nil, commission: 0.07)
        for (factory, state) in zip(factories(), states(validator)) {
            let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: locale))
            XCTAssertNil(viewModel.identity)
            XCTAssertEqual(viewModel.account.name, "")
            guard case let .unelected(commission) = viewModel.staking.status else {
                return XCTFail("expected unelected")
            }
            XCTAssertTrue(try XCTUnwrap(commission).contains("7"))
        }
    }

    func testRelaychainFactoryTreatsNotElectedValidatorAsUnelectedButPoolDoesNot() throws {
        let validator = CovAFixtures.validator(3, myNomination: .elected, elected: false)
        let relaychain = try XCTUnwrap(
            factories()[0].buildViewModel(viewModelState: relaychainState(validator), priceData: nil, locale: locale)
        )
        let pool = try XCTUnwrap(factories()[1].buildViewModel(viewModelState: poolState(validator), priceData: nil, locale: locale))
        if case .elected = relaychain.staking.status {
            XCTFail("relaychain must show unelected")
        }
        guard case let .elected(exposure) = pool.staking.status else { return XCTFail("pool shows the exposure") }
        XCTAssertNil(exposure.myNomination)
    }

    func testFactoriesReturnNilForForeignOrEmptyState() {
        let factories = factories()
        let validator = CovAFixtures.validator(4)
        XCTAssertNil(factories[0].buildViewModel(viewModelState: poolState(validator), priceData: nil, locale: locale))
        XCTAssertNil(factories[1].buildViewModel(viewModelState: relaychainState(validator), priceData: nil, locale: locale))
        XCTAssertNil(factories[0].buildViewModel(viewModelState: relaychainState(nil), priceData: nil, locale: locale))
        XCTAssertNil(factories[1].buildViewModel(viewModelState: poolState(nil), priceData: nil, locale: locale))
        XCTAssertNil(factories[0].buildStakingAmountViewModels(viewModelState: poolState(validator), priceData: nil))
        XCTAssertNil(factories[1].buildStakingAmountViewModels(viewModelState: relaychainState(nil), priceData: nil))
    }

    func testStakingAmountsSplitOwnAndNominatorStake() throws {
        let validator = CovAFixtures.validator(5)
        let price = PriceData(currencyId: "usd", priceId: "cov", price: "2", fiatDayChange: nil, coingeckoPriceId: nil)
        for (factory, state) in zip(factories(), states(validator)) {
            let rows = try XCTUnwrap(factory.buildStakingAmountViewModels(viewModelState: state, priceData: price))
            XCTAssertEqual(rows.count, 3)
            let values = rows.map { $0.value(for: locale) }
            XCTAssertTrue(values[0].balance.amount.contains("40"))
            XCTAssertTrue(values[1].balance.amount.contains("60"))
            XCTAssertTrue(values[2].balance.amount.contains("100"))
            XCTAssertNotNil(values[2].balance.price)
            XCTAssertEqual(Set(values.map(\.title)).count, 3)
        }
    }

    // MARK: - States and strategies

    func testViewModelStatesForwardEventsToListener() {
        let validator = CovAFixtures.validator(6)
        for state in [relaychainState(nil), poolState(nil)] as [ValidatorInfoViewModelState] {
            let listener = CovAValidatorInfoStateListenerSpy()
            state.setStateListener(listener)
            XCTAssertNil(state.validatorAddress)
            if let relay = state as? ValidatorInfoRelaychainViewModelState {
                relay.didStartLoading()
                relay.didReceiveValidatorInfo(validator)
                relay.didReceiveError(CovATestError.failed)
            } else if let pool = state as? ValidatorInfoPoolViewModelState {
                pool.didStartLoading()
                pool.didReceiveValidatorInfo(validator)
                pool.didReceiveError(CovATestError.failed)
            }
            XCTAssertEqual(state.validatorAddress, validator.address)
            XCTAssertEqual(listener.loadings, 1)
            XCTAssertEqual(listener.changes, 1)
            XCTAssertEqual(listener.errors.count, 1)
        }
    }

    func testStrategiesDeliverKnownValidatorImmediately() {
        let validator = CovAFixtures.validator(7)
        let chainAsset = CovAFixtures.chainAsset()
        let factory = CovAValidatorOperationFactoryStub()
        let relayOutput = ValidatorInfoRelaychainViewModelState()
        let poolOutput = ValidatorInfoPoolViewModelState()
        let relay = ValidatorInfoRelaychainStrategy(
            validatorInfo: validator, accountAddress: nil, wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
            validatorOperationFactory: factory, operationManager: OperationManager(), output: relayOutput
        )
        let pool = ValidatorInfoPoolStrategy(
            validatorInfo: validator, accountAddress: nil, wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
            validatorOperationFactory: factory, operationManager: OperationManager(), output: poolOutput
        )
        relay.setup()
        pool.reload()
        XCTAssertEqual(relayOutput.validatorAddress, validator.address)
        XCTAssertEqual(poolOutput.validatorAddress, validator.address)
        XCTAssertTrue(factory.wannabeRequests.isEmpty)
    }

    func testStrategiesReportErrorWithoutAddress() {
        let chainAsset = CovAFixtures.chainAsset()
        let listener = CovAValidatorInfoStateListenerSpy()
        let relayOutput = ValidatorInfoRelaychainViewModelState()
        relayOutput.setStateListener(listener)
        let poolOutput = ValidatorInfoPoolViewModelState()
        poolOutput.setStateListener(listener)
        let relay = ValidatorInfoRelaychainStrategy(
            validatorInfo: nil, accountAddress: "not-an-address", wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
            validatorOperationFactory: CovAValidatorOperationFactoryStub(), operationManager: OperationManager(),
            output: relayOutput
        )
        let pool = ValidatorInfoPoolStrategy(
            validatorInfo: nil, accountAddress: nil, wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
            validatorOperationFactory: CovAValidatorOperationFactoryStub(), operationManager: OperationManager(),
            output: poolOutput
        )
        relay.setup()
        pool.setup()
        XCTAssertEqual(listener.errors.count, 2)
        XCTAssertEqual(listener.loadings, 0)
    }

    func testStrategiesFetchWannabeValidatorAndFallBackToBareInfo() {
        let chainAsset = CovAFixtures.chainAsset()
        let address = CovAFixtures.address(8)
        let found = CovAFixtures.validator(8, commission: 0.2)
        let factory = CovAValidatorOperationFactoryStub()
        factory.selectedResult = [found]
        let emptyFactory = CovAValidatorOperationFactoryStub()
        let failingFactory = CovAValidatorOperationFactoryStub()
        failingFactory.error = CovATestError.failed

        var outputs: [(ValidatorInfoViewModelState, CovAValidatorInfoStateListenerSpy)] = []
        var strategies: [ValidatorInfoStrategy] = []
        for (index, opFactory) in [factory, emptyFactory, failingFactory].enumerated() {
            let listener = CovAValidatorInfoStateListenerSpy()
            if index % 2 == 0 {
                let output = ValidatorInfoRelaychainViewModelState()
                output.setStateListener(listener)
                outputs.append((output, listener))
                strategies.append(ValidatorInfoRelaychainStrategy(
                    validatorInfo: nil, accountAddress: address, wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
                    validatorOperationFactory: opFactory, operationManager: OperationManager(), output: output
                ))
            } else {
                let output = ValidatorInfoPoolViewModelState()
                output.setStateListener(listener)
                outputs.append((output, listener))
                strategies.append(ValidatorInfoPoolStrategy(
                    validatorInfo: nil, accountAddress: address, wallet: CovAFixtures.wallet(), chainAsset: chainAsset,
                    validatorOperationFactory: opFactory, operationManager: OperationManager(), output: output
                ))
            }
        }
        strategies.forEach { $0.setup() }
        CovAViewInspector.spin(until: { outputs.allSatisfy { $0.1.changes + $0.1.errors.count > 0 } })

        XCTAssertEqual(factory.wannabeRequests.first, [CovAFixtures.accountId(8)])
        XCTAssertEqual(outputs[0].1.loadings, 1)
        XCTAssertEqual(outputs[0].1.changes, 1)
        XCTAssertEqual((outputs[0].0 as? ValidatorInfoRelaychainViewModelState)?.validatorInfo?.commission, 0.2)
        XCTAssertEqual(outputs[1].1.changes, 1)
        XCTAssertEqual(outputs[1].0.validatorAddress, address)
        XCTAssertEqual((outputs[1].0 as? ValidatorInfoPoolViewModelState)?.validatorInfo?.commission, 0)
        XCTAssertEqual(outputs[2].1.errors.count, 1)
        XCTAssertEqual(outputs[2].1.changes, 0)
    }

    func testInteractorBaseForwardsToStrategy() {
        let strategy = CovAValidatorInfoStrategySpy()
        let interactor = ValidatorInfoInteractorBase(chainAsset: CovAFixtures.chainAsset(), strategy: strategy)
        interactor.setup()
        interactor.reload()
        interactor.reload()
        XCTAssertEqual(strategy.setupCount, 1)
        XCTAssertEqual(strategy.reloadCount, 2)
    }
}
