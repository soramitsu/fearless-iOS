import Foundation
import SoraKeystore
import SoraFoundation

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    init(primitiveFactory: WalletPrimitiveFactoryProtocol) {
        self.primitiveFactory = primitiveFactory
    }

    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )
    }

    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType
        )
    }
}
