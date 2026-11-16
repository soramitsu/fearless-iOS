import BigInt
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftConfirmViewSpy: CovHNftHostController, NftSendConfirmViewInput, Localizable {
    private(set) var receivers: [AccountViewModel?] = []
    private(set) var senders: [AccountViewModel?] = []
    private(set) var fees: [BalanceViewModelProtocol?] = []
    private(set) var nftViewModels: [NftSendConfirmViewModel] = []
    private(set) var loading: [Bool] = []

    func didReceive(receiverViewModel: AccountViewModel?) { receivers.append(receiverViewModel) }
    func didReceive(senderViewModel: AccountViewModel?) { senders.append(senderViewModel) }
    func didReceive(feeViewModel: BalanceViewModelProtocol?) { fees.append(feeViewModel) }
    func didReceive(nftViewModel: NftSendConfirmViewModel) { nftViewModels.append(nftViewModel) }
    func didStartLoading() { loading.append(true) }
    func didStopLoading() { loading.append(false) }
    func applyLocalization() {}
}

final class CovHNftConfirmInteractorSpy: NftSendConfirmInteractorInput {
    private(set) weak var output: NftSendConfirmInteractorOutput?
    private(set) var estimates: [String?] = []
    private(set) var submits: [String] = []

    func setup(with output: NftSendConfirmInteractorOutput) { self.output = output }
    func estimateFee(for _: NFT, address: String?) { estimates.append(address) }
    func submitExtrinsic(nft _: NFT, receiverAddress: String) { submits.append(receiverAddress) }
}

final class CovHNftConfirmRouterSpy: NftSendConfirmRouterInput {
    var presentsErrors = false
    private(set) var calls: [String] = []
    private(set) var completions: [(String, ChainAsset?)] = []

    func complete(on _: ControllerBackedProtocol, title: String, chainAsset: ChainAsset?) {
        completions.append((title, chainAsset))
    }

    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        calls.append("error")
        return presentsErrors
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("failed") }
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("noFee") }
    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("tooHigh") }
    func presentSuccessNotification(_: String, from _: ControllerBackedProtocol?, completion _: (() -> Void)?) {}
}

final class CovHNftAuthorizerStub: SubmissionAuthorizing {
    var authorized = true
    private(set) var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(authorized)
    }
}

final class CovHNftAccountViewModelFactoryStub: AccountViewModelFactoryProtocol {
    func buildViewModel(title: String, address: String, locale _: Locale) -> AccountViewModel {
        AccountViewModel(title: title, name: address, icon: nil)
    }

    func buildViewModel(title: String, address: String, name _: String?, locale _: Locale) -> AccountViewModel {
        AccountViewModel(title: title, name: address, icon: nil)
    }
}

final class CovHNftSendConfirmPresenterTests: XCTestCase {
    private struct Context {
        let view = CovHNftConfirmViewSpy()
        let interactor = CovHNftConfirmInteractorSpy()
        let router = CovHNftConfirmRouterSpy()
        let authorizer = CovHNftAuthorizerStub()
        let wallet: MetaAccountModel
        let chain: ChainModel
        let presenter: NftSendConfirmPresenter

        init(utility: Bool = true, wallet: MetaAccountModel = CovHNftFixtures.wallet()) {
            self.wallet = wallet
            chain = CovHNftFixtures.chain(utility: utility)
            let validating = SendDataValidatingFactory(presentable: router)
            presenter = NftSendConfirmPresenter(
                interactor: interactor,
                router: router,
                localizationManager: LocalizationManager.shared,
                scamInfo: nil,
                receiverAddress: "receiver",
                wallet: wallet,
                accountViewModelFactory: CovHNftAccountViewModelFactoryStub(),
                nft: CovHNftFixtures.nft(chain: chain, thumbnail: "https://image.invalid/n.png", collectionName: "Confirm collection"),
                logger: Logger.shared,
                nftViewModelFactory: NftSendConfirmViewModelFactory(),
                dataValidatingFactory: validating,
                submissionAuthorizer: authorizer
            )
            validating.view = view
            presenter.didLoad(view: view)
        }
    }

