import Foundation
import Web3
import Web3PromiseKit
import Web3ContractABI
import SSFModels

protocol EthereumBalanceFetching {
    func fetchBalance(chainAsset: ChainAsset, address: String) async throws -> BigUInt
}

final class EthereumBalanceFetcher: EthereumBalanceFetching {
    func fetchBalance(chainAsset: ChainAsset, address: String) async throws -> BigUInt {
        let eth = try chainAsset.eth()

        if chainAsset.asset.isUtility {
            return try await withCheckedThrowingContinuation { continuation in
                do {
                    let ethereumAddress = try EthereumAddress(hex: address, eip55: false)
                    eth.getBalance(address: ethereumAddress, block: .latest) { resp in
                        if let balance = resp.result {
                            return continuation.resume(with: .success(balance.quantity))
                        } else if let error = resp.error {
                            return continuation.resume(with: .failure(error))
                        } else {
                            return continuation.resume(with: .success(.zero))
                        }
                    }
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }
        } else {
            let contractAddress = try EthereumAddress(hex: chainAsset.asset.id, eip55: false)
            let contract = eth.Contract(type: GenericERC20Contract.self, address: contractAddress)

            return try await withCheckedThrowingContinuation { continuation in
                do {
                    try contract.balanceOf(address: EthereumAddress(hex: address, eip55: true)).call(completion: { response, error in

                        if let response = response, let balance = response["_balance"] as? BigUInt {
                            return continuation.resume(with: .success(balance))
                        } else if let error = error {
                            return continuation.resume(with: .failure(error))
                        } else {
                            return continuation.resume(with: .success(.zero))
                        }
                    })
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }
        }
    }
}
