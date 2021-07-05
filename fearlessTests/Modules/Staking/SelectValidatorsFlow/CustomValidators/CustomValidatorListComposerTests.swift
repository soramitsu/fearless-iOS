import XCTest
@testable import fearless

class CustomValidatorListComposerTests: XCTestCase {
    private func createSelectedValidators(from validators: [ElectedValidatorInfo]) -> [SelectedValidatorInfo] {
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

    func testDefaultFilter() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )
        let expectedResult = allValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.defaultFilter()
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }

    func testRecommendedFilter() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self

        let allValidators = createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )

        let goodValidators = createSelectedValidators(from: generator.goodValidators)

        let expectedResult = goodValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.recommendedFilter()
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }

    func testSort() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = createSelectedValidators(from: generator.goodValidators)
        let expectedResult = allValidators.sorted {
            $0.ownStake >= $1.ownStake
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.sortedBy = .ownStake
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }

    func testClustersRemoval() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = createSelectedValidators(from: generator.clusterValidators)
        let expectedResult = [
            allValidators.sorted {
                $0.stakeReturn >= $1.stakeReturn
            }.first
        ]

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsClusters = .limited(amount: 1)
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }

    func testSlashesRemoval() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = createSelectedValidators(
            from: generator.goodValidators +
                [generator.slashedValidator]
        )

        let goodValidators = createSelectedValidators(from: generator.goodValidators)

        let expectedResult = goodValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsSlashed = false
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }

    func testTwoFilterCriteria() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = createSelectedValidators(
            from:  generator.goodValidators +
                generator.badValidators +
                generator.clusterValidators
        )

        let expectedValidators = createSelectedValidators(
            from: generator.goodValidators +
                [generator.noIdentityValidator] +
                generator.clusterValidators
        )

        let expectedResult = expectedValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsSlashed = false
        filter.allowsOversubscribed = false
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators)

        //then

        XCTAssertEqual(result, expectedResult)
    }
}
