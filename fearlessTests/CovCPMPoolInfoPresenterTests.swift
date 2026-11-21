import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPMInfoViewSpy: StakingPoolInfoViewInput {
    let hostController = UIViewController()
    private(set) var viewModels: [StakingPoolInfoViewModel] = []
    private(set) var statuses: [NominationViewStatus?] = []
    private(set) var startLoadingCount = 0
    private(set) var stopLoadingCount = 0

    var isSetup: Bool { true }
    var controller: UIViewController { hostController }
    var loadableContentView: UIView { hostController.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didStartLoading() { startLoadingCount += 1 }
    func didStopLoading() { stopLoadingCount += 1 }
    func didReceive(viewModel: StakingPoolInfoViewModel) { viewModels.append(viewModel) }
    func didReceive(status: NominationViewStatus?) { statuses.append(status) }
}

final class CovCPMInfoInteractorSpy: StakingPoolInfoInteractorInput {
    private(set) var setupCount = 0
    private(set) var nominationRequests: [(accountId: AccountId, era: EraIndex)] = []

    func setup(with _: StakingPoolInfoInteractorOutput) { setupCount += 1 }
    func fetchPoolNomination(poolStashAccountId: AccountId, activeEra: EraIndex) {
        nominationRequests.append((poolStashAccountId, activeEra))
    }
}

final class CovCPMInfoRouterSpy: StakingPoolInfoRouterInput {
    private(set) var dismissCount = 0
    private(set) var statusEvents: [ApplicationStatusAlertEvent] = []
    private(set) var selectValidatorsCount = 0
    private(set) var walletManagementTags: [Int] = []
    private(set) var walletManagementOutputs: [WalletsManagmentModuleOutput?] = []
    private(set) var updatedRoles: [(roles: StakingPoolRoles, poolId: String)] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated _: Bool) { statusEvents.append(viewModel) }
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}

    func proceedToSelectValidatorsStart(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: fearless.MetaAccountModel) {
        selectValidatorsCount += 1
    }

    func showWalletManagment(contextTag: Int, from _: ControllerBackedProtocol?, moduleOutput: WalletsManagmentModuleOutput?) {
        walletManagementTags.append(contextTag)
        walletManagementOutputs.append(moduleOutput)
    }

    func showUpdateRoles(
        roles: StakingPoolRoles,
        poolId: String,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        updatedRoles.append((roles, poolId))
    }
}

final class CovCPMInfoLoggerSpy: LoggerProtocol {
    private(set) var errors: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) { errors.append(message) }
    func customError(error: Error, file _: String, function _: String, line _: Int) { errors.append("\(error)") }
}

enum CovCPMInfoFixtures {
    struct CovCTestError: Error {}

    static func nomination(targets: [Data], submittedIn: UInt32) throws -> Nomination {
        let json: [String: Any] = [
            "targets": targets.map { $0.base64EncodedString() },
            "submittedIn": "\(submittedIn)"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    static func pool(
        id: String = "7",
        state: StakingPoolState = .open,
        roles: StakingPoolRoles,
        points: BigUInt = BigUInt(25_000_000_000)
    ) -> StakingPool {
        StakingPool(
            id: id,
            info: StakingPoolInfo(points: points, state: state, memberCounter: 3, roles: roles),
            name: "Fixture pool"
        )
    }
}

final class CovCPMPoolInfoPresenterTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var view: CovCPMInfoViewSpy!
    private var interactor: CovCPMInfoInteractorSpy!
    private var router: CovCPMInfoRouterSpy!
    private var logger: CovCPMInfoLoggerSpy!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        view = CovCPMInfoViewSpy()
        interactor = CovCPMInfoInteractorSpy()
        router = CovCPMInfoRouterSpy()
        logger = CovCPMInfoLoggerSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        view = nil
        interactor = nil
        router = nil
        logger = nil
        super.tearDown()
    }

