import Foundation
import BigInt

protocol StakingLocalSubscriptionHandler {
    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for address: AccountAddress,
        api: ChainModel.ExternalApi
    )

    func handleStashItem(result: Result<StashItem?, Error>, for address: AccountAddress)

    func handleNomination(result: Result<Nomination?, Error>, accountId: AccountId, chainId: ChainModel.Id)

    func handleValidator(
        result: Result<ValidatorPrefs?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId: ChainModel.Id)

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId: ChainModel.Id)

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId: ChainModel.Id)

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId: ChainModel.Id)

    func handleCurrentEra(result: Result<EraIndex?, Error>, chainId: ChainModel.Id)
}

extension StakingLocalSubscriptionHandler {
    func handleTotalReward(
        result _: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: ChainModel.ExternalApi
    ) {}

    func handleStashItem(result _: Result<StashItem?, Error>, for _: AccountAddress) {}

    func handleNomination(
        result _: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleValidator(
        result _: Result<ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleLedgerInfo(
        result _: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handlePayee(
        result _: Result<RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleMinNominatorBond(result _: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {}

    func handleCounterForNominators(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleMaxNominatorsCount(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleActiveEra(result _: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {}

    func handleCurrentEra(result _: Result<EraIndex?, Error>, chainId _: ChainModel.Id) {}
}
