import BigInt
import SSFUtils
import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovBAnValidatorsInteractorStub: AnalyticsValidatorsInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var reloadCalls = 0

    func setup() { setupCalls += 1 }
    func reload() { reloadCalls += 1 }
}

final class CovBAnValidatorsWireframeStub: AnalyticsValidatorsWireframeProtocol {
    private(set) var shownAddresses: [AccountAddress] = []

    func showValidatorInfo(
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow: ValidatorInfoFlow,
        view _: ControllerBackedProtocol?
    ) {
        if case let .relaychain(_, address) = flow, let address = address {
            shownAddresses.append(address)
        }
    }
}

final class CovBAnValidatorsOutputStub: AnalyticsValidatorsInteractorOutputProtocol {
    private(set) var identities: [Result<[AccountAddress: AccountIdentity], Error>] = []
    private(set) var eraInfos: [Result<[SubqueryEraValidatorInfo]?, Error>] = []
    private(set) var stashes: [Result<AccountAddress?, Error>] = []
    private(set) var rewards: [Result<[SubqueryRewardItemData], Error>] = []
    private(set) var nominations: [Result<Nomination?, Error>] = []
    private(set) var eraRanges: [EraRange] = []

    func didReceive(identitiesByAddressResult: Result<[AccountAddress: AccountIdentity], Error>) {
        identities.append(identitiesByAddressResult)
    }

    func didReceive(eraValidatorInfosResult: Result<[SubqueryEraValidatorInfo]?, Error>) { eraInfos.append(eraValidatorInfosResult) }
    func didReceive(stashAddressResult: Result<AccountAddress?, Error>) { stashes.append(stashAddressResult) }
    func didReceive(rewardsResult: Result<[SubqueryRewardItemData], Error>) { rewards.append(rewardsResult) }
    func didReceive(nominationResult: Result<Nomination?, Error>) { nominations.append(nominationResult) }
    func didReceive(eraRange: EraRange) { eraRanges.append(eraRange) }
}

final class CovBAnValidatorsModuleTests: XCTestCase {
    private struct CovBAnModule {
        let chain: ChainModel
        let interactor: CovBAnValidatorsInteractorStub
        let wireframe: CovBAnValidatorsWireframeStub
        let factory: AnalyticsValidatorsViewModelFactory
        let presenter: AnalyticsValidatorsPresenter
        let view: AnalyticsValidatorsViewController
        let window: UIWindow
        let first: AccountAddress
        let second: AccountAddress
        let nomination: Nomination

        var table: UITableView { view.rootView.tableView }
        var header: AnalyticsValidatorsHeaderView { view.rootView.headerView }

        // Inspect exposed Objective-C properties to avoid the SDK/pod Charts module name collision.
        private func chart() throws -> UIView {
            try XCTUnwrap(header.subviews.first { $0.responds(to: NSSelectorFromString("centerAttributedText")) })
        }

        func centerText() throws -> String? {
            (try chart().value(forKey: "centerAttributedText") as? NSAttributedString)?.string
        }

        func segmentCount() throws -> Int? {
            try chart().value(forKeyPath: "data.entryCount") as? Int
        }

        func selectedSegment() throws -> Double? {
            let highlights = try chart().value(forKey: "highlighted") as? [NSObject]
            return highlights?.first?.value(forKey: "x") as? Double
        }
    }

    private var locale: Locale { CovBAnFixtures.locale }

