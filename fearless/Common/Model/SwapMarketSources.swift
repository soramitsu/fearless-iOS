import Foundation

protocol SwapMarketSourcerProtocol {
    init?(fromAssetId: String?, toAssetId: String?, forceSmartIds: [String])
    func getMarketSources() -> [LiquiditySourceType]
    func getMarketSource(at index: Int) -> LiquiditySourceType?
    func isEmpty() -> Bool
    func isLoaded() -> Bool
    func didLoad(_ serverMarketSources: [LiquiditySourceType])
    func getServerMarketSources() -> [String]
    func index(of marketSource: LiquiditySourceType) -> Int?
    func contains(_ marketSource: LiquiditySourceType) -> Bool
}

final class SwapMarketSourcer: SwapMarketSourcerProtocol {
    private var marketSources: [LiquiditySourceType]?
    private var fromAssetId: String
    private var toAssetId: String
    private let forceSmartIds: [String]

    required init?(fromAssetId: String?, toAssetId: String?, forceSmartIds: [String]) {
        guard let fromAssetId = fromAssetId,
              let toAssetId = toAssetId
        else {
            return nil
        }
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
        self.forceSmartIds = forceSmartIds
    }

    func getMarketSources() -> [LiquiditySourceType] {
        marketSources ?? []
    }

    func getMarketSource(at index: Int) -> LiquiditySourceType? {
        guard let marketSources = marketSources, index < marketSources.count else {
            return nil
        }
        return marketSources[index]
    }

    func isEmpty() -> Bool {
        marketSources?.isEmpty ?? true
    }

    func isLoaded() -> Bool {
        marketSources != nil
    }

    func didLoad(_ serverMarketSources: [LiquiditySourceType]) {
        setMarketSources(from: serverMarketSources)
        forceAddSmartMarketSourceIfNecessary()
        addSmartIfNotEmpty()
    }

    func setMarketSources(_ marketSources: [LiquiditySourceType]) {
        self.marketSources = marketSources
    }

    func setMarketSources(from serverMarketSources: [LiquiditySourceType]) {
        marketSources = serverMarketSources
    }

    func forceAddSmartMarketSourceIfNecessary() {
        if isEmpty(), shouldForceAddSmartMarketSource() {
            add(.smart)
        }
    }

    func shouldForceAddSmartMarketSource() -> Bool {
        isXSTUSD(fromAssetId) && shouldForceSmartMarketSource(for: toAssetId) ||
            isXSTUSD(toAssetId) && shouldForceSmartMarketSource(for: fromAssetId)
    }

    func isXSTUSD(_ assetId: String) -> Bool {
        assetId == PolkaswapConstnts.xstusd
    }

    func shouldForceSmartMarketSource(for assetId: String) -> Bool {
        forceSmartIds.contains(assetId)
    }

    func add(_ marketSource: LiquiditySourceType) {
        DispatchQueue.global().sync {
            marketSources?.append(marketSource)
        }
    }

    func addSmartIfNotEmpty() {
        guard let marketSources = marketSources else { return }

        let notEmpty = !marketSources.isEmpty
        let hasNoSmart = !marketSources.contains(LiquiditySourceType.smart)
        if notEmpty, hasNoSmart {
            add(.smart)
        }
    }

    func getServerMarketSources() -> [String] {
        let filteredMarketSources = marketSources?.filter { shouldSendToServer($0) } ?? []
        return filteredMarketSources.map { $0.rawValue }
    }

    func shouldSendToServer(_ markerSource: LiquiditySourceType) -> Bool {
        markerSource != LiquiditySourceType.smart
    }

    func index(of marketSource: LiquiditySourceType) -> Int? {
        marketSources?.firstIndex(where: { $0 == marketSource })
    }

    func contains(_ marketSource: LiquiditySourceType) -> Bool {
        index(of: marketSource) != nil
    }
}
