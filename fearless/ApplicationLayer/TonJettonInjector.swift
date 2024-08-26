import Foundation
import RobinHood
import SSFModels

protocol TonJettonInjector {
    func inject(jettonItems: [TonJettonItem]) async
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

    func inject(jettonItems: [TonJettonItem]) async {
        do {
            guard let tonChain = try await chainModelRepository.fetch(by: "-239", options: RepositoryFetchOptions()) else {
                throw ConvenienceError(error: "Ton chain is not fetched")
            }
            let assetModels = map(jettonItems: jettonItems)
            let unionAssets = tonChain.assets.union(assetModels)

            guard tonChain.assets.symmetricDifference(unionAssets).isNotEmpty else {
                return
            }
            let updatedChainModel = tonChain.replacingAssets(Array(unionAssets))
            await chainModelRepository.save(models: [updatedChainModel])

            logger.info("The Open Network has been updated with new assets: \(assetModels.map { $0.name })")
        } catch {
            logger.customError(error)
        }
    }

    private func map(jettonItems: [TonJettonItem]) -> Set<AssetModel> {
        let mapped = jettonItems.map { item in
            AssetModel(
                id: item.walletAddress.toRaw(),
                name: item.jettonInfo.name,
                symbol: item.jettonInfo.symbol ?? item.jettonInfo.name,
                precision: UInt16(item.jettonInfo.fractionDigits),
                icon: item.jettonInfo.imageURL,
                currencyId: item.jettonInfo.address.toRaw(), // wallet
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                assetType: .ton(tonType: .jetton),
                priceProvider: nil,
                coingeckoPriceId: nil
            )
        }

        return Set(mapped)
    }
}
