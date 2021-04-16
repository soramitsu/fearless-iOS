import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(input: StakingRewardDetailsInput) -> StakingRewardDetailsViewProtocol? {
        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: input.chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingRewardDetailsPresenter(
            payoutInfo: input.payoutInfo,
            activeEra: input.activeEra,
            chain: input.chain,
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: PolkadotIconGenerator()
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        let interactor = StakingRewardDetailsInteractor()
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
