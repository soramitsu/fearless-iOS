import Foundation

protocol SwapMarketSourceProtocol {
    init?(fromAssetId: String?, toAssetId: String?, remoteSettings: PolkaswapRemoteSettings)
    func getMarketSources() -> [LiquiditySourceType]
    func getMarketSource(at index: Int) -> LiquiditySourceType?
    func isEmpty() -> Bool
    func isLoaded() -> Bool
    func didLoad(_ serverMarketSources: [LiquiditySourceType])
    func getRemoteMarketSources() -> [String]
    func index(of marketSource: LiquiditySourceType) -> Int?
    func contains(_ marketSource: LiquiditySourceType) -> Bool
}

final class SwapMarketSource: SwapMarketSourceProtocol {
    private var marketSources: [LiquiditySourceType]?
    private var fromAssetId: String
    private var toAssetId: String
    private let remoteSettings: PolkaswapRemoteSettings

    required init?(fromAssetId: String?, toAssetId: String?, remoteSettings: PolkaswapRemoteSettings) {
        guard let fromAssetId = fromAssetId,
              let toAssetId = toAssetId
        else {
            return nil
        }
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
        self.remoteSettings = remoteSettings
    }

    func getMarketSources() -> [LiquiditySourceType] {
        marketSources ?? [.smart]
    }

    func getMarketSource(at index: Int) -> LiquiditySourceType? {
        marketSources?[safe: index]
    }

    func isEmpty() -> Bool {
        marketSources.or([]).isEmpty
    }

    func isLoaded() -> Bool {
        marketSources != nil
    }

    func didLoad(_ serverMarketSources: [LiquiditySourceType]) {
        setMarketSources(from: serverMarketSources)
        forceAddSmartMarketSourceIfNecessary()
        addSmartIfNotEmpty()
    }

    func getRemoteMarketSources() -> [String] {
        let filteredMarketSources = marketSources?.filter { shouldSendToServer($0) } ?? []
        return filteredMarketSources.map { $0.rawValue }
    }

    func index(of marketSource: LiquiditySourceType) -> Int? {
        marketSources?.firstIndex(where: { $0 == marketSource })
    }

    func contains(_ marketSource: LiquiditySourceType) -> Bool {
        index(of: marketSource) != nil
    }

    // MARK: - Private methods

    private func setMarketSources(_ marketSources: [LiquiditySourceType]) {
        self.marketSources = marketSources
    }

    private func setMarketSources(from remoteMarketSources: [LiquiditySourceType]) {
        marketSources = remoteMarketSources
    }

    private func forceAddSmartMarketSourceIfNecessary() {
        if isEmpty() || shouldForceAddSmartMarketSource() {
            add(.smart)
        }
    }

    private func shouldForceAddSmartMarketSource() -> Bool {
        isXSTUSD(fromAssetId) && shouldForceSmartMarketSource(for: toAssetId) ||
            isXSTUSD(toAssetId) && shouldForceSmartMarketSource(for: fromAssetId)
    }

    private func isXSTUSD(_ assetId: String) -> Bool {
        assetId == remoteSettings.xstusdId
    }

    private func shouldForceSmartMarketSource(for assetId: String) -> Bool {
        remoteSettings.forceSmartIds.contains(assetId)
    }

    private func add(_ marketSource: LiquiditySourceType) {
        DispatchQueue.global().sync {
            marketSources?.append(marketSource)
        }
    }

    private func addSmartIfNotEmpty() {
        guard let marketSources = marketSources else { return }

        let notEmpty = !marketSources.isEmpty
        let hasNoSmart = !marketSources.contains(LiquiditySourceType.smart)
        if notEmpty, hasNoSmart {
            add(.smart)
        }
    }

    private func shouldSendToServer(_ markerSource: LiquiditySourceType) -> Bool {
        markerSource != LiquiditySourceType.smart
    }
}
