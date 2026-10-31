import Foundation
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import BigInt

struct AssetHubPayoutPage {
    let era: EraIndex
    let validator: AccountId
    let index: UInt32
    let exposure: ValidatorExposurePage
}

private struct AssetHubPayoutEra {
    let reward: BigUInt
    let points: EraRewardPoints
}

private struct AssetHubPayoutValidator {
    let claimed: [StringScaleMapper<UInt32>]
    let overview: ValidatorExposureMetadata
    let prefs: ValidatorPrefs
    let incentive: BigUInt
}

struct AssetHubPayoutsOperationFactory {
    let chain: ChainModel
    let account: AccountId
    let runtime: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    var storage: AsyncStorageRequestFactory = AsyncStorageRequestDefault()

    func create() -> CompoundOperationWrapper<PayoutsInfo> {
        CompoundOperationWrapper(targetOperation: AwaitOperation { try await fetch() })
    }

    private func fetch() async throws -> PayoutsInfo {
        let coder = try await runtime.fetchCoderFactory()
        let hash: String = try await JSONRPCListWorker(engine: engine, method: RPCMethod.getFinalizedBlockHash, parameters: []).performCall()
        let scanner = AssetHubPagedStorage(engine: engine, runtime: coder, block: try Data(hexStringSSF: hash), storage: storage)
        let queries = AssetHubStakingQueries(scanner: scanner)
        let active: ActiveEraInfo = try await queries.plain(.activeEra)
        let current: StringScaleMapper<EraIndex> = try await queries.plain(.currentEra)
        let constant = PrimitiveConstantOperation<UInt32>(path: .historyDepth)
        constant.codingFactory = coder
        constant.start()
        let depth = try constant.extractNoCancellableResultData()
        let history = ChainHistoryRange(currentEra: current.value, activeEra: active.index, historyDepth: depth)
        let eras = Set(history.eraList)
        let deadline = Date().addingTimeInterval(scanner.maximumDuration)
        let pages = try await discoverPages(queries: queries, eras: eras)
        var eraCache: [EraIndex: AssetHubPayoutEra] = [:]
        var validatorCache: [String: AssetHubPayoutValidator] = [:]
        var claimCache: [String: [StringScaleMapper<UInt32>]] = [:]
        var results: [PayoutInfo] = []
        for page in pages {
            try Task.checkCancellation()
            guard Date() < deadline else { throw AssetHubPagedStorage.Failure.limitExceeded }
            let key = "\(page.era):\(page.validator.toHex())"
            let claimed: [StringScaleMapper<UInt32>]
            if let cached = claimCache[key] { claimed = cached }
            else { claimed = try await queries.validator(.claimedRewards, era: page.era, account: page.validator) }
            claimCache[key] = claimed
            if claimed.contains(where: { $0.value == page.index }) { continue }
            let era: AssetHubPayoutEra
            if let cached = eraCache[page.era] { era = cached }
            else { era = try await eraEvidence(era: page.era, queries: queries) }
            eraCache[page.era] = era
            let validator: AssetHubPayoutValidator
            if let cached = validatorCache[key] { validator = cached }
            else { validator = try await validatorEvidence(page: page, queries: queries, era: era, claimed: claimed) }
            validatorCache[key] = validator
            if let payout = try calculate(page: page, era: era, validator: validator) { results.append(payout) }
        }
        return PayoutsInfo(activeEra: active.index, historyDepth: depth, payouts: results.sorted {
            if $0.era != $1.era { return $0.era > $1.era }
            if $0.validator != $1.validator { return $0.validator.lexicographicallyPrecedes($1.validator) }
            return ($0.page ?? 0) < ($1.page ?? 0)
        })
    }