    func testLoadProvidesAccountsNftAndEstimatesFee() {
        let context = Context()
        XCTAssertTrue(context.interactor.output === context.presenter)
        XCTAssertEqual(context.view.senders.first??.title, context.wallet.name)
        XCTAssertEqual(context.view.senders.first??.name, CovHNftFixtures.address(of: context.wallet, on: context.chain))
        XCTAssertEqual(context.view.receivers.first??.name, "receiver")
        XCTAssertEqual(context.view.nftViewModels.first?.collectionName, "Confirm collection")
        XCTAssertNotNil(context.view.nftViewModels.first?.nftImage)
        XCTAssertEqual(context.view.nftViewModels.first?.showWarning, false)
        XCTAssertEqual(context.interactor.estimates, ["receiver"])

        context.presenter.didBackButtonTapped()
        context.presenter.applyLocalization()
        XCTAssertEqual(context.router.calls, ["dismiss"])
    }

    func testWalletWithoutAccountHasNoSender() {
        let context = Context(wallet: CovHNftFixtures.walletWithoutAccounts())
        XCTAssertTrue(context.view.senders.isEmpty)
        XCTAssertEqual(context.view.receivers.count, 1)
    }

    func testConfirmValidatesAuthorizesAndSubmits() {
        let context = Context()
        context.presenter.didConfirmButtonTapped()
        XCTAssertEqual(context.router.calls, ["noFee"])

        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000_000))))
        XCTAssertFalse(context.view.fees.last??.amount.isEmpty ?? true)
        context.presenter.didConfirmButtonTapped()
        XCTAssertEqual(context.router.calls, ["noFee", "tooHigh"])

        let asset = context.chain.utilityChainAssets()[0]
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(3_000_000_000_000))), for: asset)
        context.authorizer.authorized = false
        context.presenter.didConfirmButtonTapped()
        XCTAssertTrue(context.interactor.submits.isEmpty)

        context.authorizer.authorized = true
        context.presenter.didConfirmButtonTapped()
        XCTAssertEqual(context.authorizer.requests, 2)
        XCTAssertEqual(context.interactor.submits, ["receiver"])
        XCTAssertEqual(context.view.loading, [true])
    }

    func testTransferResults() {
        let context = Context()
        context.presenter.didTransfer(result: .success("0xhash"))
        XCTAssertEqual(context.router.completions.first?.0, "0xhash")
        XCTAssertEqual(context.router.completions.first?.1?.asset.id, context.chain.utilityChainAssets().first?.asset.id)

        context.presenter.didTransfer(result: .failure(CovHNftError.failed))
        context.router.presentsErrors = true
        context.presenter.didTransfer(result: .failure(CovHNftError.failed))
        XCTAssertEqual(context.router.calls, ["error", "failed", "error"])
        XCTAssertEqual(context.view.loading, [false, false, false])
    }

    func testTransferWithoutUtilityAssetAndErrors() {
        let context = Context(utility: false)
        context.presenter.didTransfer(result: .success("0xhash"))
        XCTAssertTrue(context.router.completions.isEmpty)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1))))
        context.presenter.didReceiveFee(result: .failure(CovHNftError.failed))
        let asset = ChainAsset(chain: context.chain, asset: CovHNftFixtures.utilityAsset())
        context.presenter.didReceiveAccountInfo(result: .success(nil), for: asset)
        context.presenter.didReceiveAccountInfo(result: .failure(CovHNftError.failed), for: asset)
        XCTAssertTrue(context.view.fees.isEmpty)
    }
}

final class CovHNftConfirmOutputSpy: NftSendConfirmInteractorOutput {
    private let lock = NSLock()
    private var storedFees: [Result<RuntimeDispatchInfo, Error>] = []
    private var storedTransfers: [Result<String, Error>] = []
    private var storedInfos = 0

