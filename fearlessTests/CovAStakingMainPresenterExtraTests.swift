import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAChainSelectionViewStub: UIViewController, ChainSelectionViewProtocol {
    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
}

final class CovAStakingMainPresenterExtraTests: XCTestCase {
    private var savedWallet: MetaAccountModel?
    private var retainedView: UIViewController?

    override func setUp() {
        super.setUp()
        savedWallet = SelectedWalletSettings.shared.internalValue
        SelectedWalletSettings.shared.internalValue = CovAFixtures.wallet()
    }

    override func tearDown() {
        SelectedWalletSettings.shared.internalValue = savedWallet
        super.tearDown()
    }

    private func makePresenter() -> (StakingMainPresenter, CovAStakingMainWireframeStub, CovAStakingMainInteractorSpy, CovAStakingMainModuleOutputSpy) {
        let wallet = CovAFixtures.wallet()
        let wireframe = CovAStakingMainWireframeStub()
        let output = CovAStakingMainModuleOutputSpy()
        let validating = StakingDataValidatingFactory(presentable: wireframe)
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
            dataValidatingFactory: validating,
            logger: nil,
            selectedMetaAccount: wallet,
            moduleOutput: output
        )
        let view = CovAStakingMainViewStub()
        view.localizationManager = CovAFixtures.localizationManager
        view.loadViewIfNeeded()
        presenter.view = view
        validating.view = view
        let interactor = CovAStakingMainInteractorSpy()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        retainedView = view
        return (presenter, wireframe, interactor, output)
    }

    func testAssetSelectionSavesTheChoiceAndSwitchesToPools() {
        let (presenter, _, interactor, output) = makePresenter()
        let selection = CovAChainSelectionViewStub()
        let chainAsset = CovAFixtures.chainAsset()
        presenter.assetSelection(view: selection, didCompleteWith: chainAsset, context: AssetSelectionStakingType.normal(chainAsset: chainAsset))
        presenter.assetSelection(view: selection, didCompleteWith: chainAsset, context: AssetSelectionStakingType.pool(chainAsset: chainAsset))
        presenter.assetSelection(view: selection, didCompleteWith: chainAsset, context: nil)
        XCTAssertEqual(interactor.savedChainAssets.count, 2)
        XCTAssertEqual(output.switches, 1)
    }

    func testNominatorPendingRewardsOpenNominatorPayouts() throws {
        let (presenter, wireframe, _, _) = makePresenter()
        presenter.didReceive(newChainAsset: CovAFixtures.chainAsset())
        presenter.didReceive(selectedAddress: CovAStakingMainFixtures.stashAddress)
        presenter.didReceive(stashItem: CovAStakingMainFixtures.stash())
        try presenter.didReceive(ledgerInfo: CovAStakingMainFixtures.ledger())
        try presenter.didReceive(nomination: CovAStakingMainFixtures.nomination())
        presenter.modalPickerDidSelectModelAtIndex(0, context: [StakingManageOption.pendingRewards] as NSArray)
        presenter.modalPickerDidSelectModelAtIndex(0, context: [StakingManageOption.setupValidators] as NSArray)
        presenter.modalPickerDidSelectModelAtIndex(0, context: [StakingManageOption.yourValidator] as NSArray)
        XCTAssertEqual(wireframe.events, ["payoutsNominator"])
        presenter.didReceive(networkStakingInfoError: CovATestError.failed)
        XCTAssertEqual(wireframe.events.last, "error")
    }
}
