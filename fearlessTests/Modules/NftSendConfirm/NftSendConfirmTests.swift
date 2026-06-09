import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class NftSendConfirmTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpAndProvidesInitialViewModels() {
        let fixture = makeFixture()
        let view = NftSendConfirmViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertEqual(view.receiverViewModel?.name, fixture.receiverAddress)
        XCTAssertEqual(view.senderViewModel?.title, fixture.wallet.name)
        XCTAssertEqual(view.nftViewModel?.collectionName, "Collection")
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.last?.address, fixture.receiverAddress)
    }

    func testBackButton_whenTapped_thenDismissesView() {
        let fixture = makeFixture()
        let view = NftSendConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didBackButtonTapped()

        XCTAssertTrue(fixture.router.dismissedView === view)
    }

    func testConfirmButton_whenValidationPasses_thenSubmitsExtrinsic() {
        let fixture = makeFixture()
        let view = NftSendConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveAccountInfo(
            result: .success(makeAccountInfo(free: 10_000)),
            for: fixture.utilityChainAsset
        )
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5)))
        fixture.presenter.didConfirmButtonTapped()

        XCTAssertEqual(view.startLoadingCount, 1)
        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
        XCTAssertEqual(fixture.interactor.submitCalls.last?.receiverAddress, fixture.receiverAddress)
        XCTAssertEqual(fixture.interactor.submitCalls.last?.nft, fixture.nft)
    }

    func testTransferResult_whenSuccess_thenCompletesAndStopsLoading() {
        let fixture = makeFixture()
        let view = NftSendConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTransfer(result: .success("0xhash"))

        XCTAssertEqual(view.stopLoadingCount, 1)
        XCTAssertTrue(fixture.router.completedView === view)
        XCTAssertEqual(fixture.router.completedTitle, "0xhash")
        XCTAssertEqual(fixture.router.completedChainAsset?.chainAssetId, fixture.utilityChainAsset.chainAssetId)
    }

    func testTransferResult_whenErrorIsNotPresented_thenShowsFallbackError() {
        let fixture = makeFixture()
        let view = NftSendConfirmViewSpy()
        fixture.router.shouldPresentError = false

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTransfer(result: .failure(TestError.expected))

        XCTAssertEqual(view.stopLoadingCount, 1)
        XCTAssertEqual(fixture.router.presentedErrors.count, 1)
        XCTAssertEqual(fixture.router.extrinsicFailedCount, 1)
    }

    private func makeFixture() -> NftSendConfirmFixture {
        let interactor = NftSendConfirmInteractorInputSpy()
        let router = NftSendConfirmRouterSpy()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let nft = makeNFT()
        let receiverAddress = "receiver-address"
        let presenter = NftSendConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            scamInfo: nil,
            receiverAddress: receiverAddress,
            wallet: wallet,
            accountViewModelFactory: AccountViewModelFactorySpy(),
            nft: nft,
            logger: LoggerSpy(),
            nftViewModelFactory: NftSendConfirmViewModelFactorySpy(),
            dataValidatingFactory: SendDataValidatingFactory(presentable: router)
        )

        return NftSendConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            wallet: wallet,
            nft: nft,
            receiverAddress: receiverAddress,
            utilityChainAsset: nft.chain.utilityChainAssets()[0]
        )
    }

    private func makeNFT() -> NFT {
        let asset = makeUtilityAsset()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [asset]

        return NFT(
            chain: chain,
            tokenId: "1",
            title: "NFT #1",
            description: nil,
            smartContract: nil,
            metadata: nil,
            mediaThumbnail: nil,
            media: nil,
            tokenType: .erc721,
            collectionName: "Collection",
            collection: nil
        )
    }

    private func makeUtilityAsset() -> AssetModel {
        AssetModel(
            id: "utility",
            name: "DOT",
            symbol: "dot",
            precision: 2,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    private func makeAccountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
        )
    }
}

private struct NftSendConfirmFixture {
    let presenter: NftSendConfirmPresenter
    let interactor: NftSendConfirmInteractorInputSpy
    let router: NftSendConfirmRouterSpy
    let wallet: MetaAccountModel
    let nft: NFT
    let receiverAddress: String
    let utilityChainAsset: ChainAsset
}

private final class NftSendConfirmViewSpy: NftSendConfirmViewInput {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    private(set) var receiverViewModel: AccountViewModel?
    private(set) var senderViewModel: AccountViewModel?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var nftViewModel: NftSendConfirmViewModel?
    private(set) var startLoadingCount = 0
    private(set) var stopLoadingCount = 0

    func didReceive(receiverViewModel: AccountViewModel?) {
        self.receiverViewModel = receiverViewModel
    }

    func didReceive(senderViewModel: AccountViewModel?) {
        self.senderViewModel = senderViewModel
    }

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        self.feeViewModel = feeViewModel
    }

    func didReceive(nftViewModel: NftSendConfirmViewModel) {
        self.nftViewModel = nftViewModel
    }

    func didStartLoading() {
        startLoadingCount += 1
    }

    func didStopLoading() {
        stopLoadingCount += 1
    }
}

private final class NftSendConfirmInteractorInputSpy: NftSendConfirmInteractorInput {
    private(set) weak var output: NftSendConfirmInteractorOutput?
    private(set) var estimateFeeCalls: [(nft: NFT, address: String?)] = []
    private(set) var submitCalls: [(nft: NFT, receiverAddress: String)] = []

    func setup(with output: NftSendConfirmInteractorOutput) {
        self.output = output
    }

    func estimateFee(for nft: NFT, address: String?) {
        estimateFeeCalls.append((nft, address))
    }

    func submitExtrinsic(nft: NFT, receiverAddress: String) {
        submitCalls.append((nft, receiverAddress))
    }
}

private final class NftSendConfirmRouterSpy: NftSendConfirmRouterInput {
    var shouldPresentError = true

    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var completedView: ControllerBackedProtocol?
    private(set) var completedTitle: String?
    private(set) var completedChainAsset: ChainAsset?
    private(set) var presentedErrors: [Error] = []
    private(set) var extrinsicFailedCount = 0
    private(set) var presentedMessages: [(message: String?, title: String)] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func complete(
        on view: ControllerBackedProtocol,
        title: String,
        chainAsset: ChainAsset?
    ) {
        completedView = view
        completedTitle = title
        completedChainAsset = chainAsset
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return shouldPresentError
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        extrinsicFailedCount += 1
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append((message, title))
    }

    func presentInfo(
        message: String?,
        title: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessages.append((message, title))
    }

    func presentSuccessNotification(
        _: String,
        from _: ControllerBackedProtocol?,
        completion closure: (() -> Void)?
    ) {
        closure?()
    }
}

private struct AccountViewModelFactorySpy: AccountViewModelFactoryProtocol {
    func buildViewModel(
        title: String,
        address: String,
        locale _: Locale
    ) -> AccountViewModel {
        AccountViewModel(title: title, name: address, icon: nil)
    }

    func buildViewModel(
        title: String,
        address: String,
        name: String?,
        locale _: Locale
    ) -> AccountViewModel {
        AccountViewModel(title: title, name: name ?? address, icon: nil)
    }
}

private struct NftSendConfirmViewModelFactorySpy: NftSendConfirmViewModelFactoryProtocol {
    func buildViewModel(nft: NFT) -> NftSendConfirmViewModel {
        NftSendConfirmViewModel(
            nftImage: nil,
            collectionName: nft.collectionName,
            showWarning: false
        )
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum TestError: Error {
    case expected
}