    var fees: [Result<RuntimeDispatchInfo, Error>] { lock.lock(); defer { lock.unlock() }; return storedFees }
    var transfers: [Result<String, Error>] { lock.lock(); defer { lock.unlock() }; return storedTransfers }
    var infos: Int { lock.lock(); defer { lock.unlock() }; return storedInfos }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        lock.lock()
        storedFees.append(result)
        lock.unlock()
    }

    func didTransfer(result: Result<String, Error>) {
        lock.lock()
        storedTransfers.append(result)
        lock.unlock()
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {
        lock.lock()
        storedInfos += 1
        lock.unlock()
    }
}

final class CovHNftSendConfirmInteractorTests: XCTestCase {
    func testFeeSubmitAndSubscriptions() throws {
        let chain = CovHNftFixtures.chain()
        let transfer = CovHNftTransferStub()
        let adapter = CovHNftAccountInfoAdapterSpy()
        let interactor = NftSendConfirmInteractor(
            transferService: transfer,
            accountInfoSubscriptionAdapter: adapter,
            wallet: CovHNftFixtures.wallet(),
            chain: chain
        )
        let output = CovHNftConfirmOutputSpy()
        interactor.setup(with: output)
        XCTAssertEqual(adapter.subscriptions.count, 1)

        let nft = CovHNftFixtures.nft(chain: chain)
        interactor.estimateFee(for: nft, address: "receiver")
        CovHNftWait.until { !transfer.listeners.isEmpty }
        XCTAssertEqual(transfer.estimates, ["receiver"])
        XCTAssertEqual(try output.fees.first?.get().fee, "1000000000000")

        let listener = try XCTUnwrap(transfer.listeners.first)
        listener.didReceiveFee(fee: BigUInt(7))
        listener.didReceiveFeeError(feeError: CovHNftError.failed)
        CovHNftWait.until { output.fees.count == 3 }
        XCTAssertEqual(try output.fees[1].get().fee, "7")

        transfer.fee = .failure(CovHNftError.failed)
        interactor.estimateFee(for: nft, address: nil)
        CovHNftWait.until { output.fees.count == 4 }
        XCTAssertThrowsError(try output.fees[3].get())

        interactor.submitExtrinsic(nft: nft, receiverAddress: "receiver")
        CovHNftWait.until { output.transfers.count == 1 }
        XCTAssertEqual(try output.transfers.first?.get(), "0xhash")

        transfer.submitResult = .failure(CovHNftError.failed)
        interactor.submitExtrinsic(nft: nft, receiverAddress: "receiver")
        CovHNftWait.until { output.transfers.count == 2 }
        XCTAssertThrowsError(try output.transfers[1].get())
        XCTAssertEqual(transfer.submits, ["receiver", "receiver"])

        interactor.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chain.utilityChainAssets()[0])
        XCTAssertEqual(output.infos, 1)
    }

    func testSetupWithoutUtilityDoesNotSubscribe() {
        let adapter = CovHNftAccountInfoAdapterSpy()
        let interactor = NftSendConfirmInteractor(
            transferService: CovHNftTransferStub(),
            accountInfoSubscriptionAdapter: adapter,
            wallet: CovHNftFixtures.wallet(),
            chain: CovHNftFixtures.chain(utility: false)
        )
        interactor.setup(with: CovHNftConfirmOutputSpy())
        XCTAssertTrue(adapter.subscriptions.isEmpty)
    }
}

final class CovHNftSendConfirmRoutingAndViewTests: XCTestCase {
    func testCompleteDismissesAndShowsAllDoneOnPresenter() throws {
        let host = CovHNftHostController()
        let navigation = CovHNftNavigationSpy(rootViewController: host)
        let presenting = CovHNftHostController()
        navigation.presentingOverride = presenting
        let router = NftSendConfirmRouter()

        router.complete(on: host, title: "0xhash", chainAsset: nil)
        XCTAssertEqual(navigation.dismissCount, 1)
        XCTAssertTrue(presenting.presented.isEmpty)

        let chain = CovHNftFixtures.chain()
        router.complete(on: host, title: "0xhash", chainAsset: chain.utilityChainAssets().first)
        XCTAssertEqual(navigation.dismissCount, 2)
        let done = try XCTUnwrap(presenting.presented.first)
        XCTAssertTrue(done is AllDoneViewController)
        XCTAssertEqual(done.modalPresentationStyle, .custom)
    }

