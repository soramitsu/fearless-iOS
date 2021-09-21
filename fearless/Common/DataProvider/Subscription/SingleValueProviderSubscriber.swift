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

    func subscribeToCurrentEraProvider(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedEraIndex>?

    func subscribeToPayeeProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedPayee>?

    func subscribeToBlockNumber(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedBlockNumber>?

    func subscribeToMinNominatorBondProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedBigUInt>?

    func subscribeToCounterForNominatorsProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedU32>?

    func subscribeToMaxNominatorsCountProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedU32>?
}
