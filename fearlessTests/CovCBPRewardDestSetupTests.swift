import XCTest
import BigInt
import SSFModels
import SSFUtils
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovCBPRDSCalculatorStub: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal = 1
    var validatorReturns: [Data: Decimal] = [:]
    var throwsForValidators = false

    func calculateEarnings(amount: Decimal, validatorAccountId: AccountId, isCompound: Bool, period _: CalculationPeriod) throws -> Decimal {
        if throwsForValidators { throw CommonError.undefined }
        let rate = validatorReturns[validatorAccountId] ?? 0.1
        return amount * rate * (isCompound ? 2 : 1)
    }

    func calculateMaxEarnings(amount: Decimal, isCompound: Bool, period _: CalculationPeriod) -> Decimal {
        amount * (isCompound ? 0.2 : 0.1)
    }

    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount * 0.05 }

    func calculatorReturn(isCompound: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        isCompound ? 0.2 : 0.1
    }

    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}

final class CovCBPRDSViewDouble: StakingRewardDestSetupViewProtocol {
    let backing = UIViewController()
    var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    var destinations: [ChangeRewardDestinationViewModel?] = []

    var isSetup: Bool { true }
    var controller: UIViewController { backing }

    func applyLocalization() {}
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) { fees.append(viewModel) }
    func didReceiveRewardDestination(viewModel: ChangeRewardDestinationViewModel?) { destinations.append(viewModel) }
}

final class CovCBPRDSWireframeDouble: StakingRewardDestSetupWireframeProtocol {
    var webURLs: [URL] = []
    var proceeded: [RewardDestination<AccountAddress>] = []
    var selections: [(count: Int, selected: fearless.ChainAccountResponse?)] = []

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) { webURLs.append(url) }

    func proceed(
        view _: StakingRewardDestSetupViewProtocol?,
        rewardDestination: RewardDestination<fearless.ChainAccountResponse>,
        asset _: AssetModel,
        chain _: ChainModel,
        selectedAccount _: fearless.MetaAccountModel
    ) {
        proceeded.append(rewardDestination.accountAddress)
    }

    func presentAccountSelection(
        _ accounts: [fearless.ChainAccountResponse],
        selectedAccountItem: fearless.ChainAccountResponse?,
        title _: LocalizableResource<String>,
        delegate _: ModalPickerViewControllerDelegate,
        from _: ControllerBackedProtocol?,
        context _: AnyObject?
    ) {
        selections.append((accounts.count, selectedAccountItem))
    }

    func dismiss(view _: ControllerBackedProtocol?) {}
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovCBPRDSInteractorDouble: StakingRewardDestSetupInteractorInputProtocol {
    var setupCount = 0
    var fetchAccountsCount = 0
    var estimated: [RewardDestination<AccountAddress>] = []

    func setup() { setupCount += 1 }
    func estimateFee(rewardDestination: RewardDestination<AccountAddress>) { estimated.append(rewardDestination) }
    func fetchPayoutAccounts() { fetchAccountsCount += 1 }
}

final class CovCBPRDSChangeFactoryStub: ChangeRewardDestinationViewModelFactoryProtocol {
    var requests: [(original: RewardDestination<AccountAddress>, bonded: Decimal, hasNomination: Bool)] = []

    func createViewModel(
        from originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination _: RewardDestination<fearless.ChainAccountResponse>?,
        bondedAmount: Decimal,
        calculator _: RewardCalculatorEngineProtocol,
        nomination: Nomination?,
        priceData _: PriceData?
    ) -> ChangeRewardDestinationViewModel? {
        requests.append((originalRewardDestination, bondedAmount, nomination != nil))
        let selection = LocalizableResource<RewardDestinationViewModelProtocol> { _ in
            RewardDestinationViewModel(rewardViewModel: nil, type: .restake)
        }
        return ChangeRewardDestinationViewModel(selectionViewModel: selection, canApply: true)
    }
}

final class CovCBPRewardDestSetupTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()
    private let validatorA = Data(repeating: 1, count: 32)
    private let validatorB = Data(repeating: 2, count: 32)

    private var balanceFactory: BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
    }

    private func account() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
    }

    private func makeLedger(active: String) throws -> StakingLedger {
        let stash = "0x" + String(repeating: "01", count: 32)
        let json = "{\"stash\":\"\(stash)\",\"total\":\"\(active)\",\"active\":\"\(active)\",\"unlocking\":[]}"
        return try JSONDecoder().decode(StakingLedger.self, from: Data(json.utf8))
    }

    private func makeNomination(targets: [Data]) throws -> Nomination {
        let hexTargets = targets.map { "\"0x" + $0.map { String(format: "%02x", $0) }.joined() + "\"" }.joined(separator: ",")
        let json = "{\"targets\":[\(hexTargets)],\"submittedIn\":\"5\"}"
        return try JSONDecoder().decode(Nomination.self, from: Data(json.utf8))
    }

    private func address(_ byte: UInt8) throws -> String {
        try SS58AddressFactory().address(fromAccountId: Data(repeating: byte, count: 32), type: 0)
    }

    // MARK: - ChangeRewardDestinationViewModelFactory

    private func makeChangeFactory() -> ChangeRewardDestinationViewModelFactory {
        let rewardFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator(),
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )
        return ChangeRewardDestinationViewModelFactory(rewardDestinationViewModelFactory: rewardFactory)
    }

    func testChangeFactoryMaxReturnForOriginalRestake() throws {
        let viewModel = try XCTUnwrap(makeChangeFactory().createViewModel(
            from: .restake,
            selectedRewardDestination: nil,
            bondedAmount: 100,
            calculator: CovCBPRDSCalculatorStub(),
            nomination: nil,
            priceData: nil
        ))

        XCTAssertFalse(viewModel.canApply)
        let selection = viewModel.selectionViewModel.value(for: locale)
        guard case .restake = selection.type else { return XCTFail("restake expected") }
        let reward = try XCTUnwrap(selection.rewardViewModel)
        XCTAssertEqual(reward.restakeAmount, balanceFactory.balanceFromPrice(20, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)
        XCTAssertEqual(reward.payoutAmount, balanceFactory.balanceFromPrice(10, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)
        XCTAssertTrue(reward.restakeAvailable)
    }

    func testChangeFactoryOriginalPayoutAndSelectedDestinations() throws {
        let payoutAddress = try address(4)
        let factory = makeChangeFactory()

        let original = try XCTUnwrap(factory.createViewModel(
            from: .payout(account: payoutAddress),
            selectedRewardDestination: nil,
            bondedAmount: 10,
            calculator: CovCBPRDSCalculatorStub(),
            nomination: nil,
            priceData: nil
        ))
        guard case let .payout(_, title, originalAddress) = original.selectionViewModel.value(for: locale).type else {
            return XCTFail("payout expected")
        }
        XCTAssertEqual(title, payoutAddress)
        XCTAssertEqual(originalAddress, payoutAddress)

        let selectedPayout = try XCTUnwrap(factory.createViewModel(
            from: .restake,
            selectedRewardDestination: .payout(account: try account()),
            bondedAmount: 10,
            calculator: CovCBPRDSCalculatorStub(),
            nomination: nil,
            priceData: nil
        ))
        XCTAssertTrue(selectedPayout.canApply)
        guard case let .payout(_, selectedTitle, _) = selectedPayout.selectionViewModel.value(for: locale).type else {
            return XCTFail("payout expected")
        }
        XCTAssertEqual(selectedTitle, wallet.name)

        let selectedRestake = try XCTUnwrap(factory.createViewModel(
            from: .restake,
            selectedRewardDestination: .restake,
            bondedAmount: 10,
            calculator: CovCBPRDSCalculatorStub(),
            nomination: nil,
            priceData: nil
        ))
        XCTAssertFalse(selectedRestake.canApply)
    }

    func testChangeFactoryUsesBestNominatedValidator() throws {
        let calculator = CovCBPRDSCalculatorStub()
        calculator.validatorReturns = [validatorA: 0.05, validatorB: 0.3]
        calculator.rewardAssetRate = 2

        let viewModel = try XCTUnwrap(makeChangeFactory().createViewModel(
            from: .restake,
            selectedRewardDestination: nil,
            bondedAmount: 10,
            calculator: calculator,
            nomination: try makeNomination(targets: [validatorA, validatorB]),
            priceData: nil
        ))

        let reward = try XCTUnwrap(viewModel.selectionViewModel.value(for: locale).rewardViewModel)
        XCTAssertEqual(reward.restakeAmount, balanceFactory.balanceFromPrice(12, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)
        XCTAssertEqual(reward.payoutAmount, balanceFactory.balanceFromPrice(6, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)
    }

    func testChangeFactoryFallsBackWhenValidatorReturnsFail() throws {
        let calculator = CovCBPRDSCalculatorStub()
        calculator.throwsForValidators = true

        let viewModel = try XCTUnwrap(makeChangeFactory().createViewModel(
            from: .restake,
            selectedRewardDestination: nil,
            bondedAmount: 50,
            calculator: calculator,
            nomination: try makeNomination(targets: [validatorA]),
            priceData: nil
        ))

        let reward = try XCTUnwrap(viewModel.selectionViewModel.value(for: locale).rewardViewModel)
        XCTAssertEqual(reward.restakeAmount, balanceFactory.balanceFromPrice(10, priceData: nil, usageCase: .listCrypto).value(for: locale).amount)
    }

    // MARK: - Presenter

    private struct CovCEnv {
        let presenter: StakingRewardDestSetupPresenter
        let view: CovCBPRDSViewDouble
        let wireframe: CovCBPRDSWireframeDouble
        let interactor: CovCBPRDSInteractorDouble
        let factory: CovCBPRDSChangeFactoryStub
    }

    private func makeEnv() -> CovCEnv {
        let wireframe = CovCBPRDSWireframeDouble()
        let interactor = CovCBPRDSInteractorDouble()
        let factory = CovCBPRDSChangeFactoryStub()
        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: factory,
            balanceViewModelFactory: balanceFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            asset: asset,
            selectedAccount: wallet,
            rewardChainAsset: nil,
            logger: nil
        )
        let view = CovCBPRDSViewDouble()
        presenter.view = view
        return CovCEnv(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, factory: factory)
    }

    func testSetupProvidesEmptyStateAndLearnMore() {
        let env = makeEnv()

        env.presenter.setup()
        XCTAssertEqual(env.view.destinations.count, 1)
        XCTAssertNil(env.view.destinations.first ?? nil)
        XCTAssertEqual(env.view.fees.count, 1)
        XCTAssertNil(env.view.fees.first ?? nil)
        XCTAssertEqual(env.interactor.setupCount, 1)

        env.presenter.displayLearnMore()
        XCTAssertEqual(env.wireframe.webURLs, [ApplicationConfig.shared.learnPayoutURL])

        env.presenter.selectPayoutDestination()
        XCTAssertTrue(env.interactor.estimated.isEmpty)
    }

    func testInteractorOutputsBuildRewardDestination() throws {
        let env = makeEnv()
        let calculator = CovCBPRDSCalculatorStub()

        env.presenter.didReceiveStakingLedger(result: .success(try makeLedger(active: "200000000000")))
        env.presenter.didReceiveCalculator(result: .success(calculator))
        XCTAssertTrue(env.factory.requests.isEmpty)

        env.presenter.didReceiveRewardDestinationAccount(result: .success(.restake))
        XCTAssertEqual(env.factory.requests.count, 1)
        XCTAssertEqual(env.factory.requests.last?.bonded, 20)
        XCTAssertEqual(env.interactor.estimated, [.restake])
        XCTAssertNotNil(env.view.destinations.last ?? nil)

        env.presenter.didReceiveNomination(result: .success(try makeNomination(targets: [validatorA])))
        XCTAssertEqual(env.factory.requests.last?.hasNomination, true)

        env.presenter.didReceiveRewardDestinationAddress(result: .success(.payout(account: "5Somewhere")))
        XCTAssertEqual(env.factory.requests.last?.original, .payout(account: "5Somewhere"))

        env.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        XCTAssertNotNil(env.view.fees.last ?? nil)

        let failures: [Error] = [CommonError.undefined]
        for error in failures {
            env.presenter.didReceiveFee(result: .failure(error))
            env.presenter.didReceiveStashItem(result: .failure(error))
            env.presenter.didReceiveController(result: .failure(error))
            env.presenter.didReceiveStash(result: .failure(error))
            env.presenter.didReceiveStakingLedger(result: .failure(error))
            env.presenter.didReceiveRewardDestinationAccount(result: .failure(error))
            env.presenter.didReceiveRewardDestinationAddress(result: .failure(error))
            env.presenter.didReceiveCalculator(result: .failure(error))
            env.presenter.didReceiveAccounts(result: .failure(error))
            env.presenter.didReceiveNomination(result: .failure(error))
            env.presenter.didReceiveAccountInfo(result: .failure(error))
        }
        XCTAssertTrue(env.wireframe.selections.isEmpty)
        XCTAssertEqual(env.factory.requests.count, 3)
    }

    func testSelectionsAndProceed() throws {
        let env = makeEnv()
        let stash = try account()

        env.presenter.didReceiveStash(result: .success(stash))
        env.presenter.didReceiveController(result: .success(stash))
        env.presenter.didReceiveStashItem(result: .success(StashItem(stash: stash.toAddress() ?? "", controller: stash.toAddress() ?? "")))

        env.presenter.selectPayoutDestination()
        XCTAssertEqual(env.interactor.estimated.last, .payout(account: stash.toAddress() ?? ""))

        env.presenter.selectRestakeDestination()
        XCTAssertEqual(env.interactor.estimated.last, .restake)

        env.presenter.selectPayoutAccount()
        XCTAssertEqual(env.interactor.fetchAccountsCount, 1)
        XCTAssertEqual(env.interactor.estimated.count, 3)

        env.presenter.didReceiveAccounts(result: .success([stash]))
        XCTAssertEqual(env.wireframe.selections.count, 1)
        XCTAssertEqual(env.wireframe.selections.first?.count, 1)

        env.presenter.modalPickerDidSelectModelAtIndex(0, context: PrimitiveContextWrapper(value: [stash]))
        XCTAssertEqual(env.interactor.estimated.last, .payout(account: stash.toAddress() ?? ""))
        env.presenter.modalPickerDidSelectModelAtIndex(0, context: nil)
        XCTAssertEqual(env.interactor.estimated.count, 4)

        env.presenter.proceed()
        XCTAssertTrue(env.wireframe.proceeded.isEmpty)

        env.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        env.presenter.didReceiveAccountInfo(result: .success(
            AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 100_000_000_000, reserved: 0, frozen: 0))
        ))
        env.presenter.proceed()
        XCTAssertEqual(env.wireframe.proceeded, [.payout(account: stash.toAddress() ?? "")])

        env.presenter.didReceiveAccountInfo(result: .success(nil))
        env.presenter.proceed()
        XCTAssertEqual(env.wireframe.proceeded.count, 1)
    }

    func testSelectPayoutFallsBackToController() throws {
        let env = makeEnv()
        let controller = try account()

        env.presenter.didReceiveStash(result: .success(nil))
        env.presenter.didReceiveController(result: .success(controller))
        env.presenter.selectPayoutDestination()

        XCTAssertEqual(env.interactor.estimated, [.payout(account: controller.toAddress() ?? "")])
        XCTAssertEqual(env.view.destinations.count, 1)
    }
}
