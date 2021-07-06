import Foundation
@testable import fearless

struct CustomValidatorListTestDataGenerator {
    static let goodValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr1",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "Good validator"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let slashedValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr2",
            nominators: [],
            totalStake: 10.1,
            ownStake: 10.1,
            comission: 0.0,
            identity: AccountIdentity(name: "Slashed validator"),
            stakeReturn: 0.1,
            hasSlashes: true,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let oversubscribedValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr3",
            nominators: [
                NominatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7NOM1", stake: 1.0),
                NominatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7NOM2", stake: 1.0)
            ],
            totalStake: 100,
            ownStake: 100,
            comission: 0.0,
            identity: AccountIdentity(name: "Oversubscribed validator"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 1,
            blocked: false
        )
    }()

    static let clusterValidatorParent: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr4",
            nominators: [],
            totalStake: 11,
            ownStake: 11,
            comission: 0.0,
            identity: AccountIdentity(name: "Clustered validator parent"),
            stakeReturn: 0.2,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let clusterValidatorChild1: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr5",
            nominators: [],
            totalStake: 10.123,
            ownStake: 10.123,
            comission: 0.0,
            identity: AccountIdentity(
                name: "Clustered validator child 1",
                parentAddress: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr4",
                parentName: nil,
                identity: nil
            ),
            stakeReturn: 0.5,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let clusterValidatorChild2: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
            nominators: [],
            totalStake: 0.5,
            ownStake: 0.5,
            comission: 0.0,
            identity: AccountIdentity(
                name: "Clustered validator child 2",
                parentAddress: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr4",
                parentName: nil,
                identity: nil
            ),
            stakeReturn: 0.54,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let noIdentityValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
            nominators: [],
            totalStake: 16,
            ownStake: 16,
            comission: 0.0,
            identity: nil, // No identity validator
            stakeReturn: 0.2,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let poorGoodValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr8",
            nominators: [],
            totalStake: 9,
            ownStake: 9,
            comission: 0.0,
            identity: AccountIdentity(name: "Poor good validator"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let greedyGoodValidator: ElectedValidatorInfo = {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr9",
            nominators: [],
            totalStake: 98,
            ownStake: 98,
            comission: 0.0,
            identity: AccountIdentity(name: "Greedy good validator"),
            stakeReturn: 0.01,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
    }()

    static let goodValidators: [ElectedValidatorInfo] = {
        [greedyGoodValidator, poorGoodValidator, goodValidator]
    }()

    static let badValidators: [ElectedValidatorInfo] = {
        [slashedValidator, oversubscribedValidator, noIdentityValidator]
    }()

    static let clusterValidators: [ElectedValidatorInfo] = {
        [clusterValidatorParent, clusterValidatorChild1, clusterValidatorChild2]
    }()

    static func createSelectedValidators(from validators: [ElectedValidatorInfo]) -> [SelectedValidatorInfo] {
        validators.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                ),
                commission: $0.comission,
                hasSlashes: $0.hasSlashes
            )
        }
    }
}
