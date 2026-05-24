import BigInt
import FearlessFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class ControllerAccountConfirmationTests: XCTestCase {
    func testSetup_whenCalled_thenProvidesEmptyFeeAndSetsUpInteractor() {
        let sut = makeSut()

        sut.presenter.setup()

        XCTAssertEqual(sut.view.receivedFeeCallCount, 1)
        XCTAssertNil(sut.view.lastFeeViewModel)
        XCTAssertEqual(sut.interactor.setupCallCount, 1)
    }

    func testStashItem_whenReceived_thenFetchesStashAccountAndReloadsView() throws {
        let sut = makeSut()
        let stashAccount = makeChainAccount(name: "stash", chain: sut.chain)
        let stashAddress = try XCTUnwrap(stashAccount.toAddress())

        sut.presenter.didReceiveStashItem(result: .success(StashItem(stash: stashAddress, controller: "controller")))
        sut.presenter.didReceiveStashAccount(result: .success(stashAccount))

        XCTAssertEqual(sut.interactor.fetchedStashAddresses, [stashAddress])
        XCTAssertEqual(sut.view.reloadCallCount, 1)

        let viewModel = try XCTUnwrap(sut.view.lastConfirmationViewModel?.value(for: Locale.current))
        XCTAssertEqual(viewModel.stashViewModel.name, "stash")
        XCTAssertEqual(viewModel.stashViewModel.address, stashAddress)
        XCTAssertEqual(viewModel.controllerViewModel.name, sut.controllerAccount.name)
    }

    func testStashItem_whenMissing_thenClosesView() {
        let sut = makeSut()

        sut.presenter.didReceiveStashItem(result: .success(nil))

        XCTAssertEqual(sut.wireframe.closeCallCount, 1)
    }

    func testAccountActions_whenAddressesAvailable_thenPresentOptions() throws {
        let sut = makeSut()
        let stashAccount = makeChainAccount(name: "stash", chain: sut.chain)
        let stashAddress = try XCTUnwrap(stashAccount.toAddress())
        let controllerAddress = try XCTUnwrap(sut.controllerAccount.toAddress())

        sut.presenter.didReceiveStashAccount(result: .success(stashAccount))
        sut.presenter.handleStashAction()
        sut.presenter.handleControllerAction()

        XCTAssertEqual(sut.wireframe.presentedAccountOptions.map { $0.address }, [stashAddress, controllerAddress])
        XCTAssertEqual(sut.wireframe.presentedAccountOptions.map { $0.chainId }, [sut.chain.chainId, sut.chain.chainId])
    }

    func testConfirm_whenValidationPasses_thenStartsLoadingAndConfirms() {
        let sut = makeSut()

        sut.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(10))))
        sut.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: BigUInt(100_000))))
        sut.presenter.didReceiveStakingLedger(result: .success(nil))

        sut.presenter.confirm()

        XCTAssertEqual(sut.view.startLoadingCallCount, 1)
        XCTAssertEqual(sut.interactor.confirmCallCount, 1)
    }

    func testConfirm_whenFeeMissing_thenRequestsFeeAndDoesNotConfirm() {
        let sut = makeSut()

        sut.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: BigUInt(100_000))))
        sut.presenter.confirm()

        XCTAssertEqual(sut.interactor.estimateFeeCallCount, 1)
        XCTAssertEqual(sut.interactor.confirmCallCount, 0)
    }

    func testConfirmed_whenSuccess_thenStopsLoadingAndCompletes() {
        let sut = makeSut()

        sut.presenter.didConfirmed(result: .success("hash"))

        XCTAssertEqual(sut.view.stopLoadingCallCount, 1)
        XCTAssertEqual(sut.wireframe.completeCallCount, 1)
    }

    func testConfirmed_whenFailure_thenStopsLoadingAndPresentsFailure() {
        let sut = makeSut()

        sut.presenter.didConfirmed(result: .failure(TestError.expected))

        XCTAssertEqual(sut.view.stopLoadingCallCount, 1)
        XCTAssertEqual(sut.wireframe.completeCallCount, 0)
        XCTAssertEqual(sut.wireframe.presentedMessages.count, 1)
    }

    private func makeSut() -> ControllerAccountConfirmationSut {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: UInt16(fearless.SNAddressType.genericSubstrate.rawValue),
            assetPresicion: 12
        )
        let asset = ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot", assetPresicion: 12)
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let controllerAccount = makeChainAccount(name: "controller", chain: chain, wallet: selectedAccount)
        let view = ControllerAccountConfirmationViewSpy()
        let interactor = ControllerAccountConfirmationInteractorSpy()
        let wireframe = ControllerAccountConfirmationWireframeSpy()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        dataValidatingFactory.view = view

        let presenter = ControllerAccountConfirmationPresenter(
            controllerAccountItem: controllerAccount,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            iconGenerator: IconGeneratorSpy(),
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        return ControllerAccountConfirmationSut(
            presenter: presenter,
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            controllerAccount: controllerAccount
        )
    }

    private func makeChainAccount(
        name: String,
        chain: ChainModel,
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()
    ) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: chain.chainId,
            accountId: wallet.substrateAccountId,
            publicKey: wallet.substratePublicKey,
            name: name,
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: wallet.metaId
        )
    }

    private func makeAccountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: .zero, frozen: .zero, flags: .zero)
        )
    }
}