    private func makeModule() throws -> CovBAnModule {
        let chainAsset = CovBAnFixtures.chainAsset()
        let firstId = Data(repeating: 0x11, count: 32)
        let secondId = Data(repeating: 0x22, count: 32)
        let first = try AddressFactory.address(for: firstId, chain: chainAsset.chain)
        let second = try AddressFactory.address(for: secondId, chain: chainAsset.chain)
        let interactor = CovBAnValidatorsInteractorStub()
        let wireframe = CovBAnValidatorsWireframeStub()
        let factory = AnalyticsValidatorsViewModelFactory(
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            iconGenerator: UniversalIconGenerator()
        )
        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            localizationManager: LocalizationManager.shared,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            selectedAccount: CovBAnFixtures.wallet()
        )
        let view = AnalyticsValidatorsViewController(presenter: presenter)
        presenter.view = view
        let window = CovBAnFixtures.host(view)
        return CovBAnModule(
            chain: chainAsset.chain,
            interactor: interactor,
            wireframe: wireframe,
            factory: factory,
            presenter: presenter,
            view: view,
            window: window,
            first: first,
            second: second,
            nomination: try CovBAnFixtures.nomination(targets: [firstId, secondId])
        )
    }

    private func deliverAll(to module: CovBAnModule) throws {
        module.presenter.didReceive(stashAddressResult: .success(CovBAnFixtures.stash))
        module.presenter.didReceive(rewardsResult: .success([
            CovBAnFixtures.reward("a", daysAgo: 1, amount: 300, validator: module.first),
            CovBAnFixtures.reward("b", daysAgo: 1, amount: 100, validator: module.second)
        ]))
        module.presenter.didReceive(nominationResult: .success(module.nomination))
        module.presenter.didReceive(eraRange: (start: 1, end: 4))
        module.presenter.didReceive(eraValidatorInfosResult: .success([
            try CovBAnFixtures.eraInfo(address: module.first, era: 1),
            try CovBAnFixtures.eraInfo(address: module.first, era: 2),
            try CovBAnFixtures.eraInfo(address: module.second, era: 2)
        ]))
        module.view.view.layoutIfNeeded()
        module.table.layoutIfNeeded()
    }

    private func loaded(_ module: CovBAnModule) -> AnalyticsValidatorsViewModel? {
        module.factory.createViewModel(
            eraValidatorInfos: [
                (try? CovBAnFixtures.eraInfo(address: module.first, era: 1)),
                (try? CovBAnFixtures.eraInfo(address: module.first, era: 2)),
                (try? CovBAnFixtures.eraInfo(address: module.second, era: 2))
            ].compactMap { $0 },
            eraRange: (start: 1, end: 4),
            stashAddress: CovBAnFixtures.stash,
            rewards: [
                CovBAnFixtures.reward("a", daysAgo: 1, amount: 300, validator: module.first),
                CovBAnFixtures.reward("b", daysAgo: 1, amount: 100, validator: module.second)
            ],
            nomination: module.nomination,
            identitiesByAddress: [:],
            page: .activity,
            locale: module.presenter.selectedLocale
        )
    }

    func testSetupShowsLoadingUntilEveryInputArrives() throws {
        let module = try makeModule()

        XCTAssertEqual(module.interactor.setupCalls, 1)
        XCTAssertNotNil(module.table.refreshControl)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(
            module.view.localizedTitle.value(for: locale),
            R.string.localizable.stakingRecommendedTitle(preferredLanguages: locale.rLanguages)
        )

        module.presenter.didReceive(stashAddressResult: .success(CovBAnFixtures.stash))
        module.presenter.didReceive(nominationResult: .success(module.nomination))
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(module.header.frame.height, 319)
    }

    func testLoadedActivityPageFillsChartHeaderAndCells() throws {
        let module = try makeModule()
        try deliverAll(to: module)
        let expected = try XCTUnwrap(loaded(module))

        XCTAssertEqual(module.table.refreshControl?.isRefreshing, false)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(module.header.titleLabel.text, expected.listTitle)
        XCTAssertEqual(module.header.titleLabel.text, R.string.localizable.stakingAnalyticsStakeAllocation(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(try module.centerText(), expected.chartCenterText.string)
        XCTAssertEqual(try module.segmentCount(), expected.validators.count + 1)

        let cell = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 0)) as? AnalyticsValidatorsCell
        )
        XCTAssertEqual(cell.nameLabel.text, module.first)
        XCTAssertEqual(cell.progressDescriptionLabel.text, expected.validators[0].progressFullDescription)
        XCTAssertTrue(cell.delegate === module.view)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 56)
        cell.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(cell.separatorInset.left, UIConstants.horizontalInset)
        cell.prepareForReuse()
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.nameLabel.text, module.first, "Reuse keeps the bound labels until the next bind")
    }

    func testIdentitiesRenameValidatorsAndPagesSwitch() throws {
        let module = try makeModule()
        try deliverAll(to: module)

        module.presenter.didReceive(identitiesByAddressResult: .success([module.first: AccountIdentity(name: "Alice")]))
        let renamed = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 0)) as? AnalyticsValidatorsCell
        )
        XCTAssertEqual(renamed.nameLabel.text, "Alice")

        module.presenter.handlePageAction(page: .rewards)
        module.presenter.handlePageAction(page: .rewards)
        XCTAssertEqual(module.header.titleLabel.text, R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages))
        let rewardsCell = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 0)) as? AnalyticsValidatorsCell
        )
        XCTAssertEqual(rewardsCell.progressDescriptionLabel.text, "3")

        module.presenter.didReceive(identitiesByAddressResult: .failure(CovBAnError(code: 1)))
        module.presenter.didReceive(stashAddressResult: .failure(CovBAnError(code: 2)))
        module.presenter.didReceive(nominationResult: .failure(CovBAnError(code: 3)))
        module.presenter.applyLocalization()
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 2)
    }

    func testInfoButtonAndChartSegmentsRouteThroughThePresenter() throws {
        let module = try makeModule()
        try deliverAll(to: module)
        let expected = try XCTUnwrap(loaded(module))

        let visibleCell = try XCTUnwrap(module.table.cellForRow(at: IndexPath(row: 1, section: 0)) as? AnalyticsValidatorsCell)
        visibleCell.infoButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(module.wireframe.shownAddresses, [expected.validators[1].validatorAddress])
        module.view.didTapInfoButton(in: AnalyticsValidatorsCell(style: .default, reuseIdentifier: nil))
        XCTAssertEqual(module.wireframe.shownAddresses.count, 1)

        module.view.didSelectSegment(index: 0)
        XCTAssertEqual(
            try module.centerText(),
            module.factory.chartCenterText(validator: expected.validators[0]).string
        )

        let inactive = try XCTUnwrap(expected.pieChartInactiveSegment)
        module.view.didSelectSegment(index: expected.validators.count)
        XCTAssertEqual(
            try module.centerText(),
            module.factory.chartCenterTextInactiveSegment(inactive, locale: module.presenter.selectedLocale).string
        )

        module.view.didUnselect()
        XCTAssertEqual(try module.centerText(), expected.chartCenterText.string)

        module.view.tableView(module.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(try module.selectedSegment(), 0)
    }

    func testFailuresShowErrorsAndRefreshReloads() throws {
        let module = try makeModule()
        try deliverAll(to: module)
        let message = R.string.localizable.commonErrorNoDataRetrieved(preferredLanguages: module.presenter.selectedLocale.rLanguages)

        module.presenter.didReceive(rewardsResult: .failure(CovBAnError(code: 4)))
        XCTAssertTrue(module.view.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(module.view.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, message)
        module.view.didSelectSegment(index: 0)
        module.view.didUnselect()

        module.view.didRetry(errorView: errorView)
        XCTAssertEqual(module.interactor.reloadCalls, 1)
        XCTAssertFalse(module.view.shouldDisplayEmptyState)
        XCTAssertNil(module.view.viewForEmptyState)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 0)

        module.presenter.didReceive(eraValidatorInfosResult: .failure(CovBAnError(code: 5)))
        XCTAssertTrue(module.view.shouldDisplayEmptyState)

        module.table.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(module.interactor.reloadCalls, 2)
    }

    func testInteractorDeliversStashNominationAndIdentities() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let stashId = Data(repeating: 0x44, count: 32)
        let stash = try AddressFactory.address(for: stashId, chain: chainAsset.chain)
        let validatorId = Data(repeating: 0x55, count: 32)
        let validator = try AddressFactory.address(for: validatorId, chain: chainAsset.chain)
        let nomination = try CovBAnFixtures.nomination(targets: [validatorId], submittedIn: 3)
        let identities = CovBAnIdentityFactoryStub(result: .success([validator: AccountIdentity(name: "Val")]))
        let output = CovBAnValidatorsOutputStub()
        let operationManager = OperationManager()
        let interactor = AnalyticsValidatorsInteractor(
            substrateProviderFactory: SubstrateDataProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: operationManager),
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(nomination: nomination, currentEra: 9),
            identityOperationFactory: identities,
            operationManager: operationManager,
            engine: MockConnection(),
            runtimeService: CovBVmPlainRuntime(),
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            chainAsset: chainAsset,
            selectedAccount: CovBAnFixtures.wallet()
        )
        interactor.presenter = output

        interactor.handleStashItem(result: .success(StashItem(stash: stash, controller: stash)), for: stash)
        XCTAssertEqual(try output.stashes.first?.get(), stash)

        XCTAssertTrue(CovBAnFixtures.spin { !output.nominations.isEmpty })
        XCTAssertEqual(try output.nominations.first?.get()?.targets, [validatorId])
        XCTAssertTrue(CovBAnFixtures.spin { !output.identities.isEmpty })
        XCTAssertEqual(try output.identities.first?.get()[validator]?.name, "Val")
        XCTAssertEqual(identities.requestedIds, [[validatorId]])

        interactor.handleCurrentEra(result: .success(10), chainId: chainAsset.chain.chainId)
        interactor.handleCurrentEra(result: .failure(CovBAnError(code: 6)), chainId: chainAsset.chain.chainId)
        interactor.reload()
        XCTAssertTrue(output.eraRanges.isEmpty, "Without a staking API no era range is requested")
        XCTAssertTrue(output.rewards.isEmpty)
    }

    func testInteractorReportsFailures() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let identities = CovBAnIdentityFactoryStub(result: .failure(CovBAnError(code: 7)))
        let output = CovBAnValidatorsOutputStub()
        let operationManager = OperationManager()
        let interactor = AnalyticsValidatorsInteractor(
            substrateProviderFactory: SubstrateDataProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: operationManager),
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(currentEra: 2),
            identityOperationFactory: identities,
            operationManager: operationManager,
            engine: MockConnection(),
            runtimeService: CovBVmPlainRuntime(),
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            chainAsset: chainAsset,
            selectedAccount: CovBAnFixtures.wallet()
        )
        interactor.presenter = output

        interactor.handleStashItem(result: .failure(CovBAnError(code: 8)), for: "x")
        XCTAssertThrowsError(try output.stashes.first?.get())

        let nomination = try CovBAnFixtures.nomination(targets: [Data(repeating: 0x66, count: 32)])
        interactor.handleNomination(result: .success(nomination), accountId: Data(), chainId: chainAsset.chain.chainId)
        XCTAssertTrue(CovBAnFixtures.spin { !output.identities.isEmpty })
        XCTAssertThrowsError(try output.identities.first?.get())

        interactor.handleNomination(result: .failure(CovBAnError(code: 9)), accountId: Data(), chainId: chainAsset.chain.chainId)
        XCTAssertEqual(output.nominations.count, 2)
        XCTAssertThrowsError(try output.nominations.last?.get())

        interactor.setup()
        XCTAssertTrue(output.stashes.count == 1, "No stash is stored for the wallet")
    }
}
