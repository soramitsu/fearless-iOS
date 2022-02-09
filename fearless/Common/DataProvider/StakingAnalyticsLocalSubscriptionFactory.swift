import Foundation
import RobinHood

protocol StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for address: AccountAddress,
        url: URL
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]>
}

final class StakingAnalyticsLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func saveProvider(_ provider: AnyObject, for key: String) {
        providers[key] = WeakWrapper(target: provider)
    }

    func getProvider(for key: String) -> AnyObject? { providers[key]?.target }

    func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension StakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for address: AccountAddress,
        url: URL
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]> {
        clearIfNeeded()

        let identifier = "weaklyAnalytics" + address + url.absoluteString

        if let provider = getProvider(for: identifier) as? SingleValueProvider<[SubqueryRewardItemData]> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade)
            .createSingleValueRepository()

        let operationFactory = SubqueryRewardOperationFactory(url: url)
        let source = WeaklyAnalyticsRewardSource(
            address: address,
            operationFactory: operationFactory
        )

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: repository
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }
}
