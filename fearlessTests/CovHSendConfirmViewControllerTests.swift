import XCTest
import UIKit
import SoraFoundation
import SSFQRService
@testable import fearless

final class CovHSendConfirmViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testForegroundResumesReviewAndScamWarningIsForwarded() {
        let presenter = CovHSendConfirmPresenterSpy()
        let controller = WalletSendConfirmViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        controller.perform(Selector(("applicationDidBecomeActive")))
        XCTAssertEqual(presenter.resumes, 0, "A screen without a window is not resumed")

        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.rootViewController = controller
        host.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        window = host
        XCTAssertEqual(presenter.setups, 1)
        CovHSendWait.until(timeout: 0.3) { false }
        let resumes = presenter.resumes
        controller.perform(Selector(("applicationDidBecomeActive")))
        XCTAssertEqual(presenter.resumes, resumes + 1)
        controller.perform(Selector(("handleScamWarningTapped")))
        XCTAssertEqual(presenter.scamTaps, 1)

        controller.didReceive(state: .loading)
        controller.didReachTransferStage(.ready)
        controller.didBreakTransfer()
        XCTAssertTrue(controller.isViewLoaded)
    }

    func testSoraCodesStartALockedSendFlow() {
        let info = SoraQRInfo(address: "sora", rawPublicKey: Data(), username: "", assetId: "0x1", amount: nil)
        let data = SendFlowInitialData(qrInfoType: .sora(info))
        guard case let .soraMainnet(qrInfo) = data else {
            return XCTFail("A SORA code starts the SORA flow")
        }
        XCTAssertEqual(qrInfo.address, "sora")
        XCTAssertFalse(data.selectableAsset)
        XCTAssertTrue(SendFlowInitialData.address("x").selectableAsset)
    }
}

final class CovHSendConfirmPresenterSpy: WalletSendConfirmPresenterProtocol, WalletSendConfirmScopeManaging {
    var setups = 0
    var confirms = 0
    var backs = 0
    var scamTaps = 0
    var resumes = 0
    var suspends = 0

    var hasOwnedRecoveryPresentation: Bool { false }
    func setup() { setups += 1 }
    func didTapConfirmButton() { confirms += 1 }
    func didTapBackButton() { backs += 1 }
    func didTapScamWarningButton() { scamTaps += 1 }
    func resumeSendReview() { resumes += 1 }
    func suspendSendReview() { suspends += 1 }
}
