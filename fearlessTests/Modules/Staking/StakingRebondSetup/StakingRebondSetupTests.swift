import BigInt
import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRebondSetupTests: XCTestCase {
    func testSetup_thenProvidesInitialModelsAndStartsInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertNotNil(fixture.view.inputViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertNil(fixture.view.assetViewModel)
    }

    func testModelInputs_whenReceived_thenProvidesAssetAndFeeViewModels() {
        let fixture = makeFixture()

        provideReadyState(to: fixture)

        XCTAssertEqual(fixture.view.assetViewModel?.value(for: Locale.current).balance, "5")
        XCTAssertEqual(fixture.view.feeViewModel?.value(for: Locale.current).amount, "0.001")
    }

    func testAmountUpdatesAndPercentageSelection_thenRefreshInputAndAsset() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.updateAmount(2)
        XCTAssertEqual(fixture.view.assetViewModel?.value(for: Locale.current).balance, "5")

        fixture.presenter.selectAmountPercentage(0.4)
        XCTAssertEqual(fixture.view.inputViewModel?.value(for: Locale.current).decimalAmount, Decimal(2))
    }

    func testProceed_whenValid_thenRoutesToConfirmation() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.updateAmount(2)
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.proceededAmount, 2)
        XCTAssertEqual(fixture.wireframe.proceededChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.proceededWalletId, fixture.wallet.metaId)
        XCTAssertTrue(fixture.wireframe.didProceedWithRelaychainFlow)
    }

    func testProceed_whenFeeMissing_thenRefreshesFeeAndDoesNotRoute() {
        let fixture = makeFixture()
        provideStateWithoutFee(to: fixture)

        fixture.presenter.updateAmount(2)
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.interactor.estimateFeeCalls, 1)
        XCTAssertNil(fixture.wireframe.proceededAmount)
    }

    func testClose_thenRoutesThroughWireframe() {
        let fixture = makeFixture()

        fixture.presenter.close()

        XCTAssertTrue(fixture.wireframe.closedView === fixture.view)
    }

    private func makeFixture() -> StakingRebondSetupFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingRebondSetupInteractorInputSpy()
        let wireframe = StakingRebondSetupWireframeSpy()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: wallet,
            logger: LoggerSpy()
        )
        let view = StakingRebondSetupViewSpy()
        presenter.view = view
        dataValidatingFactory.view = view

        return StakingRebondSetupFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            chainAsset: chainAsset,
            wallet: wallet,
            controllerAccount: makeAccount(address: WestendStub.address, name: "controller", chain: chainAsset.chain)
        )
    }

    private func provideReadyState(to fixture: StakingRebondSetupFixture) {
        provideStateWithoutFee(to: fixture)
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
    }

    private func provideStateWithoutFee(to fixture: StakingRebondSetupFixture) {
        fixture.presenter.didReceiveController(result: .success(fixture.controllerAccount))
        fixture.presenter.didReceiveStashItem(
            result: .success(StashItem(stash: WestendStub.address, controller: WestendStub.address))
        )
        fixture.presenter.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))
        fixture.presenter.didReceiveStakingLedger(result: .success(makeStakingLedger()))
        fixture.presenter.didReceiveActiveEra(result: .success(ActiveEraInfo(index: 777)))
    }

    private func makeStakingLedger() -> StakingLedger {
        let payload: [String: Any] = [
            "stash": Data(repeating: 1, count: 32).base64EncodedString(),
            "total": String(BigUInt(5_000_000_000_000)),
            "active": String(BigUInt.zero),
            "unlocking": [
                [
                    "value": String(BigUInt(5_000_000_000_000)),
                    "era": String(778)
                ]
            ],
            "claimedRewards": []
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return try! JSONDecoder().decode(StakingLedger.self, from: data)
    }

    private func makeChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeAccount(
        address: AccountAddress,
        name: String,
        chain: ChainModel
    ) -> fearless.ChainAccountResponse {
        let accountId = try! address.toAccountId()

        return fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: name,
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false,
            walletId: "wallet-id"
        )
    }
}

private struct StakingRebondSetupFixture {
    let presenter: StakingRebondSetupPresenter
    let interactor: StakingRebondSetupInteractorInputSpy
    let wireframe: StakingRebondSetupWireframeSpy
    let view: StakingRebondSetupViewSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let controllerAccount: fearless.ChainAccountResponse
}

private final class StakingRebondSetupInteractorInputSpy: StakingRebondSetupInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls = 0

    func setup() {
        didSetup = true
    }

    func estimateFee() {
        estimateFeeCalls += 1
    }
}

private final class StakingRebondSetupViewSpy: StakingRebondSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var inputViewModel: LocalizableResource<IAmountInputViewModel>?

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        inputViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class StakingRebondSetupWireframeSpy: StakingRebondSetupWireframeProtocol {
    private(set) weak var closedView: StakingRebondSetupViewProtocol?
    private(set) var proceededAmount: Decimal?
    private(set) var proceededChainAssetId: String?
    private(set) var proceededWalletId: String?
    private(set) var didProceedWithRelaychainFlow = false

    func proceed(
        view _: StakingRebondSetupViewProtocol?,
        amount: Decimal,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    ) {
        proceededAmount = amount
        proceededChainAssetId = chainAsset.identifier
        proceededWalletId = wallet.metaId

        if case .relaychain = flow {
            didProceedWithRelaychainFlow = true
        }
    }

    func close(view: StakingRebondSetupViewProtocol?) {
        closedView = view
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
