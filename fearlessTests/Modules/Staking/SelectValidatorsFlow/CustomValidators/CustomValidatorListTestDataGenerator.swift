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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 10,
            ownStake: 10,
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
            totalStake: 9,
            ownStake: 9,
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
}
