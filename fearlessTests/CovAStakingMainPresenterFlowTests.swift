import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStakingMainPresenterFlowTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAStakingMainFixtures

    private var savedWallet: MetaAccountModel?
    private var walletReplaced = false

    override func tearDown() {
        if walletReplaced {
            SelectedWalletSettings.shared.internalValue = savedWallet
            walletReplaced = false
        }
        super.tearDown()
    }

    /// Several presenter actions read the selected wallet; it is set in memory only and restored in tearDown.
    private func useSelectedWallet() {
        savedWallet = SelectedWalletSettings.shared.internalValue
        walletReplaced = true
        SelectedWalletSettings.shared.internalValue = CovAFixtures.wallet()
    }

    private struct CovAContext {
        let presenter: StakingMainPresenter
        let view: CovAStakingMainViewStub
        let wireframe: CovAStakingMainWireframeStub
        let interactor: CovAStakingMainInteractorSpy
        let output: CovAStakingMainModuleOutputSpy
    }

    private func makeContext() -> CovAContext {
        let wallet = CovAFixtures.wallet()
        let wireframe = CovAStakingMainWireframeStub()
        let output = CovAStakingMainModuleOutputSpy()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingMainPresenter(
            stateViewModelFactory: StakingStateViewModelFactory(
                analyticsRewardsViewModelFactoryBuilder: { chainAsset, balance in
                    AnalyticsRewardsViewModelFactory(
                        assetInfo: chainAsset.assetDisplayInfo,
                        balanceViewModelFactory: balance,
                        calendar: Calendar(identifier: .gregorian)
                    )
                },
                selectedMetaAccount: wallet,
                eventCenter: EventCenter.shared
            ),
            networkInfoViewModelFactory: NetworkInfoViewModelFactory(),
            viewModelFacade: StakingViewModelFacade(selectedMetaAccount: wallet),
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            selectedMetaAccount: wallet,
            moduleOutput: output
        )
        let view = CovAStakingMainViewStub()
        view.localizationManager = CovAFixtures.localizationManager
        view.loadViewIfNeeded()
        let interactor = CovAStakingMainInteractorSpy()
        presenter.view = view
        dataValidatingFactory.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        return CovAContext(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, output: output)
    }

    private func networkInfo() -> NetworkStakingInfo {
        .relaychain(
            baseInfo: BaseStakingInfo(lockUpPeriod: 28, minimalBalance: 1_000_000_000, minStakeAmongActiveNominators: 2_000_000_000),
            relaychainInfo: RelaychainStakingInfo(
                stakingDuration: StakingDuration(session: 3600, era: 21600, unlocking: 2_419_200),
                totalStake: BigUInt(1_000_000_000_000_000),
                activeNominatorsCount: 10
            )
        )
    }

    /// Feeds the presenter like the interactor would, up to a nominator with stake.
    private func feedCommonData(_ presenter: StakingMainPresenter) throws {
        presenter.didReceive(newChainAsset: CovAFixtures.chainAsset())
        presenter.didReceive(selectedAddress: CovAFixtureAlias.stashAddress)
        presenter.didReceive(accountInfo: WestendStub.accountInfo.item)
        presenter.didReceive(calculator: CovARewardCalculatorStub())
        try presenter.didReceive(eraStakersInfo: CovAFixtureAlias.eraStakers())
        presenter.didReceive(networkStakingInfo: networkInfo())
        presenter.didReceiveMinNominatorBond(result: .success(BigUInt(5)))
        presenter.didReceiveCounterForNominators(result: .success(1))
        presenter.didReceiveMaxNominatorsCount(result: .success(100))
        presenter.didReceiveMaxNominatorsPerValidator(64)
        presenter.didReceive(eraCountdownResult: .success(CovAFixtureAlias.eraCountdown()))
        presenter.didReceieve(subqueryRewards: .success([]), period: .week)
        presenter.didReceive(rewardChainAsset: nil)
    }

    func testSetupAndInteractorOutputsRenderViewModels() throws {
        let context = makeContext()
        context.presenter.setup()
        context.presenter.setup()
        XCTAssertEqual(context.interactor.calls, ["setup"], "setup runs once")
        context.presenter.didTriggerViewWillAppear()
        context.presenter.didTriggerViewWillDisappear()
        context.presenter.networkInfoViewDidChangeExpansion(isExpanded: true)
        context.presenter.networkInfoViewExpansion(isExpanded: false)
        XCTAssertEqual(context.view.expansions, [false])

        try feedCommonData(context.presenter)
        XCTAssertEqual(context.presenter.chainAsset?.chain.chainId, CovAFixtures.chainId)
        XCTAssertNotNil(context.view.mainViewModels.last ?? nil)
        XCTAssertNotNil(context.view.networkInfos.last ?? nil)
        XCTAssertFalse(context.view.stories.isEmpty)

        context.presenter.didReceive(stashItem: nil)
        context.presenter.updateAmount(3)
        XCTAssertEqual(context.presenter.amount, 3)
        context.presenter.selectAmountPercentage(0.5)
        XCTAssertEqual(context.presenter.amount, 5)
        CovAViewInspector.spin(until: {
            if case .noStash = context.view.states.last {
                return true
            }
            return false
        })
        guard case .noStash = context.view.states.last else { return XCTFail("no stash state rendered") }

        context.presenter.selectStory(at: 1)
        context.presenter.performRewardInfoAction()
        context.presenter.performAccountAction()
        context.presenter.performAssetSelection()
        context.presenter.showAddNewWallet()
        context.presenter.showImportWallet(defaultSource: .mnemonic)
        context.presenter.showImportGoogle()
        context.presenter.showGetPreinstalledWallet()
        XCTAssertEqual(context.wireframe.events, [
            "stories:1", "rewardDetails", "accounts", "assetSelection", "createWallet", "importWallet", "backup", "preinstalled"
        ])
    }

    func testErrorsArePresented() {
        let context = makeContext()
        context.presenter.didReceive(totalReward: CovATestError.failed as Error)
        context.presenter.didReceive(balanceError: CovATestError.failed)
        context.presenter.didReceive(calculatorError: CovATestError.failed)
        context.presenter.didReceive(stashItemError: CovATestError.failed)
        context.presenter.didReceive(ledgerInfoError: CovATestError.failed)
        context.presenter.didReceive(nominationError: CovATestError.failed)
        context.presenter.didReceive(validatorError: CovATestError.failed)
        context.presenter.didReceive(eraStakersInfoError: CovATestError.failed)
        context.presenter.didReceive(networkStakingInfoError: CovATestError.failed)
        context.presenter.didReceive(payeeError: CovATestError.failed)
        context.presenter.didReceiveControllerAccount(result: .failure(CovATestError.failed))
        context.presenter.didReceieve(subqueryRewards: .failure(CovATestError.failed), period: .month)
        context.presenter.didReceiveMinNominatorBond(result: .failure(CovATestError.failed))
        context.presenter.didReceiveCounterForNominators(result: .failure(CovATestError.failed))
        context.presenter.didReceiveMaxNominatorsCount(result: .failure(CovATestError.failed))
        context.presenter.didReceive(eraCountdownResult: .failure(CovATestError.failed))
        XCTAssertEqual(context.wireframe.events.filter { $0 == "error" }.count, 16)
        context.presenter.performRewardInfoAction()
        context.presenter.selectStory(at: 0)
        context.presenter.selectAmountPercentage(0.5)
        XCTAssertEqual(context.wireframe.events.count, 16, "nothing to show without staking data")
    }

    func testNominatorActionsAndManageOptions() throws {
        useSelectedWallet()
        let context = makeContext()
        try feedCommonData(context.presenter)
        context.presenter.didReceive(stashItem: CovAFixtureAlias.stash())
        try context.presenter.didReceive(ledgerInfo: CovAFixtureAlias.ledger())
        context.presenter.didReceive(totalReward: CovAFixtureAlias.totalReward())
        context.presenter.didReceive(payee: .staked)
        try context.presenter.didReceive(nomination: CovAFixtureAlias.nomination())

        context.presenter.performNominationStatusAction()
        XCTAssertEqual(context.wireframe.sheets.count, 1)
        context.presenter.performValidationStatusAction()
        XCTAssertEqual(context.wireframe.sheets.count, 1, "not a validator")

        context.presenter.performManageStakingAction()
        let items = try XCTUnwrap(context.wireframe.manageItems.last)
        XCTAssertEqual(items.count, 4)
        for index in items.indices {
            context.presenter.modalPickerDidSelectModelAtIndex(index, context: items as NSArray)
        }
        context.presenter.modalPickerDidSelectModelAtIndex(99, context: items as NSArray)

        context.presenter.performMainAction()
        context.presenter.performChangeValidatorsAction()
        context.presenter.performBondMoreAction()
        context.presenter.performRedeemAction()
        context.presenter.didReceiveControllerAccount(result: .success(CovAConfirmFixtures.controller()))
        context.presenter.performRedeemAction()
        context.presenter.performAnalyticsAction()

        let events = context.wireframe.events
        for expected in ["balance", "rewardDestination", "validators", "controller", "setupAmount", "bondMore",
                         "missingController", "redeem", "analytics"] {
            XCTAssertTrue(events.contains(expected), "\(expected) missing in \(events)")
        }
        XCTAssertEqual(context.wireframe.analyticsModes.last, [.accountIsNominator, .includeValidatorsTab])
    }

    func testBondedSetupValidatorsAndManageOptions() throws {
        useSelectedWallet()
        let context = makeContext()
        try feedCommonData(context.presenter)
        context.presenter.didReceive(stashItem: CovAFixtureAlias.stash())
        try context.presenter.didReceive(ledgerInfo: CovAFixtureAlias.ledger())
        context.presenter.didReceive(payee: .staked)
        context.presenter.didReceive(nomination: nil)
        context.presenter.didReceive(validatorPrefs: nil)
        context.presenter.updateAmount(2)
        XCTAssertEqual(context.presenter.amount, 2)

        context.presenter.performNominationStatusAction()
        XCTAssertEqual(context.wireframe.sheets.count, 1)

        context.presenter.performSetupValidatorsForBondedAction()
        XCTAssertTrue(context.wireframe.events.contains("missingController"))
        context.presenter.didReceiveControllerAccount(result: .success(CovAConfirmFixtures.controller()))
        context.presenter.performSetupValidatorsForBondedAction()
        XCTAssertTrue(context.wireframe.events.contains("selectValidators"))

        context.presenter.performManageStakingAction()
        let items = try XCTUnwrap(context.wireframe.manageItems.last)
        XCTAssertEqual(items.count, 4)
        let setupIndex = try XCTUnwrap(items.firstIndex {
            if case .setupValidators = $0 {
                return true
            }; return false
        })
        context.presenter.modalPickerDidSelectModelAtIndex(setupIndex, context: items as NSArray)
        XCTAssertEqual(context.wireframe.events.filter { $0 == "selectValidators" }.count, 2)
        context.presenter.performAnalyticsAction()
        XCTAssertEqual(context.wireframe.analyticsModes.last, [.accountIsNominator])
    }

    func testValidatorManageOptionsAndStatus() throws {
        useSelectedWallet()
        let context = makeContext()
        try feedCommonData(context.presenter)
        context.presenter.didReceive(stashItem: StashItem(stash: CovAFixtures.address(1), controller: CovAFixtures.address(1)))
        try context.presenter.didReceive(ledgerInfo: CovAFixtureAlias.ledger())
        context.presenter.didReceive(validatorPrefs: CovAFixtureAlias.prefs())

        context.presenter.performValidationStatusAction()
        XCTAssertEqual(context.wireframe.sheets.count, 1)
        context.presenter.performManageStakingAction()
        let items = try XCTUnwrap(context.wireframe.manageItems.last)
        XCTAssertEqual(items.count, 4)
        for index in items.indices {
            context.presenter.modalPickerDidSelectModelAtIndex(index, context: items as NSArray)
        }
        XCTAssertTrue(context.wireframe.events.contains("yourValidator"))
        context.presenter.modalPickerDidSelectModelAtIndex(0, context: [StakingManageOption.pendingRewards] as NSArray)
        XCTAssertTrue(context.wireframe.events.contains("payoutsValidator"))
        context.presenter.performAnalyticsAction()
        XCTAssertEqual(context.wireframe.analyticsModes.last, [])
    }

    func testWalletChangeAndAssetSelection() throws {
        let context = makeContext()
        try feedCommonData(context.presenter)
        let infos = context.view.networkInfos.count
        context.presenter.didReceive(selectedWallet: CovAFixtures.wallet())
        var other = CovAFixtures.wallet()
        other = MetaAccountModel(
            metaId: "cov-a-other", name: other.name, substrateAccountId: other.substrateAccountId,
            substrateCryptoType: 0, substratePublicKey: other.substratePublicKey, ethereumAddress: nil, ethereumPublicKey: nil,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: other.selectedCurrency, networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true,
            favouriteChainIds: []
        )
        context.presenter.didReceive(selectedWallet: other)
        XCTAssertEqual(context.view.networkInfos.count, infos, "only Asset Hub routes drop the staking info")

        context.presenter.didReceive(newChainAsset: nil)
        XCTAssertNil(context.presenter.chainAsset)
        XCTAssertNil(context.view.networkInfos.last ?? nil)
        XCTAssertNil(context.view.mainViewModels.last ?? nil)
    }
}
