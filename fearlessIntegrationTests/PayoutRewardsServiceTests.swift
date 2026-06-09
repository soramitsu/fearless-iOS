import XCTest
import BigInt
import SSFModels
import SSFUtils
@testable import fearless

final class PayoutRewardsServiceTests: XCTestCase {
    func testNominatorPayoutInfo_whenNominatorHasExposure_thenCalculatesShareAfterCommission() throws {
        let chainAsset = makeChainAsset()
        let nominator = Data(repeating: 1, count: 32)
        let validator = Data(repeating: 2, count: 32)
        let factory = NominatorPayoutInfoFactory(
            addressPrefix: chainAsset.chain.addressPrefix,
            precision: Int16(chainAsset.asset.precision),
            chainAsset: chainAsset
        )
        let identity = AccountIdentity(name: "Validator One")
        let validatorAddress = try AddressFactory.address(
            for: validator,
            chainFormat: chainAsset.chain.chainFormat
        )
        let nominatorExposure = try makeIndividualExposure(who: nominator, value: 600)

        let payout = try factory.calculate(
            for: nominator,
            era: 42,
            validatorInfo: makeValidatorInfo(
                validator: validator,
                ownStake: 400,
                totalStake: 1_000,
                nominators: [nominatorExposure],
                commission: 100_000_000
            ),
            erasRewardDistribution: try makeRewardDistribution(
                era: 42,
                validator: validator,
                totalReward: 1_000_000_000_000,
                validatorPoints: 25,
                totalPoints: 100
            ),
            identities: [validatorAddress: identity]
        )

        XCTAssertEqual(payout?.era, 42)
        XCTAssertEqual(payout?.validator, validator)
        XCTAssertEqual(payout?.identity?.name, identity.name)
        assertDecimal(payout?.reward, equals: Decimal(string: "0.135")!)
    }

    func testNominatorPayoutInfo_whenNominatorHasNoExposure_thenReturnsNil() throws {
        let chainAsset = makeChainAsset()
        let nominator = Data(repeating: 3, count: 32)
        let validator = Data(repeating: 4, count: 32)
        let factory = NominatorPayoutInfoFactory(
            addressPrefix: chainAsset.chain.addressPrefix,
            precision: Int16(chainAsset.asset.precision),
            chainAsset: chainAsset
        )

        let payout = try factory.calculate(
            for: nominator,
            era: 7,
            validatorInfo: makeValidatorInfo(
                validator: validator,
                ownStake: 1_000,
                totalStake: 1_000,
                nominators: [],
                commission: 0
            ),
            erasRewardDistribution: try makeRewardDistribution(
                era: 7,
                validator: validator,
                totalReward: 1_000_000_000_000,
                validatorPoints: 1,
                totalPoints: 1
            ),
            identities: [:]
        )

        XCTAssertNil(payout)
    }

    func testValidatorPayoutInfo_whenValidatorHasCommission_thenCombinesOwnStakeAndCommissionRewards() throws {
        let chainAsset = makeChainAsset()
        let validator = Data(repeating: 5, count: 32)
        let factory = ValidatorPayoutInfoFactory(chainAsset: chainAsset)
        let nominatorExposure = try makeIndividualExposure(
            who: Data(repeating: 6, count: 32),
            value: 600
        )

        let payout = try factory.calculate(
            for: Data(repeating: 9, count: 32),
            era: 99,
            validatorInfo: makeValidatorInfo(
                validator: validator,
                ownStake: 400,
                totalStake: 1_000,
                nominators: [nominatorExposure],
                commission: 100_000_000
            ),
            erasRewardDistribution: try makeRewardDistribution(
                era: 99,
                validator: validator,
                totalReward: 1_000_000_000_000,
                validatorPoints: 25,
                totalPoints: 100
            ),
            identities: [:]
        )

        XCTAssertEqual(payout?.era, 99)
        XCTAssertEqual(payout?.validator, validator)
        assertDecimal(payout?.reward, equals: Decimal(string: "0.115")!)
    }

