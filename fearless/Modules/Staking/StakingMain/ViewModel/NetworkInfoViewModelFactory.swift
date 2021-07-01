import Foundation
import SoraFoundation
import BigInt
import SoraKeystore

protocol NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel(for chain: Chain) -> LocalizableResource<String>
    func createNetworkStakingInfoViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chain: Chain,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<NetworkStakingInfoViewModelProtocol>
}

final class NetworkInfoViewModelFactory {
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    private var chain: Chain?
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?

    init(primitiveFactory: WalletPrimitiveFactoryProtocol) {
        self.primitiveFactory = primitiveFactory
    }

    private func getBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory, self.chain == chain {
            return factory
        }

        let factory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        self.chain = chain
        balanceViewModelFactory = factory

        return factory
    }

    private func createStakeViewModel(
        stake: BigUInt,
        chain: Chain,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let stakedAmount = Decimal.fromSubstrateAmount(
            stake,
            precision: chain.addressType.precision
        ) ?? 0.0

        let stakedPair = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: priceData
        )

        return LocalizableResource { locale in
            stakedPair.value(for: locale)
        }
    }

    private func createTotalStakeViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chain: Chain,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(stake: networkStakingInfo.totalStake, chain: chain, priceData: priceData)
    }

    private func createMinimalStakeViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chain: Chain,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(
            stake: networkStakingInfo.calculateMinimumStake(given: minNominatorBond),
            chain: chain,
            priceData: priceData
        )
    }

    private func createActiveNominatorsViewModel(
        with networkStakingInfo: NetworkStakingInfo
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)

            return quantityFormatter
                .string(from: networkStakingInfo.activeNominatorsCount as NSNumber) ?? ""
        }
    }

    private func createLockUpPeriodViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chain: Chain
    ) -> LocalizableResource<String> {
        let lockUpPeriodInDays = Int(networkStakingInfo.lockUpPeriod) / chain.erasPerDay

        return LocalizableResource { locale in
            R.string.localizable.stakingMainLockupPeriodValue(
                format: lockUpPeriodInDays,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

extension NetworkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel(for chain: Chain) -> LocalizableResource<String> {
        LocalizableResource { locale in
            chain.addressType.titleForLocale(locale)
        }
    }

    func createNetworkStakingInfoViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chain: Chain,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<NetworkStakingInfoViewModelProtocol> {
        let localizedTotalStake = createTotalStakeViewModel(
            with: networkStakingInfo,
            chain: chain,
            priceData: priceData
        )

        let localizedMinimalStake = createMinimalStakeViewModel(
            with: networkStakingInfo,
            chain: chain,
            minNominatorBond: minNominatorBond,
            priceData: priceData
        )

        let nominatorsCount = createActiveNominatorsViewModel(with: networkStakingInfo)

        let localizedLockUpPeriod = createLockUpPeriodViewModel(
            with: networkStakingInfo,
            chain: chain
        )

        return LocalizableResource { locale in
            NetworkStakingInfoViewModel(
                totalStake: localizedTotalStake.value(for: locale),
                minimalStake: localizedMinimalStake.value(for: locale),
                activeNominators: nominatorsCount.value(for: locale),
                lockUpPeriod: localizedLockUpPeriod.value(for: locale)
            )
        }
    }
}
