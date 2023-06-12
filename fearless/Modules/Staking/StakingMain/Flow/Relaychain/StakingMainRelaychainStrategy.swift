import Foundation
import Web3

protocol StakingMainRelaychainStrategyOutput: AnyObject {
    func didReceive(totalReward: Result<TotalRewardItem, Error>)
    func didReceive(accountInfo: Result<AccountInfo?, Error>)
    func didReceive(calculator: Result<RewardCalculatorEngineProtocol, Error>)
    func didReceive(stashItem: Result<StashItem?, Error>)
    func didReceive(ledgerInfo: Result<StakingLedger?, Error>)
    func didReceive(nomination: Result<Nomination?, Error>)
    func didReceive(validatorPrefs: Result<ValidatorPrefs?, Error>)
    func didReceive(eraStakersInfo: Result<EraStakersInfo, Error>)
    func didReceive(networkStakingInfo: Result<NetworkStakingInfo, Error>)
    func didReceive(payee: Result<RewardDestinationArg?, Error>)
    func didReceive(minNominatorBond: Result<BigUInt?, Error>)
    func didReceive(counterForNominators: Result<UInt32?, Error>)
    func didReceive(maxNominatorsCount: Result<UInt32?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
    func didReceive(maxNominatorsPerValidator: Result<UInt32, Error>)
    func didReceive(controllerAccount: Result<ChainAccountResponse?, Error>)
}

final class StakingMainRelaychainStrategy: RuntimeConstantFetching, AccountFetching {
    weak var output: StakingMainRelaychainStrategyOutput?
}
