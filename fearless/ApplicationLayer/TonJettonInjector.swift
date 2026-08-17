import Foundation
import RobinHood
import SSFModels

protocol TonJettonInjector {
    func inject(jettonItems: [TonJettonBalance]) async
    func inject(tonPriceData: [PriceData]) async
}

actor TonJettonInjectorImpl: TonJettonInjector {
    private let chainModelRepository: AsyncAnyRepository<ChainModel>
    private let logger: LoggerProtocol
    private let eventCenter: EventCenterProtocol

    init(
        chainModelRepository: AsyncAnyRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainModelRepository = chainModelRepository
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func inject(jettonItems: [TonJettonBalance]) async {
        do {
            let tonChain = try await fetchTonChain()
            let heldAssets = map(jettonItems: jettonItems)
            var mergedById = Dictionary(uniqueKeysWithValues: tonChain.assets.map { ($0.id, $0) })

            let exactPrices = zip(jettonItems, heldAssets).flatMap { item, heldAsset in
                item.priceData.compactMap {
                    exactPrice($0, for: heldAsset.asset)
                }
            }
            ExactAssetPriceCache.shared.upsert(exactPrices)

            heldAssets.forEach { heldAsset in
                let existingAsset = mergedById[heldAsset.asset.id]
                let existingTrust = existingAsset.map {
                    AssetTrustResolver.metadataTrust(
                        for: ChainAsset(chain: tonChain, asset: $0)
                    )
                }

                // Signed/curated registry metadata wins. Previously discovered
                // entries may refresh from TonAPI, but unrelated catalog assets
                // and defaults are never removed by a scan.
                if existingTrust?.provenance != .registry {
                    mergedById[heldAsset.asset.id] = heldAsset.asset
                    TonJettonMetadataTrust.apply(
                        to: ChainAsset(chain: tonChain, asset: heldAsset.asset),
                        verification: heldAsset.verification
                    )
                }
            }

            let assetModels = Set(mergedById.values)

            let updatedChainModel = tonChain
            updatedChainModel.assets = assetModels
            await chainModelRepository.save(models: [updatedChainModel])
            eventCenter.notify(with: PricesUpdated())

            logger.info("The Open Network has been updated with new assets: \(assetModels.map { $0.name })")
        } catch {
            logger.customError(error)
        }
    }

    func inject(tonPriceData: [PriceData]) async {
        do {
            let tonChain = try await fetchTonChain()
            guard let tonAsset = tonChain.utilityChainAssets().first else {
                return
            }
            let exactPrices = tonPriceData.compactMap {
                exactPrice($0, for: tonAsset.asset)
            }
            guard let tonPrice = exactPrices.first else {
                return
            }

            ExactAssetPriceCache.shared.upsert(exactPrices)

            let updatedTonAsset = tonAsset.asset.replacingPrice(tonPrice)
            var jettons = Array(tonChain.assets.filter { !$0.isUtility })
            jettons.append(updatedTonAsset)
            let updatedChain = tonChain
            updatedChain.assets = Set(jettons)
            await chainModelRepository.save(models: [updatedChain])
            eventCenter.notify(with: PricesUpdated())
        } catch {
            logger.customError(error)
        }
    }

    private func map(
        jettonItems: [TonJettonBalance]
    ) -> [(asset: AssetModel, verification: String?)] {
        jettonItems.map { balanceInfo in
            let asset = AssetModel(
                id: balanceInfo.item.jettonInfo.address.toRaw(),
                name: balanceInfo.item.jettonInfo.name,
                symbol: balanceInfo.item.jettonInfo.symbol ?? balanceInfo.item.jettonInfo.name,
                precision: UInt16(balanceInfo.item.jettonInfo.fractionDigits),
                icon: balanceInfo.item.jettonInfo.imageURL,
                price: Decimal(string: balanceInfo.priceData.first?.price ?? ""),
                fiatDayChange: balanceInfo.priceData.first?.fiatDayChange,
                currencyId: balanceInfo.item.jettonInfo.address.toRaw(),
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                type: .xcm,
                ethereumType: nil,
                priceProvider: nil,
                coingeckoPriceId: balanceInfo.priceData.first?.coingeckoPriceId
            )
            return (asset, balanceInfo.item.jettonInfo.verification)
        }
    }

    /// TonAPI returns an explicit fiat/currency value but no provider ID. Bind
    /// it only to the curated asset's declared price ID; never infer from symbol.
    private func exactPrice(_ price: PriceData, for asset: AssetModel) -> PriceData? {
        guard let assetPriceId = asset.priceId,
              !assetPriceId.isEmpty,
              price.priceId.isEmpty || price.priceId == assetPriceId else {
            return nil
        }

        return PriceData(
            currencyId: price.currencyId,
            priceId: assetPriceId,
            price: price.price,
            fiatDayChange: price.fiatDayChange,
            coingeckoPriceId: price.coingeckoPriceId ?? asset.coingeckoPriceId
        )
    }

    private func fetchTonChain() async throws -> ChainModel {
        let chainId = tonChainId()

        guard let tonChain = try await chainModelRepository.fetch(by: chainId, options: RepositoryFetchOptions()) else {
            throw ConvenienceError(error: "Ton chain is not fetched for chainId: \(chainId)")
        }

        return tonChain
    }

    private func tonChainId() -> ChainModel.Id {
        TonChainSelection.selectedChainId()
    }
}

protocol DynamicAssetCatalogInjecting {
    func inject(assetModels: [AssetModel], into chain: ChainModel) async
}

/// Merges held, non-registry assets into the local chain catalog without
/// replacing curated metadata. The trust tombstone keeps their indexer/chain
/// metadata and prices outside verified portfolio totals.
actor DynamicAssetCatalogInjectorImpl: DynamicAssetCatalogInjecting {
    private let chainModelRepository: AsyncAnyRepository<ChainModel>
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol

    init(
        chainModelRepository: AsyncAnyRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainModelRepository = chainModelRepository
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func inject(assetModels: [AssetModel], into chain: ChainModel) async {
        guard assetModels.isNotEmpty else {
            return
        }

        do {
            let persistedChain = try await chainModelRepository.fetch(
                by: chain.chainId,
                options: RepositoryFetchOptions()
            ) ?? chain
            var mergedAssets = persistedChain.assets
            let curatedIds = Set(mergedAssets.map(\.id))
            let discoveredAssets = assetModels.filter { !curatedIds.contains($0.id) }

            guard discoveredAssets.isNotEmpty else {
                return
            }

            discoveredAssets.forEach { asset in
                mergedAssets.insert(asset)
                let chainAsset = ChainAsset(chain: persistedChain, asset: asset)
                let trust = AssetTrustResolver.metadataTrust(for: chainAsset)

                // Iroha discovery marks held definitions with unknown scale as
                // `.missing` before this catalog merge. Do not downgrade that
                // stronger, honest state to `.unverified` (which also clears
                // the missing tombstone). Likewise retain an explicit indexer
                // verification. A new asset with the resolver's default
                // registry fallback is not actually registry-curated here, so
                // it must still become unverified.
                let hasExplicitTrust = trust.trust == .missing ||
                    (trust.trust == .verified && trust.provenance == .indexer)
                if !hasExplicitTrust {
                    AssetTrustResolver.markUnverified(chainAsset)
                }
            }

            // Keep the caller's in-flight chain snapshot coherent with the
            // returned dynamic account-info keys. Visibility discovery can
            // therefore apply preferences immediately, before Core Data emits
            // its asynchronous registry refresh.
            var inFlightAssets = chain.assets
            discoveredAssets.forEach { inFlightAssets.insert($0) }
            chain.assets = inFlightAssets

            persistedChain.assets = mergedAssets
            await chainModelRepository.save(models: [persistedChain])
            eventCenter.notify(with: PricesUpdated())
        } catch {
            logger.customError(error)
        }
    }
}
