import XCTest
import BigInt
import SSFModels
import SSFUtils
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovCBPRDCRecordingController: UIViewController {
    var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCBPRDCViewDouble: StakingRewardDestConfirmViewProtocol, FWTransferSealShowing {
    let recorder = CovCBPRDCRecordingController()
    var confirmations: [StakingRewardDestConfirmViewModel] = []
    var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    var events: [String] = []

    var isSetup: Bool { true }
    var controller: UIViewController { recorder }
    var loadableContentView: UIView { recorder.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func applyLocalization() {}
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel) { confirmations.append(viewModel) }
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) { fees.append(viewModel) }
    func didReachTransferStage(_ stage: FWSealStage) { events.append("stage-\(stage)") }
    func didBreakTransfer() { events.append("break") }
}

final class CovCBPRDCWireframeDouble: StakingRewardDestConfirmWireframeProtocol {
    var completeCount = 0
    var extrinsicFailedCount = 0

    func complete(from _: StakingRewardDestConfirmViewProtocol?) { completeCount += 1 }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { extrinsicFailedCount += 1 }
    func dismiss(view _: ControllerBackedProtocol?) {}
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovCBPRDCInteractorDouble: StakingRewardDestConfirmInteractorInputProtocol {
    var setupCount = 0
    var estimates: [(RewardDestination<AccountAddress>, StashItem)] = []
    var submits: [(RewardDestination<AccountAddress>, StashItem)] = []

    func setup() { setupCount += 1 }
    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem) {
        estimates.append((rewardDestination, stashItem))
    }

    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem) {
        submits.append((rewardDestination, stashItem))
    }
}

final class CovCBPRDCAuthorizerStub: SubmissionAuthorizing {
    var allow = true

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        completion(allow)
    }
}

final class CovCBPRDCThrowingFactory: StakingRewardDestConfirmVMFactoryProtocol {
    var calls = 0

    func createViewModel(
        from _: StashItem,
        rewardDestination _: RewardDestination<fearless.ChainAccountResponse>,
        controller _: fearless.ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel {
        calls += 1
        throw CommonError.undefined
    }
}

final class CovCBPRewardDestConfirmPresenterTests: XCTestCase {
    private struct CovCEnv {
        let presenter: StakingRewardDestConfirmPresenter
        let view: CovCBPRDCViewDouble
        let wireframe: CovCBPRDCWireframeDouble
        let interactor: CovCBPRDCInteractorDouble
        let authorizer: CovCBPRDCAuthorizerStub
    }

    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()

    private func account() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
    }

    private func stashItem() throws -> StashItem {
        let address = try XCTUnwrap(try account().toAddress())
        return StashItem(stash: address, controller: address)
    }