    /// Exposure pages name a nominator only inside their values, so reading every page of the history window would
    /// download all validators' exposures (about 0.9 MB per era on Polkadot Asset Hub, 84 eras). Only the validators
    /// this account nominates now, and its own exposure as a validator, are read. A reward from a validator it stopped
    /// nominating inside the window is not listed; it stays claimable by anyone until the window passes.
    private func discoverPages(queries: AssetHubStakingQueries, eras: Set<EraIndex>) async throws -> [AssetHubPayoutPage] {
        let scanner = queries.scanner
        let nominations: [StorageResponse<Nomination>] = try await storage.queryItems(
            engine: engine, keyParams: [account], factory: scanner.runtime, storagePath: .nominators, at: scanner.block
        )
        let targets = nominations.first?.value?.targets ?? []
        guard targets.count <= Self.maximumNominations else { throw AssetHubPagedStorage.Failure.limitExceeded }
        let validators = Array(Set(targets + [account])).sorted { $0.lexicographicallyPrecedes($1) }
        let pairs = eras.sorted().flatMap { era in validators.map { (era: era, validator: $0) } }

        let overviews: [StorageResponse<ValidatorExposureMetadata>] = try await chunked(pairs) { chunk in
            try await storage.queryItems(
                engine: engine,
                keyParams: chunk.map { pair -> [[NMapKeyParamProtocol]] in
                    [[NMapKeyParam(value: StringScaleMapper(value: pair.era))], [NMapKeyParam(value: pair.validator)]]
                },
                factory: scanner.runtime, storagePath: .erasStakersOverview, at: scanner.block
            )
        }

        var pages: [AssetHubPayoutPage] = []
        var pageKeys: [(era: EraIndex, validator: AccountId, page: UInt32)] = []
        for (pair, response) in zip(pairs, overviews) {
            guard let overview = response.value else { continue }
            guard overview.pageCount > 0 else {
                // A validator backed only by its own stake is paid through virtual page zero.
                if pair.validator == account, overview.own > 0 {
                    pages.append(AssetHubPayoutPage(
                        era: pair.era, validator: account, index: 0, exposure: ValidatorExposurePage(others: [], pageTotal: 0)
                    ))
                }
                continue
            }
            guard pageKeys.count + Int(overview.pageCount) <= Self.maximumPages else {
                throw AssetHubPagedStorage.Failure.limitExceeded
            }
            pageKeys += (0 ..< overview.pageCount).map { (era: pair.era, validator: pair.validator, page: $0) }
        }

        let exposures: [StorageResponse<ValidatorExposurePage>] = try await chunked(pageKeys) { chunk in
            try await storage.queryItems(
                engine: engine,
                keyParams: chunk.map { key -> [[NMapKeyParamProtocol]] in
                    [[NMapKeyParam(value: StringScaleMapper(value: key.era))], [NMapKeyParam(value: key.validator)],
                     [NMapKeyParam(value: StringScaleMapper(value: key.page))]]
                },
                factory: scanner.runtime, storagePath: .erasStakersPaged, at: scanner.block
            )
        }
        for (key, response) in zip(pageKeys, exposures) {
            // The overview counts this page, so a missing value is a broken answer, not an empty page.
            guard let exposure = response.value else { throw AssetHubPagedStorage.Failure.invalidPage }
            if key.validator == account || exposure.others.contains(where: { $0.who == account }) {
                pages.append(AssetHubPayoutPage(era: key.era, validator: key.validator, index: key.page, exposure: exposure))
            }
        }
        return pages
    }

    private static let maximumNominations = 64
    private static let maximumPages = 10000

    /// Reads storage for `items` in requests of at most `AssetHubPagedStorage.pageSize` keys, one response per item.
    private func chunked<Item, Value>(
        _ items: [Item],
        read: ([Item]) async throws -> [StorageResponse<Value>]
    ) async throws -> [StorageResponse<Value>] {
        var result: [StorageResponse<Value>] = []
        var start = 0
        while start < items.count {
            try Task.checkCancellation()
            let end = min(start + AssetHubPagedStorage.pageSize, items.count)
            let values = try await read(Array(items[start ..< end]))
            guard values.count == end - start else { throw AssetHubPagedStorage.Failure.invalidPage }
            result += values
            start = end
        }
        return result
    }

    private func eraEvidence(era: EraIndex, queries: AssetHubStakingQueries) async throws -> AssetHubPayoutEra {
        let reward: StringScaleMapper<BigUInt> = try await queries.era(.totalValidatorReward, era: era)
        let points: EraRewardPoints = try await queries.era(.rewardPointsPerValidator, era: era)
        guard Set(points.individual.map(\.accountId)).count == points.individual.count,
              points.individual.reduce(UInt64(0), { $0 + UInt64($1.rewardPoint) }) == UInt64(points.total) else {
            throw EraValidatorServiceError.unexpectedInfo
        }
        return AssetHubPayoutEra(reward: reward.value, points: points)
    }

    private func validatorEvidence(page: AssetHubPayoutPage, queries: AssetHubStakingQueries, era: AssetHubPayoutEra, claimed: [StringScaleMapper<UInt32>]) async throws -> AssetHubPayoutValidator {
        let overview: ValidatorExposureMetadata = try await queries.validator(.erasStakersOverview, era: page.era, account: page.validator)
        let prefs: ValidatorPrefs = try await queries.validator(.erasPrefs, era: page.era, account: page.validator)
        let points = era.points.individual.first(where: { $0.accountId == page.validator })?.rewardPoint ?? 0
        let incentive = page.validator == account ? try await queries.validatorIncentive(era: page.era, account: page.validator, points: points) : .zero
        return AssetHubPayoutValidator(claimed: claimed, overview: overview, prefs: prefs, incentive: incentive)
    }

    private func calculate(page: AssetHubPayoutPage, era: AssetHubPayoutEra, validator: AssetHubPayoutValidator) throws -> PayoutInfo? {
        guard !validator.claimed.contains(where: { $0.value == page.index }) else { return nil }
        let individual = era.points.individual.first(where: { $0.accountId == page.validator })?.rewardPoint ?? 0
        let amount = try AssetHubRewardMath.payout(
            allocation: .init(reward: era.reward, points: individual, totalPoints: era.points.total, commission: validator.prefs.commission, incentive: validator.incentive),
            exposure: .init(overview: validator.overview, page: page.exposure, pageIndex: page.index),
            account: account, validator: page.validator
        )
        guard amount > 0 else { return nil }
        guard let asset = chain.assets.first(where: { $0.id == AssetHubStakingRoute.staking(on: chain.chainId)?.nativeAssetId }),
              let decimal = Decimal.fromSubstrateAmount(amount, precision: Int16(asset.precision)) else {
            throw EraValidatorServiceError.unexpectedInfo
        }
        return PayoutInfo(era: page.era, validator: page.validator, reward: decimal, identity: nil, page: page.index)
    }
}
