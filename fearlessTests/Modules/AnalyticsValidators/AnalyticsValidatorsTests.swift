import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import fearless

final class AnalyticsValidatorsTests: XCTestCase {
    private let stashAddress = "stash-address"
    private let locale = Locale(identifier: "en_US")

    func testRewardsAllocationUsesOnlyUniqueAttributableRewardEvents() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(
            targets: [
                context.firstAccountId,
                context.secondAccountId,
                context.firstAccountId,
                Data([0x01])
            ]
        )
        let otherAccountId = Data(repeating: 0x33, count: 32)
        let otherAddress = try AddressFactory.address(for: otherAccountId, chain: context.chain)
        let rewards = [
            reward(id: "first", validatorAddress: context.firstAddress, amount: 100),
            reward(id: "second", validatorAddress: context.secondAddress, amount: 300),
            reward(id: "second", validatorAddress: context.secondAddress, amount: 300),
            reward(id: "slash", validatorAddress: context.firstAddress, amount: 9900, isReward: false),
            reward(id: "other-stash", validatorAddress: context.firstAddress, amount: 10000, stashAddress: "other"),
            reward(id: "missing-validator", validatorAddress: "", amount: 20000),
            reward(id: "old-validator", validatorAddress: otherAddress, amount: 30000),
            reward(id: "   ", validatorAddress: context.firstAddress, amount: 40000)
        ]

        let viewModel = context.factory.createViewModel(
            eraValidatorInfos: [],
            eraRange: (start: 1, end: 1),
            stashAddress: stashAddress,
            rewards: rewards,
            nomination: nomination,
            identitiesByAddress: nil,
            page: .rewards,
            locale: locale
        )

