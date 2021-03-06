import Foundation
@testable import fearless
import BigInt

struct WestendStub {
    static var price: PriceData = {
        PriceData(price: "0.3",
                  time: Int64(Date().timeIntervalSince1970),
                  height: 1,
                  records: [])
    }()

    static var accountInfo: DecodedAccountInfo = {

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

    static var recommendedValidators: [ElectedValidatorInfo] = {
        let address = "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 10.0,
                                             ownStake: 10.0,
                                             comission: 0.1,
                                             identity: AccountIdentity(name: "Test"),
                                             stakeReturn: 0.1,
                                             hasSlashes: false,
                                             oversubscribed: false)
        return [validator]
    }()

    static var otherValidators: [ElectedValidatorInfo] = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 5.0,
                                             ownStake: 5.0,
                                             comission: 0.1,
                                             identity: nil,
                                             stakeReturn: 0.1,
                                             hasSlashes: false,
                                             oversubscribed: true)
        return [validator]
    }()

    static var allValidators: [ElectedValidatorInfo] { otherValidators + recommendedValidators }

    static var eraValidators: [EraValidatorInfo] = {
        let validator = EraValidatorInfo(accountId: Data(repeating: 0, count: 32),
                                         exposure: ValidatorExposure(total: BigUInt(1e+13),
                                                                     own: BigUInt(1e+13),
                                                                     others: []),
                                         prefs: ValidatorPrefs(commission: BigUInt(1e+8)))

        return [validator]
    }()

    static var rewardCalculator: RewardCalculatorEngineProtocol = {
        let total = eraValidators.reduce(BigUInt(0)) { $0 + $1.exposure.total }
        return RewardCalculatorEngine(totalIssuance: total,
                                      validators: eraValidators,
                                      chain: .westend)
    }()
}
