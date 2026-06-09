import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class ValidatorInfoTests: XCTestCase {
    func testSetupAndReload_thenDelegatesToInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()
        fixture.presenter.reload()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(fixture.interactor.didReload)
    }

    func testModelStateChanges_thenRendersValidatorInfoAndEmptyStates() {
        let fixture = makeFixture()

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)
        XCTAssertEqual(fixture.view.validatorInfoViewModel?.account.address, WestendStub.address)

        fixture.viewModelFactory.viewModel = nil
        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)
        XCTAssertTrue(fixture.view.didReceiveEmpty)
    }

    func testLoadingAndErrorCallbacks_thenUpdateViewAndLogError() {
        let fixture = makeFixture()

        fixture.presenter.didStartLoading()
        fixture.presenter.didReceiveError(error: TestError.expected)

        XCTAssertTrue(fixture.view.didReceiveLoading)
        XCTAssertTrue(fixture.logger.didLogError)
    }

    func testAccountOptionsAndTotalStake_thenRouteThroughWireframe() {
        let fixture = makeFixture()

        fixture.presenter.presentAccountOptions()
        fixture.presenter.presentTotalStake()

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
        XCTAssertEqual(fixture.wireframe.stakingAmountItems.count, 3)
    }

    func testMinStake_whenElectedViewModelAvailable_thenShowsInfo() {
        let fixture = makeFixture()
        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        fixture.presenter.presentMinStake()

        XCTAssertEqual(fixture.wireframe.presentedInfoTitle, "")
        XCTAssertNotNil(fixture.wireframe.presentedInfoMessage)
    }

    func testIdentityLinks_thenRouteEmailAndWeb() {
        let fixture = makeFixture()

        fixture.presenter.presentIdentityItem(.link("validator@example.com", tag: .email))
        fixture.presenter.presentIdentityItem(.link("https://fearlesswallet.io", tag: .web))

        XCTAssertEqual(fixture.wireframe.emailRecipients, ["validator@example.com"])
        XCTAssertEqual(fixture.wireframe.webUrl, URL(string: "https://fearlesswallet.io")!)
    }

    private func makeFixture() -> ValidatorInfoFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ValidatorInfoInteractorInputSpy()
        let wireframe = ValidatorInfoWireframeSpy()
        let viewModelFactory = ValidatorInfoViewModelFactorySpy()
        let state = ValidatorInfoViewModelStateSpy()
        let logger = LoggerSpy()
        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            viewModelState: state,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: LocalizationManagerProtocolSpy(),
            logger: logger
        )
        let view = ValidatorInfoViewSpy()
        presenter.view = view

        return ValidatorInfoFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            state: state,
            chainAsset: chainAsset,
            logger: logger
        )
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
}

private struct ValidatorInfoFixture {
    let presenter: ValidatorInfoPresenter
    let interactor: ValidatorInfoInteractorInputSpy
    let wireframe: ValidatorInfoWireframeSpy
    let view: ValidatorInfoViewSpy
    let viewModelFactory: ValidatorInfoViewModelFactorySpy
    let state: ValidatorInfoViewModelStateSpy
    let chainAsset: ChainAsset
    let logger: LoggerSpy
}

private final class ValidatorInfoInteractorInputSpy: ValidatorInfoInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didReload = false

    func setup() {
        didSetup = true
    }

    func reload() {
        didReload = true
    }
}

private final class ValidatorInfoViewSpy: ValidatorInfoViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var validatorInfoViewModel: ValidatorInfoViewModel?
    private(set) var didReceiveEmpty = false
    private(set) var didReceiveLoading = false
    private(set) var errorMessage: String?

    func didRecieve(state: ValidatorInfoState) {
        switch state {
        case let .validatorInfo(viewModel):
            validatorInfoViewModel = viewModel
        case .empty:
            didReceiveEmpty = true
        case .loading:
            didReceiveLoading = true
        case let .error(message):
            errorMessage = message
        }
    }

    func applyLocalization() {}
}

private final class ValidatorInfoViewModelStateSpy: ValidatorInfoViewModelState {
    weak var stateListener: ValidatorInfoModelStateListener?
    let validatorAddress: String? = WestendStub.address

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }
}

private final class ValidatorInfoViewModelFactorySpy: ValidatorInfoViewModelFactoryProtocol {
    var viewModel: ValidatorInfoViewModel? = .testValue

    func buildViewModel(
        viewModelState _: ValidatorInfoViewModelState,
        priceData _: PriceData?,
        locale _: Locale
    ) -> ValidatorInfoViewModel? {
        viewModel
    }

    func buildStakingAmountViewModels(
        viewModelState _: ValidatorInfoViewModelState,
        priceData _: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]? {
        [
            LocalizableResource { _ in StakingAmountViewModel(title: "Own", balance: BalanceViewModel(amount: "1", price: nil)) },
            LocalizableResource { _ in StakingAmountViewModel(title: "Nominators", balance: BalanceViewModel(amount: "2", price: nil)) },
            LocalizableResource { _ in StakingAmountViewModel(title: "Total", balance: BalanceViewModel(amount: "3", price: nil)) }
        ]
    }
}

private extension ValidatorInfoViewModel {
    static var testValue: ValidatorInfoViewModel {
        let minStake = BalanceViewModel(amount: "1 UNIT", price: nil)
        let exposure = Exposure(
            nominators: "1 / 16",
            myNomination: MyNomination(isRewarded: true),
            totalStake: BalanceViewModel(amount: "10 UNIT", price: nil),
            estimatedReward: "12%",
            oversubscribed: false,
            comission: "1%",
            minStakeToGetRewards: minStake
        )

        return ValidatorInfoViewModel(
            account: AccountInfoViewModel(title: "", address: WestendStub.address, name: "validator", icon: nil),
            staking: Staking(status: .elected(exposure: exposure), slashed: false),
            identity: [
                IdentityItem(title: "Email", value: .link("validator@example.com", tag: .email)),
                IdentityItem(title: "Web", value: .link("https://fearlesswallet.io", tag: .web))
            ],
            title: "Validator"
        )
    }
}

private final class ValidatorInfoWireframeSpy: ValidatorInfoWireframeProtocol {
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?
    private(set) var stakingAmountItems: [LocalizableResource<StakingAmountViewModel>] = []
    private(set) var presentedInfoMessage: String?
    private(set) var presentedInfoTitle: String?
    private(set) var emailRecipients: [String] = []
    private(set) var webUrl: URL?
    var canWriteEmail = true

    func showStakingAmounts(
        from _: ValidatorInfoViewProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    ) {
        stakingAmountItems = items
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionsAddress = address
        accountOptionsChainId = chain.chainId
    }

    @discardableResult
    func writeEmail(
        with message: SocialMessage,
        from _: ControllerBackedProtocol,
        completionHandler _: EmailComposerCompletion?
    ) -> Bool {
        emailRecipients = message.recepients
        return canWriteEmail
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webUrl = url
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedInfoMessage = message
        presentedInfoTitle = title
    }

    func presentInfo(message: String?, title: String, from _: ControllerBackedProtocol?) {
        presentedInfoMessage = message
        presentedInfoTitle = title
    }
}

private final class LocalizationManagerProtocolSpy: LocalizationManagerProtocol {
    var selectedLocalization = "en"
    let availableLocalizations = ["en"]

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping LocalizationChangeClosure
    ) {}

    func removeObserver(by _: AnyObject) {}
}

private final class LoggerSpy: LoggerProtocol {
    private(set) var didLogError = false

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {
        didLogError = true
    }
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum TestError: Error {
    case expected
}
