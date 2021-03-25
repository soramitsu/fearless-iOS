import Foundation
@testable import fearless
import BigInt
import IrohaCrypto
import CommonWallet

struct WestendStub {
    static let address: String = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"

    static let price: PriceData = {
        PriceData(price: "0.3",
                  time: Int64(Date().timeIntervalSince1970),
                  height: 1,
                  records: [])
    }()

    static let totalReward: TotalRewardItem = {
        TotalRewardItem(address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
                        blockNumber: 777,
                        extrinsicIndex: 0,
                        amount: AmountDecimal(value: 777))
    }()

    static let activeEra: DecodedActiveEra = {
        let era = ActiveEraInfo(index: 777)
        return DecodedActiveEra(identifier: Chain.westend.genesisHash + "_active_era",
                                item: era)
    }()

    static let accountInfo: DecodedAccountInfo = {

        let data = DyAccountData(free: BigUInt(1e+13),
                                 reserved: BigUInt(0),
                                 miscFrozen: BigUInt(0),
                                 feeFrozen: BigUInt(0))

        let info = DyAccountInfo(nonce: 1,
                                 consumers: 0,
                                 providers: 0,
                                 data: data)

        return DecodedAccountInfo(identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                  item: info)
    }()

    static let electionStatus: DecodedElectionStatus = {
        DecodedElectionStatus(identifier: Chain.westend.genesisHash + "_election",
                              item: .close)
    }()

    static let nomination: DecodedNomination = {
        let nomination = Nomination(targets: [],
                                    submittedIn: 0)

        return DecodedNomination(identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                 item: nomination)
    }()

    static let ledgerInfo: DecodedLedgerInfo = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let accountId = try! SS58AddressFactory().accountId(from: address)
        let info = DyStakingLedger(stash: accountId,
                                   total: BigUInt(1e+12),
                                   active: BigUInt(1e+12),
                                   unlocking: [],
                                   claimedRewards: [])

        return DecodedLedgerInfo(identifier: address, item: info)
    }()

    static let validator: DecodedValidator = {
        let prefs = ValidatorPrefs(commission: BigUInt(1e+8), blocked: false)

        return DecodedValidator(identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                item: prefs)
    }()

    static let recommendedValidators: [ElectedValidatorInfo] = {
        let address = "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 10.0,
                                             ownStake: 10.0,
                                             comission: 0.1,
                                             identity: AccountIdentity(name: "Test"),
                                             stakeReturn: 0.1,
                                             hasSlashes: false,
                                             oversubscribed: false,
                                             blocked: false)
        return [validator]
    }()

    static let otherValidators: [ElectedValidatorInfo] = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 5.0,
                                             ownStake: 5.0,
                                             comission: 0.1,
                                             identity: nil,
                                             stakeReturn: 0.1,
                                             hasSlashes: false,
                                             oversubscribed: true,
                                             blocked: false)
        return [validator]
    }()

    static var allValidators: [ElectedValidatorInfo] { otherValidators + recommendedValidators }

    static let eraValidators: [EraValidatorInfo] = {
        let validator = EraValidatorInfo(accountId: Data(repeating: 0, count: 32),
                                         exposure: ValidatorExposure(total: BigUInt(1e+13),
                                                                     own: BigUInt(1e+13),
                                                                     others: []),
                                         prefs: ValidatorPrefs(commission: BigUInt(1e+8), blocked: false))

        return [validator]
    }()

    static let rewardCalculator: RewardCalculatorEngineProtocol = {
        let total = eraValidators.reduce(BigUInt(0)) { $0 + $1.exposure.total }
        return RewardCalculatorEngine(totalIssuance: total,
                                      validators: eraValidators,
                                      chain: .westend)
    }()
}
