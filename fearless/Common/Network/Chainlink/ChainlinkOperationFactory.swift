import Foundation
import Web3
import SSFModels
import RobinHood
import Web3ContractABI

protocol ChainlinkOperationFactory {
    func priceCall(for chainAsset: ChainAsset, connection: Web3.Eth?) -> BaseOperation<PriceData>?
}

final class ChainlinkOperationFactoryImpl: ChainlinkOperationFactory {
    private lazy var chainRegistry: ChainRegistryProtocol = {
        ChainRegistryFacade.sharedRegistry
    }()

    func priceCall(for chainAsset: ChainAsset, connection: Web3.Eth?) -> BaseOperation<PriceData>? {
        let operation = ManualOperation<PriceData>()

        do {
            guard let contract = chainAsset.asset.priceProvider?.id else {
                throw ConvenienceError(error: "Missing price contract address")
            }
            guard let ws = connection else {
                throw ConvenienceError(error: "Can't get ethereum connection for chain: \(chainAsset.chain.name)")
            }

            let receiverAddress = try EthereumAddress(rawAddress: contract.hexToBytes())

            let outputs: [ABI.Element.InOut] = [
                ABI.Element.InOut(name: "roundId", type: .uint(bits: 80)),
                ABI.Element.InOut(name: "answer", type: .int(bits: 256)),
                ABI.Element.InOut(name: "startedAt", type: .int(bits: 256)),
                ABI.Element.InOut(name: "updatedAt", type: .int(bits: 256)),
                ABI.Element.InOut(name: "answeredInRound", type: .uint(bits: 80))
            ]
            let method = ABI.Element.Function(
                name: "latestRoundData",
                inputs: [],
                outputs: outputs,
                constant: false,
                payable: false
            )
            let priceCall = EthereumCall(
                to: receiverAddress,
                value: EthereumQuantity(quantity: .zero),
                data: try EthereumData(ethereumValue: .string(method.methodString))
            )
            ws.call(call: priceCall, block: .latest) { resp in
                switch resp.status {
                case let .success(result):
                    let decoded = ABIDecoder.decode(types: outputs, data: Data(hex: result.hex()))
                    guard
                        let price = decoded?[safe: 1] as? BigInt,
                        let precision = chainAsset.asset.priceProvider?.precision,
                        let priceDecimal = Decimal.fromSubstrateAmount(BigUInt(price), precision: precision)
                    else {
                        let error = ConvenienceError(error: "Decoding price error")
                        operation.result = .failure(error)
                        operation.finish()
                        return
                    }

                    let priceData = PriceData(
                        currencyId: "usd",
                        priceId: contract,
                        price: "\(priceDecimal)",
                        fiatDayChange: nil,
                        coingeckoPriceId: chainAsset.asset.coingeckoPriceId
                    )
                    operation.result = .success(priceData)
                    operation.finish()

                case let .failure(error):
                    operation.result = .failure(error)
                    operation.finish()
                }
            }
        } catch {
            operation.result = .failure(error)
            operation.finish()
            Logger.shared.customError(error)
            return nil
        }

        return operation
    }
}