private struct ControllerAccountConfirmationSut {
    let presenter: ControllerAccountConfirmationPresenter
    let view: ControllerAccountConfirmationViewSpy
    let interactor: ControllerAccountConfirmationInteractorSpy
    let wireframe: ControllerAccountConfirmationWireframeSpy
    let chain: ChainModel
    let controllerAccount: ChainAccountResponse
}

private final class ControllerAccountConfirmationViewSpy: ControllerAccountConfirmationViewProtocol {
    var localizationManager: LocalizationManagerProtocol?
    let controller = UIViewController()
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    private(set) var reloadCallCount = 0
    private(set) var receivedFeeCallCount = 0
    private(set) var startLoadingCallCount = 0
    private(set) var stopLoadingCallCount = 0
    private(set) var lastConfirmationViewModel: LocalizableResource<ControllerAccountConfirmationVM>?
    private(set) var lastFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var isSetup: Bool { true }

    func applyLocalization() {}

    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>) {
        reloadCallCount += 1
        lastConfirmationViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        receivedFeeCallCount += 1
        lastFeeViewModel = viewModel
    }

    func didStartLoading() {
        startLoadingCallCount += 1
    }

    func didStopLoading() {
        stopLoadingCallCount += 1
    }
}

private final class ControllerAccountConfirmationInteractorSpy: ControllerAccountConfirmationInteractorInputProtocol {
    private(set) var setupCallCount = 0
    private(set) var confirmCallCount = 0
    private(set) var estimateFeeCallCount = 0
    private(set) var fetchedStashAddresses: [AccountAddress] = []

    func setup() {
        setupCallCount += 1
    }

    func confirm() {
        confirmCallCount += 1
    }

    func fetchStashAccountItem(for address: AccountAddress) {
        fetchedStashAddresses.append(address)
    }

    func estimateFee() {
        estimateFeeCallCount += 1
    }
}

private final class ControllerAccountConfirmationWireframeSpy: ControllerAccountConfirmationWireframeProtocol {
    private(set) var closeCallCount = 0
    private(set) var completeCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var presentedMessages: [String] = []
    private(set) var presentedAccountOptions: [(address: AccountAddress, chainId: ChainModel.Id)] = []

    func complete(from view: ControllerAccountConfirmationViewProtocol?) {
        completeCallCount += 1
    }

    func close(view: ControllerBackedProtocol?) {
        closeCallCount += 1
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissCallCount += 1
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale: Locale,
        exportClosure: (() -> Void)?
    ) {
        presentedAccountOptions.append((address, chain.chainId))
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        presentedMessages.append(String(describing: error))
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedMessages.append(viewModel.title)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append(title)
    }

    func presentInfo(message: String?, title: String, from view: ControllerBackedProtocol?) {
        presentedMessages.append(title)
    }

    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?) {
        presentedMessages.append("extrinsicFailed")
    }
}

private final class IconGeneratorSpy: IconGenerating {
    func generateFromAddress(_ address: String) throws -> DrawableIcon {
        throw TestError.expected
    }
}

private enum TestError: Error {
    case expected
}
