import XCTest
@testable import fearless

class RecommendationsComposerTests: XCTestCase {
    let allValidators: [ElectedValidatorInfo] = [
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr1",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: nil,
            stakeReturn: 0.9,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(
                name: "val1",
                parentAddress: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                parentName: nil,
                identity: nil
            ),
            stakeReturn: 0.5,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val4"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val2"),
            stakeReturn: 0.6,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e8pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val5"),
            stakeReturn: 0.9,
            hasSlashes: true,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo7Bfv8Ff6e8pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val5"),
            stakeReturn: 0.9,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: true
        )
    ]

    func testClusterRemovalAndFilters() {
        // given

        let expectedValidators: [ElectedValidatorInfo] = [
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val2"),
                stakeReturn: 0.6,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            ),
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr9",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val4"),
                stakeReturn: 0.1,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            )
        ]

        let composer = RecommendationsComposer(resultSize: 10, clusterSizeLimit: 1)

        // when

        let result = composer.compose(from: allValidators)

        // then

        XCTAssertEqual(expectedValidators, result)
    }

    func testMaxSizeApplied() {
        // given

        let expectedValidators: [ElectedValidatorInfo] = [
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val2"),
                stakeReturn: 0.6,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            )
        ]

        let composer = RecommendationsComposer(resultSize: 1, clusterSizeLimit: 1)

        // when

        let result = composer.compose(from: allValidators)

        // then

        XCTAssertEqual(expectedValidators, result)
    }
}
