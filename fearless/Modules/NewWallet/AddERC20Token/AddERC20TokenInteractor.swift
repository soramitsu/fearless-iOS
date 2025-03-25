import Foundation
import Web3
import SSFModels
import RobinHood
import Web3ContractABI

final class AddERC20TokenInteractor {
    // MARK: - Private properties

    private weak var output: AddERC20TokenInteractorOutput?
    private let web3: Web3.Eth
    private let chain: ChainModel
    private let storage: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    // MARK: - Constructors

    init(
        chain: ChainModel,
        storage: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.storage = storage
        self.operationManager = operationManager
        
        // Инициализация Web3 с RPC URL для Ethereum
        let rpcURL = "https://mainnet.infura.io/v3/YOUR-PROJECT-ID" // Замените на ваш RPC URL
        self.web3 = Web3(rpcURL: rpcURL).eth
    }
}

// MARK: - AddERC20TokenInteractorInput

extension AddERC20TokenInteractor: AddERC20TokenInteractorInput {
    func setup(with output: AddERC20TokenInteractorOutput) {
        self.output = output
    }

    func validateAndFetchToken(address: String) {
        Task {
            do {
                // Проверяем, что адрес валидный
                let contractAddress = try EthereumAddress(rawAddress: address.hexToBytes())

                // Создаем контракт ERC20
                let contract = web3.Contract(type: GenericERC20Contract.self, address: contractAddress)

                // Получаем данные токена
                async let name = contract.name().call()
                async let symbol = contract.symbol().call()
                async let decimals = contract.decimals().call()
                async let totalSupply = contract.totalSupply().call()

                let (nameResult, symbolResult, decimalsResult, totalSupplyResult) = await (name, symbol, decimals, totalSupply)

                guard let name = nameResult.value?["_name"] as? String,
                      let symbol = symbolResult.value?["_symbol"] as? String,
                      let decimals = decimalsResult.value?["_decimals"] as? UInt8,
                      let totalSupply = totalSupplyResult.value?["_totalSupply"] as? BigUInt else {
                    throw AddERC20TokenError.invalidTokenData
                }

                let tokenInfo = ERC20TokenInfo(
                    address: address,
                    name: name,
                    symbol: symbol,
                    decimals: decimals,
                    totalSupply: totalSupply
                )

                await MainActor.run {
                    output?.didReceive(tokenInfo: tokenInfo)
                }
            } catch {
                await MainActor.run {
                    output?.didReceive(error: error)
                }
            }
        }
    }

    func saveToken(_ token: ERC20TokenInfo) {
        Task {
            do {
                // Создаем новый AssetModel
                let asset = AssetModel(
                    id: token.address,
                    name: token.name,
                    symbol: token.symbol,
                    precision: UInt16(token.decimals),
                    icon: nil,
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
                    coinbaseUrl: nil
                )

                // Создаем обновленную цепь с новым ассетом
                var updatedAssets = chain.assets
                updatedAssets.insert(asset)
                let updatedChain = chain.replacingAssets(Array(updatedAssets))

                // Создаем и выполняем операцию сохранения
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

                await MainActor.run {
                    output?.didReceive(tokenInfo: token)
                }
            } catch {
                await MainActor.run {
                    output?.didReceive(error: error)
                }
            }
        }
    }
} 