        XCTAssertEqual(viewModel.validators.count, 2)
        XCTAssertEqual(viewModel.validators.map(\.validatorAddress), [context.secondAddress, context.firstAddress])
        XCTAssertEqual(viewModel.validators.map(\.amount), [3.0, 1.0])
        XCTAssertEqual(viewModel.validators[0].progressPercents, 0.75, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.validators[1].progressPercents, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.pieChartSegmentValues.reduce(0.0, +), 1.0, accuracy: 0.000_001)
        XCTAssertTrue(viewModel.pieChartSegmentValues.allSatisfy { $0.isFinite && (0.0 ... 1.0).contains($0) })
        XCTAssertEqual(viewModel.validators.map(\.mainValueText), ["3", "1"])
        XCTAssertEqual(
            viewModel.validators.map(\.secondaryValueText),
            [formattedPercent(0.75, locale: locale), formattedPercent(0.25, locale: locale)]
        )
        XCTAssertEqual(
            centerLines(viewModel),
            ["Received rewards", "4", formattedPercent(1.0, locale: locale)]
        )
        let placeholderMarker = ["TO", "DO"].joined()
        XCTAssertFalse(viewModel.chartCenterText.string.contains(placeholderMarker))
    }

    func testMissingAndMalformedValidatorAttributionFailsClosed() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(targets: [context.firstAccountId, context.secondAccountId])
        let rewards = [
            reward(id: "missing", validatorAddress: "", amount: 500),
            reward(id: "malformed", validatorAddress: "not-an-address", amount: 700)
        ]

        let viewModel = context.factory.createViewModel(
            eraValidatorInfos: [],
            eraRange: (start: 1, end: 1),
            stashAddress: stashAddress,
            rewards: rewards,
            nomination: nomination,
            identitiesByAddress: nil,
            page: .rewards,
            locale: locale
        )

        XCTAssertEqual(viewModel.validators.map(\.amount), [0.0, 0.0])
        XCTAssertEqual(viewModel.pieChartSegmentValues, [0.0, 0.0])
        XCTAssertTrue(viewModel.pieChartSegmentValues.allSatisfy { $0.isFinite && !$0.isNaN })
        XCTAssertEqual(
            centerLines(viewModel),
            ["Received rewards", "0", formattedPercent(0.0, locale: locale)]
        )
    }

    func testExtremeRewardAmountFailsClosedWithoutNaNOrInfinity() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(targets: [context.firstAccountId])
        let hugeAmount = try XCTUnwrap(BigUInt(String(repeating: "9", count: 200)))
        let rewards = [
            reward(id: "normal", validatorAddress: context.firstAddress, amount: 100),
            reward(id: "extreme", validatorAddress: context.firstAddress, amount: hugeAmount)
        ]

        let viewModel = context.factory.createViewModel(
            eraValidatorInfos: [],
            eraRange: (start: 1, end: 1),
            stashAddress: stashAddress,
            rewards: rewards,
            nomination: nomination,
            identitiesByAddress: nil,
            page: .rewards,
            locale: locale
        )

        XCTAssertEqual(viewModel.validators.first?.amount, 0.0)
        XCTAssertEqual(viewModel.validators.first?.progressPercents, 0.0)
        XCTAssertEqual(viewModel.pieChartSegmentValues, [0.0])
        XCTAssertTrue(viewModel.pieChartSegmentValues.allSatisfy { $0.isFinite && !$0.isNaN })
        XCTAssertEqual(centerLines(viewModel), ["Received rewards", "0", formattedPercent(0.0, locale: locale)])
    }

    func testUnsupportedAssetPrecisionFailsClosed() throws {
        let context = try makeContext(precision: .max)
        let nomination = try makeNomination(targets: [context.firstAccountId])
        let viewModel = context.factory.createViewModel(
            eraValidatorInfos: [],
            eraRange: (start: 1, end: 1),
            stashAddress: stashAddress,
            rewards: [reward(id: "reward", validatorAddress: context.firstAddress, amount: 100)],
            nomination: nomination,
            identitiesByAddress: nil,
            page: .rewards,
            locale: locale
        )

        XCTAssertEqual(viewModel.validators.first?.amount, 0.0)
        XCTAssertEqual(viewModel.validators.first?.progressPercents, 0.0)
        XCTAssertEqual(centerLines(viewModel), ["Received rewards", "0", formattedPercent(0.0, locale: locale)])
    }

    func testOutOfRangeEraDataIsExcludedFromActivityPercentages() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(targets: [context.firstAccountId, context.secondAccountId])
        let eraInfos = [
            try makeEraInfo(address: context.firstAddress, era: 10),
            try makeEraInfo(address: context.firstAddress, era: 11),
            try makeEraInfo(address: context.firstAddress, era: 11),
            try makeEraInfo(address: context.firstAddress, era: 100),
            try makeEraInfo(address: context.secondAddress, era: 12)
        ]

        let viewModel = context.factory.createViewModel(
            eraValidatorInfos: eraInfos,
            eraRange: (start: 10, end: 12),
            stashAddress: stashAddress,
            rewards: [],
            nomination: nomination,
            identitiesByAddress: nil,
            page: .activity,
            locale: locale
        )

        XCTAssertEqual(viewModel.validators.map(\.amount), [2.0, 1.0])
        XCTAssertEqual(viewModel.validators[0].progressPercents, 2.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.validators[1].progressPercents, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.pieChartInactiveSegment?.percents, 0.0)
        XCTAssertEqual(viewModel.pieChartInactiveSegment?.eraCount, 0)
        XCTAssertTrue(viewModel.pieChartSegmentValues.allSatisfy { $0.isFinite && (0.0 ... 1.0).contains($0) })
    }

    func testMalformedTargetsAndEraRangeBoundariesDoNotCrashOrProduceInvalidValues() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(
            targets: [context.firstAccountId, Data([0x01]), context.firstAccountId]
        )
        let ranges: [EraRange] = [
            (start: 10, end: 9),
            (start: .max, end: .max)
        ]

        for eraRange in ranges {
            let viewModel = context.factory.createViewModel(
                eraValidatorInfos: [],
                eraRange: eraRange,
                stashAddress: stashAddress,
                rewards: [],
                nomination: nomination,
                identitiesByAddress: nil,
                page: .activity,
                locale: locale
            )

            XCTAssertEqual(viewModel.validators.count, 1)
            XCTAssertEqual(viewModel.validators.first?.progressPercents, 0.0)
            XCTAssertEqual(viewModel.pieChartInactiveSegment?.percents, 1.0)
            XCTAssertEqual(viewModel.pieChartInactiveSegment?.eraCount, 1)
            XCTAssertTrue(viewModel.pieChartSegmentValues.allSatisfy { $0.isFinite && !$0.isNaN })
        }
    }

    func testReceivedRewardsTitleIsLocalized() throws {
        let context = try makeContext(precision: 2)
        let nomination = try makeNomination(targets: [context.firstAccountId])
        let expectations: [(String, String)] = [
            ("en", "Received rewards"),
            ("ru", "Полученные вознаграждения"),
            ("ja", "受け取った報酬"),
            ("zh-Hans", "已收到的奖励")
        ]

        for (identifier, expectedTitle) in expectations {
            let viewModel = context.factory.createViewModel(
                eraValidatorInfos: [],
                eraRange: (start: 1, end: 1),
                stashAddress: stashAddress,
                rewards: [],
                nomination: nomination,
                identitiesByAddress: nil,
                page: .rewards,
                locale: Locale(identifier: identifier)
            )

            XCTAssertEqual(centerLines(viewModel).first, expectedTitle)
        }
    }
}

