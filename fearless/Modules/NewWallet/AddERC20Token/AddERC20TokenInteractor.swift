import Foundation
import Web3
import SSFModels
import RobinHood
import Web3ContractABI
import PromiseKit
import SSFNetwork

final class AddERC20TokenInteractor {
    // MARK: - Private properties

    private weak var output: AddERC20TokenInteractorOutput?
    private let storage: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let ethereumNodeFetching: EthereumNodeFetching
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private var web3: Web3.Eth?

    // MARK: - Constructors

    init(
        storage: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        ethereumNodeFetching: EthereumNodeFetching,
        chainAssetFetching: ChainAssetFetchingProtocol
    ) {
        self.storage = storage
        self.operationManager = operationManager
        self.ethereumNodeFetching = ethereumNodeFetching
        self.chainAssetFetching = chainAssetFetching
    }

    private func getTokenIconURL(address: String) -> URL? {
        let baseURL = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets"
        return URL(string: "\(baseURL)/\(address)/logo.png")
    }
}

// MARK: - AddERC20TokenInteractorInput

extension AddERC20TokenInteractor: AddERC20TokenInteractorInput {
    func setup(with output: AddERC20TokenInteractorOutput) {
        self.output = output
    }

    func validateAndFetchToken(address: String, chain: ChainModel) async throws {
        let chainAssets = try await chainAssetFetching.fetchAwait(
            shouldUseCache: true,
            filters: [.chainId(chain.chainId)],
            sortDescriptors: []
        )
        
        if chainAssets.contains(where: { $0.asset.id.lowercased() == address.lowercased() }) {
            throw AddERC20TokenError.tokenAlreadyExists
        }
        
        firstly {
            let web3 = try ethereumNodeFetching.getNode(for: chain)
            let contractAddress = try EthereumAddress(rawAddress: address.hexToBytes())
            let contract = web3.Contract(type: GenericERC20Contract.self, address: contractAddress)
            return Promise.value(contract)
        }.then { contract -> Promise<(String, String, UInt8, BigUInt)> in
            let namePromise = contract.name().call()
            let symbolPromise = contract.symbol().call()
            let decimalsPromise = contract.decimals().call()
            let totalSupplyPromise = contract.totalSupply().call()
            
            return when(fulfilled: [
                namePromise,
                symbolPromise,
                decimalsPromise,
                totalSupplyPromise
            ]).map { results in
                guard let name = results[0]["_name"] as? String,
                      let symbol = results[1]["_symbol"] as? String,
                      let decimals = results[2]["_decimals"] as? UInt8,
                      let totalSupply = results[3]["_totalSupply"] as? BigUInt else {
                    throw AddERC20TokenError.invalidTokenData
                }
                
                return (name, symbol, decimals, totalSupply)
            }
        }.done { name, symbol, decimals, totalSupply in
            let tokenInfo = ERC20TokenInfo(
                address: address,
                name: name,
                symbol: symbol,
                decimals: decimals,
                totalSupply: totalSupply,
                iconURL: self.getTokenIconURL(address: address)
            )
            
            self.output?.didReceive(tokenInfo: tokenInfo)
        }.catch { error in
            self.output?.didReceive(error: error)
        }
    }

    func saveToken(_ token: ERC20TokenInfo, for chain: ChainModel) {
        Task {
            do {
                let asset = AssetModel(
                    id: token.address,
                    name: token.name,
                    symbol: token.symbol,
                    precision: UInt16(token.decimals),
                    icon: token.iconURL,
                    currencyId: token.address,
                    existentialDeposit: nil,
                    color: nil,
                    isUtility: false,
                    isNative: false,
                    staking: nil,
                    purchaseProviders: nil,
                    assetType: .ethereum(ethereumType: .erc20),
                    priceProvider: nil,
                    coingeckoPriceId: nil,
                    priceData: [],
                    coinbaseUrl: nil,
                    isCustom: true
                )

                var updatedAssets = chain.assets
                updatedAssets.insert(asset)
                let updatedChain = chain.replacingAssets(Array(updatedAssets))

                let saveOperation = storage.saveOperation({ [updatedChain] }, { [] })
                
                try await withCheckedThrowingContinuation { continuation in
                    saveOperation.completionBlock = {
                        switch saveOperation.result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        case .none:
                            continuation.resume(throwing: CommonError.undefined)
                        }
                    }
                    
                    operationManager.enqueue(operations: [saveOperation], in: .transient)
                }

                let chainAsset = ChainAsset(chain: chain, asset: asset)
                await MainActor.run {
                    output?.didFinishSavingToken(chainAsset: chainAsset)
                }
            } catch {
                await MainActor.run {
                    output?.didReceive(error: error)
                }
            }
        }
    }
} 