    private func makePresenter(status: NominationViewStatus? = nil) throws -> StakingPoolInfoPresenter {
        let factory = StakingPoolInfoViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet)
        )
        return StakingPoolInfoPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: factory,
            chainAsset: chainAsset,
            logger: logger,
            wallet: wallet,
            status: status,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
    }

    private func rootRoles() -> StakingPoolRoles {
        StakingPoolRoles(
            depositor: Data(repeating: 1, count: 32),
            root: wallet.substrateAccountId,
            nominator: Data(repeating: 2, count: 32),
            bouncer: Data(repeating: 3, count: 32)
        )
    }

    func testDidLoadWithoutStatusSetsUpInteractorAndSendsNilStatus() throws {
        let presenter = try makePresenter()

        presenter.didLoad(view: view)

        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(view.statuses.count, 1)
        XCTAssertNil(view.statuses.first ?? nil)
        XCTAssertTrue(view.viewModels.isEmpty)
        XCTAssertTrue(interactor.nominationRequests.isEmpty)
    }

    func testDidLoadWithStatusForwardsIt() throws {
        let presenter = try makePresenter(status: .active(era: 4))

        presenter.didLoad(view: view)

        guard case let .active(era)? = view.statuses.last ?? nil else {
            return XCTFail("expected active status")
        }
        XCTAssertEqual(era, 4)
    }

    func testWillAppearStartsLoadingUntilViewModelIsProvided() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.willAppear(view: view)
        XCTAssertEqual(view.startLoadingCount, 1)

        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))
        presenter.didReceiveValidators(validators: .empty())
        XCTAssertEqual(view.stopLoadingCount, 1)

        presenter.willAppear(view: view)
        XCTAssertEqual(view.startLoadingCount, 1)
    }

    func testPoolPalletAndEraTriggerNominationFetchWithPoolStashAccount() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        let palletId = Data([0x70, 0x79, 0x2F, 0x6E, 0x6F, 0x70, 0x6C, 0x73])

        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))
        presenter.didReceive(palletIdResult: .success(palletId))
        XCTAssertTrue(interactor.nominationRequests.isEmpty)

        presenter.didReceive(activeEra: .success(ActiveEraInfo(index: 10)))

        let request = try XCTUnwrap(interactor.nominationRequests.last)
        XCTAssertEqual(request.era, 10)
        XCTAssertEqual(request.accountId.count, 32)
        XCTAssertEqual(Data(request.accountId.prefix(4)), "modl".data(using: .utf8))
        XCTAssertEqual(Data(request.accountId[request.accountId.startIndex + 4 ..< request.accountId.startIndex + 12]), palletId)
        XCTAssertEqual(request.accountId[request.accountId.startIndex + 12], PoolAccount.stash.rawValue)
        XCTAssertEqual(request.accountId[request.accountId.startIndex + 13], 7)
    }

    func testFailuresAreLogged() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceive(activeEra: .failure(CovCPMInfoFixtures.CovCTestError()))
        presenter.didReceive(palletIdResult: .failure(CovCPMInfoFixtures.CovCTestError()))
        presenter.didReceive(error: CovCPMInfoFixtures.CovCTestError())

        XCTAssertEqual(logger.errors.count, 3)
        XCTAssertTrue(interactor.nominationRequests.isEmpty)
    }

    func testViewModelForRootUserReflectsPool() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))
        presenter.didReceiveValidators(validators: .empty())

        let viewModel = try XCTUnwrap(view.viewModels.last)
        XCTAssertEqual(viewModel.indexTitle, "7")
        XCTAssertEqual(viewModel.name, "Fixture pool")
        XCTAssertEqual(viewModel.state, StakingPoolState.open.rawValue)
        XCTAssertEqual(viewModel.membersCountTitle, "3")
        XCTAssertEqual(viewModel.validatorsCountAttributedString?.string.hasPrefix("0"), true)
        XCTAssertTrue(viewModel.userIsRoot)
        XCTAssertFalse(viewModel.rolesChanged)
        XCTAssertEqual(viewModel.stakedAmountViewModel?.amount.contains("2.5"), true)
        XCTAssertEqual(
            viewModel.depositorName,
            try Data(repeating: 1, count: 32).toAddress(using: ChainFormat.substrate(0))
        )
        XCTAssertNotNil(viewModel.rootName)
        XCTAssertNotNil(viewModel.nominatorName)
        XCTAssertNotNil(viewModel.bouncerName)
    }

    func testStatusIsBuiltFromNominationAndEraStakers() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))

        presenter.didReceive(eraStakersInfo: EraStakersInfo(activeEra: 21, validators: []))
        guard case .validatorsNotSelected? = view.statuses.last ?? nil else {
            return XCTFail("expected validatorsNotSelected")
        }

        presenter.didReceive(nomination: try CovCPMInfoFixtures.nomination(targets: [Data(repeating: 9, count: 32)], submittedIn: 3))
        guard case let .active(era)? = view.statuses.last ?? nil else {
            return XCTFail("expected active status")
        }
        XCTAssertEqual(era, 21)
    }

    func testStatusWithoutPoolIsNotSent() throws {
        let presenter = try makePresenter(status: .undefined)
        presenter.didLoad(view: view)
        let initialCount = view.statuses.count

        presenter.didReceive(eraStakersInfo: EraStakersInfo(activeEra: 1, validators: []))
        presenter.didReceive(nomination: nil)

        XCTAssertEqual(view.statuses.count, initialCount)
    }

    func testRouterActions() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didTapCloseButton()
        presenter.didTapValidators()
        presenter.nominatorDidTapped()
        presenter.bouncerDidTapped()
        presenter.rootDidTapped()
        presenter.copyAddressTapped()

        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(router.selectValidatorsCount, 1)
        XCTAssertEqual(router.walletManagementTags, [0, 1, 2])
        XCTAssertTrue(router.walletManagementOutputs.allSatisfy { $0 === presenter })
        XCTAssertEqual(router.statusEvents.count, 1)
        XCTAssertTrue(router.statusEvents.first is AddressCopiedEvent)
    }

    func testSaveRolesRequiresPool() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.saveRolesDidTapped()
        XCTAssertTrue(router.updatedRoles.isEmpty)

        let roles = rootRoles()
        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(id: "11", roles: roles))
        presenter.saveRolesDidTapped()

        XCTAssertEqual(router.updatedRoles.count, 1)
        XCTAssertEqual(router.updatedRoles.first?.poolId, "11")
        XCTAssertEqual(router.updatedRoles.first?.roles, roles)
    }

    func testSelectedWalletEditsRolesAndMarksThemChanged() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))
        presenter.didReceiveValidators(validators: .empty())
        let other = AccountGenerator.generateMetaAccount()
        let otherAddress = try XCTUnwrap(other.substrateAccountId).toAddress(using: ChainFormat.substrate(0))

        presenter.selectedWallet(other, for: 0)
        XCTAssertEqual(view.viewModels.last?.nominatorName, otherAddress)
        XCTAssertEqual(view.viewModels.last?.rolesChanged, true)

        presenter.selectedWallet(other, for: 1)
        XCTAssertEqual(view.viewModels.last?.bouncerName, otherAddress)

        presenter.selectedWallet(other, for: 2)
        XCTAssertEqual(view.viewModels.last?.rootName, otherAddress)
        XCTAssertEqual(view.viewModels.last?.userIsRoot, true)

        let count = view.viewModels.count
        presenter.selectedWallet(other, for: 99)
        XCTAssertEqual(view.viewModels.count, count)

        presenter.saveRolesDidTapped()
        XCTAssertEqual(router.updatedRoles.last?.roles.root, other.substrateAccountId)
    }

    func testModuleInputStatusChangeAndLocalization() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        presenter.didReceive(stakingPool: CovCPMInfoFixtures.pool(roles: rootRoles()))
        presenter.didReceiveValidators(validators: .empty())
        let count = view.viewModels.count

        presenter.didChange(status: .inactive(era: 2))
        presenter.applyLocalization()

        guard case let .inactive(era)? = view.statuses.last ?? nil else {
            return XCTFail("expected inactive status")
        }
        XCTAssertEqual(era, 2)
        XCTAssertEqual(view.viewModels.count, count + 1)
    }
}