private extension AnalyticsValidatorsTests {
    struct Context {
        let chain: ChainModel
        let firstAccountId: Data
        let secondAccountId: Data
        let firstAddress: AccountAddress
        let secondAddress: AccountAddress
        let factory: AnalyticsValidatorsViewModelFactory
    }

    func makeContext(precision: UInt16) throws -> Context {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: precision
        )
        let asset = ChainModelGenerator.generateAssetWithId(
            "analytics-asset",
            symbol: "TST",
            assetPresicion: precision
        )
        let firstAccountId = Data(repeating: 0x11, count: 32)
        let secondAccountId = Data(repeating: 0x22, count: 32)
        let firstAddress = try AddressFactory.address(for: firstAccountId, chain: chain)
        let secondAddress = try AddressFactory.address(for: secondAccountId, chain: chain)
        let factory = AnalyticsValidatorsViewModelFactory(
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            chain: chain,
            asset: asset,
            iconGenerator: UniversalIconGenerator()
        )

        return Context(
            chain: chain,
            firstAccountId: firstAccountId,
            secondAccountId: secondAccountId,
            firstAddress: firstAddress,
            secondAddress: secondAddress,
            factory: factory
        )
    }

    func makeNomination(targets: [Data]) throws -> Nomination {
        let payload: [String: Any] = [
            "targets": targets.map { $0.toHex(includePrefix: true) },
            "submittedIn": "0"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    func makeEraInfo(address: AccountAddress, era: EraIndex) throws -> SubqueryEraValidatorInfo {
        let json = JSON.dictionaryValue([
            "address": .stringValue(address),
            "era": .unsignedIntValue(UInt64(era))
        ])
        return try XCTUnwrap(SubqueryEraValidatorInfo(from: json))
    }

    func reward(
        id: String,
        validatorAddress: AccountAddress,
        amount: BigUInt,
        stashAddress: AccountAddress? = nil,
        isReward: Bool = true
    ) -> SubqueryRewardItemData {
        SubqueryRewardItemData(
            eventId: id,
            timestamp: 0,
            validatorAddress: validatorAddress,
            era: 0,
            stashAddress: stashAddress ?? self.stashAddress,
            amount: amount,
            isReward: isReward
        )
    }

    func formattedPercent(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter.percent
        formatter.locale = locale
        return formatter.string(from: value as NSNumber) ?? ""
    }

    func centerLines(_ viewModel: AnalyticsValidatorsViewModel) -> [String] {
        viewModel.chartCenterText.string.components(separatedBy: "\n")
    }
}