    func testViewModelFactory() {
        let chain = CovHNftFixtures.chain()
        let factory = NftSendConfirmViewModelFactory()
        let withImage = factory.buildViewModel(nft: CovHNftFixtures.nft(chain: chain, thumbnail: "https://image.invalid/x.png", collectionName: "C"))
        XCTAssertNotNil(withImage.nftImage)
        XCTAssertEqual(withImage.collectionName, "C")
        let bare = factory.buildViewModel(nft: CovHNftFixtures.nft(chain: chain, collectionName: nil))
        XCTAssertNil(bare.nftImage)
        XCTAssertNil(bare.collectionName)
        XCTAssertFalse(bare.showWarning)
    }

    func testControllerBindsViewModelsAndForwardsTaps() {
        let output = CovHNftConfirmViewOutputSpy()
        let controller = NftSendConfirmViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.calls, ["load", "back", "confirm"])

        let image = UIImage()
        controller.didReceive(nftViewModel: NftSendConfirmViewModel(nftImage: BundleImageViewModel(image: image), collectionName: "Coll", showWarning: false))
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.1 CVH", price: "$2"))
        controller.didReceive(senderViewModel: AccountViewModel(title: "Wallet", name: "sender-address", icon: nil))
        controller.didReceive(receiverViewModel: AccountViewModel(title: "Receiver", name: "receiver-address", icon: nil))
        XCTAssertTrue(root.imageView.image === image)
        XCTAssertEqual(root.collectionView.valueTop.text, "Coll")
        XCTAssertEqual(root.feeView.valueTop.text, "0.1 CVH")
        XCTAssertEqual(root.feeView.valueBottom.text, "$2")
        XCTAssertEqual(root.senderView.valueTop.text, "sender-address")
        XCTAssertEqual(root.senderView.valueBottom.text, "Wallet")
        XCTAssertEqual(root.receiverView.valueTop.text, "receiver-address")

        controller.didStartLoading()
        XCTAssertFalse(root.confirmButton.isUserInteractionEnabled)
        controller.didStopLoading()
        XCTAssertTrue(root.confirmButton.isUserInteractionEnabled)

        controller.didReceive(feeViewModel: nil)
        XCTAssertNil(root.feeView.valueTop.text)
        controller.applyLocalization()
        XCTAssertEqual(root.locale, controller.selectedLocale)
    }

    func testLayoutLocalizesAndRoundsBackButton() {
        let layout = NftSendConfirmViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let english = Locale(identifier: "en")
        layout.locale = english
        layout.setNeedsLayout()
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.senderView.titleLabel.text, R.string.localizable.transactionDetailsFrom(preferredLanguages: english.rLanguages))
        XCTAssertEqual(layout.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: english.rLanguages))
        XCTAssertEqual(layout.confirmButton.imageWithTitleView?.title, R.string.localizable.commonConfirm(preferredLanguages: english.rLanguages))
        XCTAssertEqual(layout.senderView.valueTop.textAlignment, .right)
        XCTAssertTrue(layout.receiverWarningButton.isHidden)
        layout.bind(receiverViewModel: nil)
        layout.bind(senderViewModel: nil)
        XCTAssertNil(layout.receiverView.valueTop.text)
        XCTAssertNil(layout.senderView.valueBottom.text)
    }
}

final class CovHNftConfirmViewOutputSpy: NftSendConfirmViewOutput {
    private(set) var calls: [String] = []

    func didLoad(view _: NftSendConfirmViewInput) { calls.append("load") }
    func didBackButtonTapped() { calls.append("back") }
    func didConfirmButtonTapped() { calls.append("confirm") }
}
