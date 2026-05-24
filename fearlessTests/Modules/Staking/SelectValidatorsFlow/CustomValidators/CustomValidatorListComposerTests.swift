import XCTest
@testable import fearless

final class CustomValidatorListComposerTests: XCTestCase {
    func testDefaultFilter_thenKeepsAllValidatorsSortedByEstimatedReward() {
        let allValidators = makeValidators(from: generator.goodValidators + generator.badValidators)
        let expectedResult = allValidators.sorted { $0.stakeReturn >= $1.stakeReturn }

        let composer = CustomValidatorRelaychainListComposer(filter: .defaultFilter())

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult)
    }

    func testRecommendedFilter_thenKeepsOnlyRecommendedValidatorsSortedByEstimatedReward() {
        let allValidators = makeValidators(from: generator.goodValidators + generator.badValidators)
        let expectedResult = makeValidators(from: generator.goodValidators)
            .sorted { $0.stakeReturn >= $1.stakeReturn }

        let composer = CustomValidatorRelaychainListComposer(filter: .recommendedFilter())

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult)
    }

    func testOwnStakeSort_thenSortsDescendingByOwnStake() {
        let allValidators = makeValidators(from: generator.goodValidators)
        let expectedResult = allValidators.sorted { $0.ownStake >= $1.ownStake }
        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filter.sortedBy = .ownStake

        let composer = CustomValidatorRelaychainListComposer(filter: filter)

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult)
    }

    func testClusterLimit_thenReturnsBestValidatorFromCluster() {
        let allValidators = makeValidators(from: generator.clusterValidators)
        let expectedResult = [allValidators.sorted { $0.stakeReturn >= $1.stakeReturn }.first]
        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filter.allowsClusters = .limited(amount: 1)

        let composer = CustomValidatorRelaychainListComposer(filter: filter)

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult.compactMap { $0 })
    }

    func testDisallowSlashed_thenRemovesSlashedValidators() {
        let allValidators = makeValidators(from: generator.goodValidators + [generator.slashedValidator])
        let expectedResult = makeValidators(from: generator.goodValidators)
            .sorted { $0.stakeReturn >= $1.stakeReturn }
        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filter.allowsSlashed = false

        let composer = CustomValidatorRelaychainListComposer(filter: filter)

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult)
    }

    func testMultipleCriteria_thenAppliesAllDisallowedTraitsBeforeSorting() {
        let allValidators = makeValidators(
            from: generator.goodValidators + generator.badValidators + generator.clusterValidators
        )
        let expectedValidators = makeValidators(
            from: generator.goodValidators + [generator.noIdentityValidator] + generator.clusterValidators
        )
        let expectedResult = expectedValidators.sorted { $0.stakeReturn >= $1.stakeReturn }
        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filter.allowsSlashed = false
        filter.allowsOversubscribed = false

        let composer = CustomValidatorRelaychainListComposer(filter: filter)

        XCTAssertEqual(composer.compose(from: allValidators), expectedResult)
    }

    func testDisallowedTraits_whenValidatorIsAlreadyNominated_thenKeepsValidator() {
        let nominatedSlashedValidator = SelectedValidatorInfo(
            address: generator.slashedValidator.address,
            identity: generator.slashedValidator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: generator.slashedValidator.nominators,
                totalStake: generator.slashedValidator.totalStake,
                stakeReturn: generator.slashedValidator.stakeReturn,
                maxNominatorsRewarded: generator.slashedValidator.maxNominatorsRewarded
            ),
            myNomination: .active(allocation: ValidatorTokenAllocation(amount: 1, isRewarded: true)),
            commission: generator.slashedValidator.comission,
            hasSlashes: true
        )
        let allValidators = makeValidators(from: generator.goodValidators) + [nominatedSlashedValidator]
        var filter = CustomValidatorRelaychainListFilter.recommendedFilter()
        filter.allowsClusters = .unlimited

        let composer = CustomValidatorRelaychainListComposer(filter: filter)

        XCTAssertTrue(composer.compose(from: allValidators).contains(nominatedSlashedValidator))
    }

    private var generator: CustomValidatorListTestDataGenerator.Type {
        CustomValidatorListTestDataGenerator.self
    }

    private func makeValidators(from validators: [ElectedValidatorInfo]) -> [SelectedValidatorInfo] {
        generator.createSelectedValidators(from: validators)
    }
}
