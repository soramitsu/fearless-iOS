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
    private let tonChainSelectionToggleSource: TonChainSelection.ToggleSource

    init(
        chainModelRepository: AsyncAnyRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        tonChainSelectionToggleSource: TonChainSelection.ToggleSource = LocalToggleService.shared
    ) {
        self.chainModelRepository = chainModelRepository
        self.eventCenter = eventCenter
        self.logger = logger
        self.tonChainSelectionToggleSource = tonChainSelectionToggleSource
    }

    func inject(jettonItems: [TonJettonBalance]) async {
        do {
            let tonChain = try await fetchTonChain()

            var assetModels = map(jettonItems: jettonItems)
            if let tonAsset = tonChain.utilityAssets().first {
                assetModels.insert(tonAsset)
            }

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
            guard let tonPrice = tonPriceData.first else {
                return
            }

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

    private func map(jettonItems: [TonJettonBalance]) -> Set<AssetModel> {
        let mapped = jettonItems.map { balanceInfo in
            AssetModel(
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
        }

        return Set(mapped)
    }

    private func fetchTonChain() async throws -> ChainModel {
        let chainId = tonChainId()

        guard let tonChain = try await chainModelRepository.fetch(by: chainId, options: RepositoryFetchOptions()) else {
            throw ConvenienceError(error: "Ton chain is not fetched for chainId: \(chainId)")
        }

        return tonChain
    }

    private func tonChainId() -> ChainModel.Id {
        TonChainSelection.selectedChainId(toggleSource: tonChainSelectionToggleSource)
    }
}
