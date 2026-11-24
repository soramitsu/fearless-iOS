import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

/// Routes through the real staking main wireframe; modules that need a chain connection are refused for the test chain.
final class CovAStakingMainWireframeTests: XCTestCase {
    private let chainAsset = CovAFixtures.chainAsset()
    private let wallet = CovAFixtures.wallet()

    private func makeHost() -> (CovAStakingMainViewStub, UINavigationController, UIWindow) {
        let host = CovAStakingMainViewStub()
        let navigation = UINavigationController(rootViewController: host)
        let window = CovAViewInspector.host(navigation)
        return (host, navigation, window)
    }

    func testModalScreensArePresented() {
        let (host, _, window) = makeHost()
        let wireframe = StakingMainWireframe()

        wireframe.showManageStaking(
            from: host,
            items: [.stakingBalance, .rewardDestination, .controllerAccount],
            delegate: nil,
            context: nil
        )
        XCTAssertEqual(host.presentedControllers.count, 1, "the manage picker is shown")

        wireframe.showRewardDetails(from: host, maxReward: ("Max", 0.2), avgReward: ("Avg", 0.1))
        XCTAssertEqual(host.presentedControllers.count, 2, "the reward details are shown")

        wireframe.showStories(from: host, startingFrom: 0, chainAsset: chainAsset)
        XCTAssertEqual(host.presentedControllers.count, 3, "the stories are shown")

        wireframe.showAccountsSelection(from: host, moduleOutput: CovAWalletsOutputSpy())
        XCTAssertEqual(host.presentedControllers.count, 4, "the wallet list is shown")
        window.isHidden = true
    }

    func testFlowsThatNeedAChainConnectionAreNotOpened() {
        let (host, navigation, window) = makeHost()
        let wireframe = StakingMainWireframe()
        let bonding = CovAConfirmFixtures.existing(payout: false)

        wireframe.showSetupAmount(
            from: host, amount: 1, chain: chainAsset.chain, asset: chainAsset.asset, selectedAccount: wallet, rewardChainAsset: nil
        )
        wireframe.proceedToSelectValidatorsStart(
            from: host, existingBonding: bonding, chain: chainAsset.chain, asset: chainAsset.asset, selectedAccount: wallet
        )
        wireframe.showRewardPayoutsForNominator(from: host, stashAddress: CovAFixtures.address(7), chainAsset: chainAsset, wallet: wallet)
        wireframe.showRewardPayoutsForValidator(from: host, stashAddress: CovAFixtures.address(7), chainAsset: chainAsset, wallet: wallet)
        wireframe.showNominatorValidators(from: host, chainAsset: chainAsset, wallet: wallet)
        wireframe.showControllerAccount(from: host, chain: chainAsset.chain, asset: chainAsset.asset, selectedAccount: wallet)
        wireframe.showRewardDestination(
            from: host, chain: chainAsset.chain, asset: chainAsset.asset, selectedAccount: wallet, rewardChainAsset: nil
        )
        wireframe.showBondMore(from: host, chainAsset: chainAsset, wallet: wallet, flow: .relaychain)
        wireframe.showRedeem(from: host, chainAsset: chainAsset, wallet: wallet, flow: .relaychain)
        wireframe.showStakingBalance(from: host, chainAsset: chainAsset, wallet: wallet, flow: .relaychain)

        XCTAssertTrue(host.presentedControllers.isEmpty)
        XCTAssertTrue(navigation.topViewController === host)
        window.isHidden = true
    }
}

final class CovAWalletsOutputSpy: WalletsManagmentModuleOutput {
    private(set) var calls: [String] = []
    func showAddNewWallet() {
        calls.append("add")
    }

    func showImportWallet(defaultSource _: AccountImportSource) {
        calls.append("import")
    }

    func showImportGoogle() {
        calls.append("google")
    }

    func showGetPreinstalledWallet() {
        calls.append("preinstalled")
    }
}