    func testValidatorResolutionFactory_whenAddressProvided_thenResolvesOwnAccountId() throws {
        let chainAsset = makeChainAsset()
        let accountId = Data(repeating: 7, count: 32)
        let address = try AddressFactory.address(for: accountId, chain: chainAsset.chain)
        let factory = PayoutValidatorsForValidatorFactory(chainAsset: chainAsset)

        let wrapper = factory.createResolutionOperation(for: address) { nil }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertEqual(try wrapper.targetOperation.extractNoCancellableResultData(), [accountId])
    }

    func testFactoryAssembly_whenSoraStakingApiUsesPiIndexer_thenCreatesSoraNominatorFactory() {
        let chainAsset = makeChainAsset(
            stakingType: "sora",
            stakingURL: URL(string: "https://pi.soramitsu.io/graphql")!
        )

        let factory = PayoutValidatorsFactoryAssembly.createPayoutValidatorsFactory(chainAsset: chainAsset)

        XCTAssertEqual(chainAsset.chain.externalApi?.staking?.url.host, "pi.soramitsu.io")
        XCTAssertTrue(factory is SoraSubsquidPayoutValidatorsForNominatorFactory)
    }

    private func makeRewardDistribution(
        era: EraIndex,
        validator: Data,
        totalReward: BigUInt,
        validatorPoints: RewardPoint,
        totalPoints: RewardPoint
    ) throws -> ErasRewardDistribution {
        ErasRewardDistribution(
            totalValidatorRewardByEra: [era: totalReward],
            validatorPointsDistributionByEra: [
                era: try makeEraRewardPoints(
                    validator: validator,
                    validatorPoints: validatorPoints,
                    totalPoints: totalPoints
                )
            ]
        )
    }

    private func makeEraRewardPoints(
        validator: Data,
        validatorPoints: RewardPoint,
        totalPoints: RewardPoint
    ) throws -> EraRewardPoints {
        let json = """
        {
          "total": "\(totalPoints)",
          "individual": [
            ["\(validator.toHex(includePrefix: true))", "\(validatorPoints)"]
          ]
        }
        """

        return try JSONDecoder().decode(EraRewardPoints.self, from: Data(json.utf8))
    }

    private func makeIndividualExposure(who: Data, value: BigUInt) throws -> IndividualExposure {
        let json = """
        {
          "who": "\(who.toHex(includePrefix: true))",
          "value": "\(value)"
        }
        """

        return try JSONDecoder().decode(IndividualExposure.self, from: Data(json.utf8))
    }

    private func makeValidatorInfo(
        validator: Data,
        ownStake: BigUInt,
        totalStake: BigUInt,
        nominators: [IndividualExposure],
        commission: BigUInt
    ) -> EraValidatorInfo {
        EraValidatorInfo(
            accountId: validator,
            exposure: ValidatorExposure(
                total: totalStake,
                own: ownStake,
                others: nominators
            ),
            prefs: ValidatorPrefs(
                commission: commission,
                blocked: false
            )
        )
    }

    private func makeChainAsset(
        stakingType: String? = nil,
        stakingURL: URL? = nil
    ) -> ChainAsset {
        let asset = AssetModel(
            id: "xor",
            name: "SORA",
            symbol: "xor",
            precision: 12,
            isUtility: true,
            isNative: true,
            type: .normal
        )

        let staking = stakingType.flatMap { type in
            ChainModel.BlockExplorer(
                type: type,
                url: stakingURL ?? URL(string: "https://staking.example.com/graphql")!
            )
        }
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            paraId: nil,
            name: "SORA Mainnet",
            assets: [asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "wss://node.example.com")!,
                    name: "Node",
                    apikey: nil
                )
            ],
            addressPrefix: 69,
            icon: nil,
            externalApi: ChainModel.ExternalApiSet(staking: staking),
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func assertDecimal(
        _ actual: Decimal?,
        equals expected: Decimal,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected decimal value", file: file, line: line)
            return
        }

        XCTAssertEqual(
            NSDecimalNumber(decimal: actual).doubleValue,
            NSDecimalNumber(decimal: expected).doubleValue,
            accuracy: 0.000_000_001,
            file: file,
            line: line
        )
    }
}
