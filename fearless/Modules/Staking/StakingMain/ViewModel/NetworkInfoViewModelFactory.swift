import Foundation
import SoraFoundation
import BigInt

protocol NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel() -> LocalizableResource<String>
    func createNetworkStakingInfoViewModel(with networkStakingInfo: NetworkStakingInfo?) ->
    LocalizableResource<NetworkStakingInfoViewModelProtocol>

    func updateChain(with newChain: Chain)
    func updatePriceData(with newPriceData: PriceData)
}

final class NetworkInfoViewModelFactory {
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    private var chain: Chain
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    var priceData: PriceData?

    init(with chain: Chain,
         primitiveFactory: WalletPrimitiveFactoryProtocol) {
        self.chain = chain
        self.primitiveFactory = primitiveFactory
    }

    private func getBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory {
            return factory
        }

        let factory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                              selectedAddressType: chain.addressType,
                                              limit: StakingConstants.maxAmount)

        self.balanceViewModelFactory = factory

        return factory
    }

    private func createStakeViewModel(stake: BigUInt) ->
    LocalizableResource<BalanceViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let stakedAmount = Decimal.fromSubstrateAmount(stake,
                                                       precision: chain.addressType.precision) ?? 0.0

        let stakedPair = balanceViewModelFactory.balanceFromPrice(stakedAmount,
                                                                  priceData: priceData)

        return LocalizableResource { locale in
            stakedPair.value(for: locale)
        }
    }

    private func createTotalStakeViewModel(with networkStakingInfo: NetworkStakingInfo) ->
    LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(stake: networkStakingInfo.totalStake)
    }

    private func createMinimalStakeViewModel(with networkStakingInfo: NetworkStakingInfo) ->
    LocalizableResource<BalanceViewModelProtocol> {
        createStakeViewModel(stake: networkStakingInfo.minimalStake)
    }

    private func createActiveNominatorsViewModel(
        with networkStakingInfo: NetworkStakingInfo) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)

            return quantityFormatter
                .string(from: networkStakingInfo.activeNominatorsCount as NSNumber) ?? ""
        }
    }

    private func createLockUpPeriodViewModel(
        with networkStakingInfo: NetworkStakingInfo) -> LocalizableResource<String> {
        let lockUpPeriodInDays = Int(networkStakingInfo.lockUpPeriod) / chain.erasPerDay

        return LocalizableResource { locale in
            R.string.localizable.stakingMainLockupPeriodValue(format: lockUpPeriodInDays,
                                                              preferredLanguages: locale.rLanguages)
        }
    }
}

extension NetworkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol {
    func updateChain(with newChain: Chain) {
        chain = newChain
        balanceViewModelFactory = nil
        priceData = nil
    }

    func updatePriceData(with newPriceData: PriceData) {
        priceData = newPriceData
    }

    func createChainViewModel() -> LocalizableResource<String> {
        LocalizableResource { locale in
            return self.chain.addressType.titleForLocale(locale)
        }
    }

    func createNetworkStakingInfoViewModel(with networkStakingInfo: NetworkStakingInfo?) ->
    LocalizableResource<NetworkStakingInfoViewModelProtocol> {
        let stakingInfo = networkStakingInfo ?? NetworkStakingInfo(totalStake: BigUInt.zero,
                                                                   minimalStake: BigUInt.zero,
                                                                   activeNominatorsCount: 0,
                                                                   lockUpPeriod: 0)

        let localizedTotalStake = createTotalStakeViewModel(with: stakingInfo)

        let localizedMinimalStake = createMinimalStakeViewModel(with: stakingInfo)

        let nominatorsCount = createActiveNominatorsViewModel(with: stakingInfo)

        let localizedLockUpPeriod = createLockUpPeriodViewModel(with: stakingInfo)

        return LocalizableResource { locale in
            NetworkStakingInfoViewModel(totalStake: localizedTotalStake.value(for: locale),
                                    minimalStake: localizedMinimalStake.value(for: locale),
                                    activeNominators: nominatorsCount.value(for: locale),
                                    lockUpPeriod: localizedLockUpPeriod.value(for: locale))
        }
    }
}
