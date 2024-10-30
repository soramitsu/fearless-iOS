import Foundation
import RobinHood
import SSFModels

protocol TonJettonInjector {
    func inject(jettonItems: [TonJettonBalance]) async
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
            let network = LocalToggleService.shared.tonEnvListToggle.storageValue ? "-3" : "-239"
            guard let tonChain = try await chainModelRepository.fetch(by: network, options: RepositoryFetchOptions()) else {
                throw ConvenienceError(error: "Ton chain is not fetched")
            }
            var assetModels = map(jettonItems: jettonItems)
            if let tonAsset = tonChain.utilityAssets().first {
                assetModels.insert(tonAsset)
            }
            let updatedChainModel = tonChain.replacingAssets(Array(assetModels))
            await chainModelRepository.save(models: [updatedChainModel])
            let priceUpdatedEvent = PricesUpdated()
            eventCenter.notify(with: priceUpdatedEvent)

            logger.info("The Open Network has been updated with new assets: \(assetModels.map { $0.name })")
        } catch {
            logger.customError(error)
        }
    }

    private func map(jettonItems: [TonJettonBalance]) -> Set<AssetModel> {
        let mapped = jettonItems.map { balanceInfo in
            AssetModel(
                id: balanceInfo.item.walletAddress.toRaw(),
                name: balanceInfo.item.jettonInfo.name,
                symbol: balanceInfo.item.jettonInfo.symbol ?? balanceInfo.item.jettonInfo.name,
                precision: UInt16(balanceInfo.item.jettonInfo.fractionDigits),
                icon: balanceInfo.item.jettonInfo.imageURL,
                currencyId: balanceInfo.item.jettonInfo.address.toRaw(),
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                assetType: .ton(tonType: .jetton),
                priceProvider: nil,
                coingeckoPriceId: nil,
                priceData: balanceInfo.priceData
            )
        }

        return Set(mapped)
    }
}
