import Foundation
import TonAPI
import BigInt
import SSFModels
import TonSwift

enum TonRemoteBalanceFetchingError: Error {
    case missingAccount
    case balanceError
    case jettonNotFound
    case utilityNotFound
}

actor TonRemoteBalanceFetchingImpl: AccountInfoRemoteService {
    private let chainRegistry: ChainRegistryProtocol
    private let repositoryWrapper: BalanceRepositoryCacheWrapper
    private let jettonInjector: TonJettonInjector

    init(
        chainRegistry: ChainRegistryProtocol,
        repositoryWrapper: BalanceRepositoryCacheWrapper,
        jettonInjector: TonJettonInjector
    ) {
        self.chainRegistry = chainRegistry
        self.repositoryWrapper = repositoryWrapper
        self.jettonInjector = jettonInjector
    }

    // MARK: - AccountInfoRemoteService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            throw TonRemoteBalanceFetchingError.missingAccount
        }
        let address = try accountId.asTonAddress().toRaw()

        let chainAssets = chain.chainAssets.divide { chainAsset in
            chainAsset.chainAssetType.tonAssetType == .normal
        }

        guard let normal = chainAssets.slice.first else {
            throw TonRemoteBalanceFetchingError.utilityNotFound
        }
        let jettons = chainAssets.remainder

        let chainAccountInfos = try await getChainAccountInfos(
            address: address,
            currency: wallet.selectedCurrency
        )
        let normalBalance = chainAccountInfos.normal
        let jettonBalances = chainAccountInfos.jettons

        let jettonsAccountInfos = createJettonsAccountInfos(
            jettonBalances: jettonBalances,
            jettons: jettons
        )
        let jettonsAccountInfoMap = Dictionary(
            uniqueKeysWithValues: jettonsAccountInfos.map { ($0.0.chainAssetId, $0.1) }
        )

        let cacheValue = [(normal, normalBalance)] + jettonsAccountInfos
        try? cache(
            cacheValue,
            accountId: accountId
        )

        let normalMap: [ChainAssetId: AccountInfo?] = [normal.chainAssetId: normalBalance]
        let union = normalMap.merging(jettonsAccountInfoMap, uniquingKeysWith: { current, _ in current })
        return union
    }

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw TonRemoteBalanceFetchingError.missingAccount
        }
        let address = try accountId.asTonAddress().toRaw()

        let accountInfo: AccountInfo
        switch chainAsset.chainAssetType.tonAssetType {
        case .normal:
            accountInfo = try await getAccountInfo(address: address)
        case .jetton:
            let jettons = try await getAccountJettonsBalances(
                address: address,
                currency: wallet.selectedCurrency
            )
            guard let jetton = jettons.first(where: { jetton in
                jetton.item.walletAddress.toRaw() == chainAsset.asset.id
            }) else {
                return nil
            }
            return AccountInfo(balance: jetton.quantity)
        case .none:
            return nil
        }

        let cacheValue = [(chainAsset, accountInfo)]
        try? cache(
            cacheValue,
            accountId: accountId
        )
        return accountInfo
    }

    func fetchAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let chainAssets = chainAssets.divide { chainAsset in
            chainAsset.chainAssetType.tonAssetType == .normal
        }

        guard let normal = chainAssets.slice.first else {
            throw TonRemoteBalanceFetchingError.utilityNotFound
        }
        let jettons = chainAssets.remainder

        guard let accountId = wallet.fetch(for: normal.chain.accountRequest())?.accountId else {
            throw TonRemoteBalanceFetchingError.missingAccount
        }

        let address = try accountId.asTonAddress().toRaw()
        let chainAccountInfos = try await getChainAccountInfos(
            address: address,
            currency: wallet.selectedCurrency
        )
        let normalBalance = chainAccountInfos.normal
        let jettonBalances = chainAccountInfos.jettons

        let jettonsAccountInfos = createJettonsAccountInfos(
            jettonBalances: jettonBalances,
            jettons: jettons
        )
        let jettonsAccountInfoMap = Dictionary(
            uniqueKeysWithValues: jettonsAccountInfos.map { ($0.0.uniqueKey(accountId: accountId), $0.1) }
        )

        let cacheValue = [(normal, normalBalance)] + jettonsAccountInfos
        try? cache(
            cacheValue,
            accountId: accountId
        )

        let normalKey = normal.uniqueKey(accountId: accountId)
        let normalMap: [ChainAssetKey: AccountInfo?] = [normalKey: normalBalance]
        let union = normalMap.merging(jettonsAccountInfoMap, uniquingKeysWith: { current, _ in current })
        return union
    }

    // MARK: - Private methods

    private func createJettonsAccountInfos(
        jettonBalances: [TonJettonBalance],
        jettons: [ChainAsset]
    ) -> [(ChainAsset, AccountInfo)] {
        let jettonsAccountInfo: [(ChainAsset, AccountInfo)] = jettonBalances.compactMap { jetton in
            let chainAsset = jettons.first(where: { $0.asset.id == jetton.item.walletAddress.toRaw() })
            guard let chainAsset else { return nil }
            return (chainAsset, AccountInfo(balance: jetton.quantity))
        }
        return jettonsAccountInfo
    }

    private func getChainAccountInfos(
        address: String,
        currency: Currency
    ) async throws -> (normal: AccountInfo, jettons: [TonJettonBalance]) {
        async let normalBalanceTask = getAccountInfo(address: address)
        async let jettonBalancesTask = getAccountJettonsBalances(address: address, currency: currency)
        let normalBalance = try await normalBalanceTask
        let jettonBalances = try await jettonBalancesTask
        return (normalBalance, jettonBalances)
    }

    private func getAccountInfo(
        address: String
    ) async throws -> AccountInfo {
        let assembly = try chainRegistry.getTonApiAssembly()
        let tonAPIClient = assembly.tonAPIClient()

        let response = try await tonAPIClient.getAccount(.init(path: .init(account_id: address)))
        let account = try TonAccount(account: try response.ok.body.json)
        let stringBalance = String(account.balance)
        guard let balance = BigUInt(string: stringBalance) else {
            throw TonRemoteBalanceFetchingError.balanceError
        }

        let accountInfo = AccountInfo(balance: balance)
        return accountInfo
    }

    private func getAccountJettonsBalances(
        address: String,
        currency: Currency
    ) async throws -> [TonJettonBalance] {
        let assembly = try chainRegistry.getTonApiAssembly()
        let tonAPIClient = assembly.tonAPIClient()

        let response = try await tonAPIClient.getAccountJettonsBalances(
            path: .init(account_id: address),
            query: .init(currencies: currency.id.uppercased())
        )

        let jettons = try response.ok.body.json.balances.compactMap { jetton in
            do {
                let quantity = BigUInt(stringLiteral: jetton.balance)
                let walletAddress = try TonSwift.Address.parse(jetton.wallet_address.address)
                let jettonInfo = try TonJettonInfo(jettonPreview: jetton.jetton)
                let jettonItem = TonJettonItem(jettonInfo: jettonInfo, walletAddress: walletAddress)
                let rates = mapJettonRates(rates: jetton.price, currency: currency)
                let jettonBalance = TonJettonBalance(
                    item: jettonItem,
                    quantity: quantity,
                    priceData: rates
                )
                return jettonBalance
            } catch {
                return nil
            }
        }
        Task {
            await jettonInjector.inject(jettonItems: jettons)
        }
        return jettons
    }
    
    private func mapJettonRates(
        rates: Components.Schemas.TokenRates?,
        currency: Currency
    ) -> [PriceData] {
        guard 
            let price = rates?.prices?.additionalProperties.first?.value,
            let fiatDayChange = rates?.diff_24h?.additionalProperties.first?.value
        else {
            return []
        }
        let priceData = PriceData(
            currencyId: currency.id,
            priceId: "",
            price: String(price),
            fiatDayChange: .zero,
            coingeckoPriceId: nil
        )
        return [priceData]
    }

    nonisolated private func cache(
        _ cache: [(ChainAsset, AccountInfo)],
        accountId: AccountId?
    ) throws {
        guard let accountId else {
            return
        }

        let transform = try cache.map {
            let storagePath = $0.0.storagePath

            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                chainAssetKey: $0.0.uniqueKey(accountId: accountId)
            )
            return (localKey, $0.1)
        }
        let map = Dictionary(uniqueKeysWithValues: transform)
        try repositoryWrapper.save(map: map)
    }
}
