import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRewardDetailsTests: XCTestCase {
    func testSetup_thenBuildsAndReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertEqual(fixture.view.viewModel?.value(for: Locale.current).rows.count, 4)
        XCTAssertEqual(fixture.viewModelFactory.lastInput?.payoutInfo.era, 9)
    }

    func testHandlePayoutAction_thenRoutesToConfirmation() {
        let fixture = makeFixture()

        fixture.presenter.handlePayoutAction()

        XCTAssertEqual(fixture.wireframe.confirmationPayoutEra, 9)
        XCTAssertEqual(fixture.wireframe.confirmationChainAssetId, fixture.chainAsset.identifier)
    }

    func testHandleValidatorAccountAction_whenAddressAvailable_thenPresentsAccountOptions() {
        let fixture = makeFixture()

        fixture.presenter.handleValidatorAccountAction(locale: Locale.current)

        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chainAsset.chain.chainId)
    }

    func testHandleValidatorAccountAction_whenAddressMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.viewModelFactory.validatorAddressToReturn = nil

        fixture.presenter.handleValidatorAccountAction(locale: Locale.current)

        XCTAssertNil(fixture.wireframe.accountOptionsAddress)
    }

    private func makeFixture() -> StakingRewardDetailsFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let input = StakingRewardDetailsInput(
            payoutInfo: PayoutInfo(
                era: 9,
                validator: Data(repeating: 1, count: 32),
                reward: 2,
                identity: nil
            ),
            chain: chainAsset.chain,
            activeEra: 10,
            historyDepth: 84
        )
        let viewModelFactory = StakingRewardDetailsViewModelFactorySpy()
        let presenter = StakingRewardDetailsPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            input: input,
            viewModelFactory: viewModelFactory
        )
        let wireframe = StakingRewardDetailsWireframeSpy()
        let view = StakingRewardDetailsViewSpy()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = StakingRewardDetailsInteractorInputSpy()

        return StakingRewardDetailsFixture(
            presenter: presenter,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset
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

private struct StakingRewardDetailsFixture {
    let presenter: StakingRewardDetailsPresenter
    let wireframe: StakingRewardDetailsWireframeSpy
    let view: StakingRewardDetailsViewSpy
    let viewModelFactory: StakingRewardDetailsViewModelFactorySpy
    let chainAsset: ChainAsset
}

private final class StakingRewardDetailsInteractorInputSpy: StakingRewardDetailsInteractorInputProtocol {}

private final class StakingRewardDetailsViewSpy: StakingRewardDetailsViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var viewModel: LocalizableResource<StakingRewardDetailsViewModel>?

    func reload(with viewModel: LocalizableResource<StakingRewardDetailsViewModel>) {
        self.viewModel = viewModel
    }

    func applyLocalization() {}
}

private final class StakingRewardDetailsViewModelFactorySpy:
    StakingRewardDetailsViewModelFactoryProtocol {
    private(set) var lastInput: StakingRewardDetailsInput?
    var validatorAddressToReturn: AccountAddress? = WestendStub.address

    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData _: PriceData?
    ) -> LocalizableResource<StakingRewardDetailsViewModel> {
        lastInput = input

        return LocalizableResource { _ in
            StakingRewardDetailsViewModel(rows: [
                .validatorInfo(AccountInfoViewModel(title: "Validator", address: WestendStub.address, name: "validator", icon: nil)),
                .date(StakingRewardDetailsSimpleLabelViewModel(titleText: "Date", valueText: "Today")),
                .era(StakingRewardDetailsSimpleLabelViewModel(titleText: "Era", valueText: "9")),
                .reward(StakingRewardTokenUsdViewModel(title: "Reward", tokenAmountText: "2 UNIT", usdAmountText: nil))
            ])
        }
    }

    func validatorAddress(
        from _: Data,
        addressType _: fearless.SNAddressType
    ) -> AccountAddress? {
        validatorAddressToReturn
    }

    func validatorAddress(
        from _: Data,
        addressPrefix _: UInt16
    ) -> AccountAddress? {
        validatorAddressToReturn
    }
}

private final class StakingRewardDetailsWireframeSpy: StakingRewardDetailsWireframeProtocol {
    private(set) var confirmationPayoutEra: EraIndex?
    private(set) var confirmationChainAssetId: String?
    private(set) var accountOptionsAddress: String?
    private(set) var accountOptionsChainId: ChainModel.Id?

    func showPayoutConfirmation(
        from _: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        confirmationPayoutEra = payoutInfo.era
        confirmationChainAssetId = chainAsset.identifier
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
}
