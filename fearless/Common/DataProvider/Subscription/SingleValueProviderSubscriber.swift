import Foundation
import RobinHood

protocol SingleValueProviderSubscriber {
    var singleValueProviderFactory: SingleValueProviderFactoryProtocol { get }

    var subscriptionHandler: SingleValueSubscriptionHandler { get }

    func subscribeToPriceProvider(
        for assetId: WalletAssetId
    ) -> AnySingleValueProvider<PriceData>?

    func subscribeToTotalRewardProvider(
        for address: AccountAddress,
        assetId: WalletAssetId
    ) -> AnySingleValueProvider<TotalRewardItem>?

    func subscribeToAccountInfoProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedAccountInfo>?

    func subscribeToElectionStatusProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedElectionStatus>?

    func subscribeToNominationProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedNomination>?

    func subcscribeToValidatorProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedValidator>?

    func subscribeToLedgerInfoProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedLedgerInfo>?

    func subscribeToActiveEraProvider(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedActiveEra>?

    func subscribeToPayeeProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedPayee>?
}
