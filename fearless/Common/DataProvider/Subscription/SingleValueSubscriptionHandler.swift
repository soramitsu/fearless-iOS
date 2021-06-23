import Foundation
import BigInt

protocol SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for assetId: WalletAssetId)

    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        address: AccountAddress,
        assetId: WalletAssetId
    )

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress)

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain: Chain)

    func handleNomination(result: Result<Nomination?, Error>, address: AccountAddress)

    func handleValidator(result: Result<ValidatorPrefs?, Error>, address: AccountAddress)

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address: AccountAddress)

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain: Chain)

    func handlePayee(result: Result<RewardDestinationArg?, Error>, address: AccountAddress)

    func handleBlockNumber(result: Result<BlockNumber?, Error>, chain: Chain)

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chain: Chain)

    func handleCounterForNominators(result: Result<UInt32?, Error>, chain: Chain)

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chain: Chain)
}

extension SingleValueSubscriptionHandler {
    func handlePrice(result _: Result<PriceData?, Error>, for _: WalletAssetId) {}

    func handleTotalReward(
        result _: Result<TotalRewardItem, Error>,
        address _: AccountAddress,
        assetId _: WalletAssetId
    ) {}

    func handleAccountInfo(result _: Result<AccountInfo?, Error>, address _: AccountAddress) {}

    func handleElectionStatus(result _: Result<ElectionStatus?, Error>, chain _: Chain) {}

    func handleNomination(result _: Result<Nomination?, Error>, address _: AccountAddress) {}

    func handleValidator(result _: Result<ValidatorPrefs?, Error>, address _: AccountAddress) {}

    func handleLedgerInfo(result _: Result<StakingLedger?, Error>, address _: AccountAddress) {}

    func handleActiveEra(result _: Result<ActiveEraInfo?, Error>, chain _: Chain) {}

    func handlePayee(result _: Result<RewardDestinationArg?, Error>, address _: AccountAddress) {}

    func handleBlockNumber(result _: Result<BlockNumber?, Error>, chain _: Chain) {}

    func handleMinNominatorBond(result _: Result<BigUInt?, Error>, chain _: Chain) {}

    func handleCounterForNominators(result _: Result<UInt32?, Error>, chain _: Chain) {}

    func handleMaxNominatorsCount(result _: Result<UInt32?, Error>, chain _: Chain) {}
}
