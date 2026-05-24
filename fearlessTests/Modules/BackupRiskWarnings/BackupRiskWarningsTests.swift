import XCTest
import UIKit
import FearlessFoundation
@testable import fearless

final class BackupRiskWarningsTests: XCTestCase {
    func testDidLoad_whenViewIsProvided_thenSetsUpInteractor() {
        let interactor = BackupRiskWarningsInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = BackupRiskWarningsViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidBackButtonTapped_whenViewLoaded_thenDismissesView() {
        let router = BackupRiskWarningsRouterSpy()
        let presenter = createPresenter(router: router)
        let view = BackupRiskWarningsViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()

        XCTAssertTrue(router.dismissedView === view)
    }

    func testDidContinueButtonTapped_whenWalletNameProvided_thenShowsCreateAccount() {
        let router = BackupRiskWarningsRouterSpy()
        let presenter = createPresenter(walletName: "Backup Wallet", router: router)
        let view = BackupRiskWarningsViewSpy()

        presenter.didLoad(view: view)
        presenter.didContinueButtonTapped()

        XCTAssertEqual(router.usernameModel, UsernameSetupModel(username: "Backup Wallet"))
        XCTAssertTrue(router.createAccountView === view)
    }

    private func createPresenter(
        walletName: String = "Wallet",
        interactor: BackupRiskWarningsInteractorInput = BackupRiskWarningsInteractorInputSpy(),
        router: BackupRiskWarningsRouterInput = BackupRiskWarningsRouterSpy()
    ) -> BackupRiskWarningsPresenter {
        BackupRiskWarningsPresenter(
            walletName: walletName,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class BackupRiskWarningsViewSpy: BackupRiskWarningsViewInput {
    let controller = UIViewController()
    let isSetup = false
}

private final class BackupRiskWarningsInteractorInputSpy: BackupRiskWarningsInteractorInput {
    private(set) weak var output: BackupRiskWarningsInteractorOutput?

    func setup(with output: BackupRiskWarningsInteractorOutput) {
        self.output = output
    }
}

private final class BackupRiskWarningsRouterSpy: BackupRiskWarningsRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var createAccountView: ControllerBackedProtocol?
    private(set) var usernameModel: UsernameSetupModel?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showCreateAccount(
        usernameModel: UsernameSetupModel,
        from view: ControllerBackedProtocol?
    ) {
        self.usernameModel = usernameModel
        createAccountView = view
    }
}
