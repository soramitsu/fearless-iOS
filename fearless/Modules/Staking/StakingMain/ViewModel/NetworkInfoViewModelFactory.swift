import Foundation
import SoraFoundation
import BigInt

protocol NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel() -> LocalizableResource<String>
    func createEraStakingInfoViewModel(with eraStakersInfo: EraStakersInfo) ->
    LocalizableResource<EraStakingInfoViewModelProtocol>
    func createEraLockUpPeriodViewModel(with eraLockUpPeriodInEras: UInt32) -> LocalizableResource<String>

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

        let staked = balanceViewModelFactory.balanceFromPrice(stakedAmount,
                                                              priceData: priceData)

        return LocalizableResource { locale in
            staked.value(for: locale)
        }
    }

    private func createTotalStakeViewModel(with eraStakersInfo: EraStakersInfo) ->
    LocalizableResource<BalanceViewModelProtocol> {
        let totalStake = eraStakersInfo.validators
            .map({$0.exposure.total})
            .reduce(0, +)

        return createStakeViewModel(stake: totalStake)
    }

    private func createMinimalStakeViewModel(with eraStakersInfo: EraStakersInfo) ->
    LocalizableResource<BalanceViewModelProtocol> {
        let minimalStake = eraStakersInfo.validators
            .flatMap({$0.exposure.others})
            .compactMap({$0.value})
            .min() ?? BigUInt.zero

        return createStakeViewModel(stake: minimalStake)
    }

    private func createActiveNominatorsViewModel(with eraStakersInfo: EraStakersInfo) -> String {
        let nominatorsCount = eraStakersInfo.validators
            .flatMap({$0.exposure.others}).count

        return String(nominatorsCount)
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

    func createEraStakingInfoViewModel(with eraStakersInfo: EraStakersInfo) ->
    LocalizableResource<EraStakingInfoViewModelProtocol> {
        let localizedTotalStake = createTotalStakeViewModel(with: eraStakersInfo)

        let localizedMinimalStake = createMinimalStakeViewModel(with: eraStakersInfo)

        let nominatorsCount = createActiveNominatorsViewModel(with: eraStakersInfo)

        return LocalizableResource { locale in
            EraStakingInfoViewModel(totalStake: localizedTotalStake.value(for: locale),
                                    minimalStake: localizedMinimalStake.value(for: locale),
                                    activeNominators: nominatorsCount)
        }
    }

    func createEraLockUpPeriodViewModel(with eraLockUpPeriodInEras: UInt32) -> LocalizableResource<String> {
        let lockUpPeriodInDays = Int(eraLockUpPeriodInEras) / chain.erasPerDay

        return LocalizableResource { locale in
            R.string.localizable.stakingMainLockupPeriodValue(format: lockUpPeriodInDays,
                                                              preferredLanguages: locale.rLanguages)
        }
    }
}
