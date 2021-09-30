import Foundation
import SoraFoundation
import BigInt
import SoraKeystore

protocol NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel(for chainAsset: ChainAsset) -> LocalizableResource<String>
    func createNetworkStakingInfoViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chainAsset: ChainAsset,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<NetworkStakingInfoViewModelProtocol>
}

final class NetworkInfoViewModelFactory {
    private var chainAsset: ChainAsset?
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory, self.chainAsset == chainAsset {
            return factory
        }

        let factory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        )

        self.chainAsset = chainAsset
        balanceViewModelFactory = factory

        return factory
    }

    private func createStakeViewModel(
        stake: BigUInt,
        chainAsset: ChainAsset,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let stakedAmount = Decimal.fromSubstrateAmount(
            stake,
            precision: Int16(chainAsset.asset.precision)
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
        chainAsset: ChainAsset,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(
            stake: networkStakingInfo.totalStake,
            chainAsset: chainAsset,
            priceData: priceData
        )
    }

    private func createMinimalStakeViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chainAsset: ChainAsset,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(
            stake: networkStakingInfo.calculateMinimumStake(given: minNominatorBond),
            chainAsset: chainAsset,
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
        with networkStakingInfo: NetworkStakingInfo
    ) -> LocalizableResource<String> {
        // TODO: Fix eras per day
        let lockUpPeriodInDays = Int(networkStakingInfo.lockUpPeriod) / Chain.kusama.erasPerDay

        return LocalizableResource { locale in
            R.string.localizable.commonDaysFormat(
                format: lockUpPeriodInDays,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

extension NetworkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel(for chainAsset: ChainAsset) -> LocalizableResource<String> {
        LocalizableResource { _ in
            chainAsset.chain.name
        }
    }

    func createNetworkStakingInfoViewModel(
        with networkStakingInfo: NetworkStakingInfo,
        chainAsset: ChainAsset,
        minNominatorBond: BigUInt?,
        priceData: PriceData?
    ) -> LocalizableResource<NetworkStakingInfoViewModelProtocol> {
        let localizedTotalStake = createTotalStakeViewModel(
            with: networkStakingInfo,
            chainAsset: chainAsset,
            priceData: priceData
        )

        let localizedMinimalStake = createMinimalStakeViewModel(
            with: networkStakingInfo,
            chainAsset: chainAsset,
            minNominatorBond: minNominatorBond,
            priceData: priceData
        )

        let nominatorsCount = createActiveNominatorsViewModel(with: networkStakingInfo)

        let localizedLockUpPeriod = createLockUpPeriodViewModel(with: networkStakingInfo)

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