    private func makeEnv(
        destination: RewardDestination<fearless.ChainAccountResponse>,
        factory: StakingRewardDestConfirmVMFactoryProtocol = StakingRewardDestConfirmVMFactory(iconGenerator: UniversalIconGenerator())
    ) throws -> CovCEnv {
        let wireframe = CovCBPRDCWireframeDouble()
        let interactor = CovCBPRDCInteractorDouble()
        let authorizer = CovCBPRDCAuthorizerStub()
        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: destination,
            confirmModelFactory: factory,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chain: chain,
            asset: asset,
            wallet: wallet,
            logger: nil,
            submissionAuthorizer: authorizer
        )
        let view = CovCBPRDCViewDouble()
        view.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        presenter.view = view
        return CovCEnv(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, authorizer: authorizer)
    }

    func testSetupAndDataFlowProduceViewModels() throws {
        let env = try makeEnv(destination: .payout(account: try account()))

        env.presenter.setup()
        XCTAssertEqual(env.interactor.setupCount, 1)
        XCTAssertEqual(env.view.fees.count, 1)
        XCTAssertNil(env.view.fees.first ?? nil)
        XCTAssertTrue(env.view.confirmations.isEmpty)

        env.presenter.didReceiveStashItem(result: .success(try stashItem()))
        XCTAssertEqual(env.interactor.estimates.count, 1)
        XCTAssertEqual(env.interactor.estimates.first?.0, .payout(account: try account().toAddress() ?? ""))
        XCTAssertTrue(env.view.confirmations.isEmpty)

        env.presenter.didReceiveController(result: .success(try account()))
        XCTAssertEqual(env.view.confirmations.count, 1)
        XCTAssertEqual(env.view.confirmations.first?.senderName, wallet.name)

        env.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        XCTAssertNotNil(env.view.fees.last ?? nil)

        env.presenter.didReceiveStashItem(result: .success(try stashItem()))
        XCTAssertEqual(env.interactor.estimates.count, 1)

        env.presenter.didReceiveFee(result: .failure(CommonError.undefined))
        env.presenter.didReceiveStashItem(result: .failure(CommonError.undefined))
        env.presenter.didReceiveController(result: .failure(CommonError.undefined))
        env.presenter.didReceiveAccountInfo(result: .failure(CommonError.undefined))
        XCTAssertEqual(env.view.confirmations.count, 2)
    }

    func testConfirmValidatesAndSubmits() throws {
        let env = try makeEnv(destination: .restake)

        env.presenter.confirm()
        XCTAssertTrue(env.interactor.submits.isEmpty)

        env.presenter.didReceiveStashItem(result: .success(try stashItem()))
        env.presenter.didReceiveController(result: .success(try account()))
        env.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        env.presenter.didReceiveAccountInfo(result: .success(
            AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 50_000_000_000, reserved: 0, frozen: 0))
        ))

        env.authorizer.allow = false
        env.presenter.confirm()
        XCTAssertTrue(env.interactor.submits.isEmpty)

        env.authorizer.allow = true
        env.presenter.confirm()
        XCTAssertEqual(env.interactor.submits.count, 1)
        XCTAssertEqual(env.interactor.submits.first?.0, .restake)
        XCTAssertEqual(env.view.events, ["start", "stage-\(FWSealStage.ready)"])

        env.presenter.didReceiveAccountInfo(result: .success(nil))
        env.presenter.confirm()
        XCTAssertEqual(env.interactor.submits.count, 1)
    }

    func testAccountOptions() throws {
        let env = try makeEnv(destination: .payout(account: try account()))

        env.presenter.presentSenderAccountOptions()
        XCTAssertTrue(env.view.recorder.presentedControllers.isEmpty)

        env.presenter.presentPayoutAccountOptions()
        XCTAssertEqual(env.view.recorder.presentedControllers.count, 1)

        env.presenter.didReceiveController(result: .success(try account()))
        env.presenter.presentSenderAccountOptions()
        XCTAssertEqual(env.view.recorder.presentedControllers.count, 2)
        XCTAssertTrue(env.view.recorder.presentedControllers.allSatisfy { $0 is UIAlertController })

        let restakeEnv = try makeEnv(destination: .restake)
        restakeEnv.presenter.presentPayoutAccountOptions()
        XCTAssertTrue(restakeEnv.view.recorder.presentedControllers.isEmpty)
    }

    func testSubmitResults() throws {
        let env = try makeEnv(destination: .restake)

        env.presenter.didSubmitRewardDest(result: .success("0x1"))
        XCTAssertEqual(env.wireframe.completeCount, 1)
        XCTAssertEqual(env.view.events, ["stop", "stage-\(FWSealStage.accepted)"])

        env.presenter.didSubmitRewardDest(result: .failure(CommonError.network))
        XCTAssertEqual(env.wireframe.extrinsicFailedCount, 1)
        XCTAssertEqual(env.view.events.last, "break")

        env.presenter.view = nil
        env.presenter.didSubmitRewardDest(result: .success("0x2"))
        XCTAssertEqual(env.wireframe.completeCount, 1)
    }

    func testFactoryErrorIsSwallowed() throws {
        let factory = CovCBPRDCThrowingFactory()
        let env = try makeEnv(destination: .restake, factory: factory)

        env.presenter.didReceiveController(result: .success(try account()))
        env.presenter.didReceiveStashItem(result: .success(try stashItem()))

        XCTAssertEqual(factory.calls, 1)
        XCTAssertTrue(env.view.confirmations.isEmpty)
    }
}
