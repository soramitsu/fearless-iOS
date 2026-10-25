import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils

final class OklinkHistoryOperationFactory {
    static func decodeResponse(_ data: Data?, response: URLResponse?) throws -> OklinkHistoryResponse {
        guard let response = response as? HTTPURLResponse,
              (200 ... 299).contains(response.statusCode) else {
            throw OklinkHistoryError.invalidHTTPResponse
        }
        guard let data else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }
        let decoded = try JSONDecoder().decode(OklinkHistoryResponse.self, from: data)
        _ = try decoded.validatedData()
        return decoded
    }

    static func historyURL(address: String, url: URL, asset: AssetModel, page: String? = nil) -> URL? {
        let requestedPage = page ?? "1"
        guard let pageNumber = Int(requestedPage), pageNumber > 0,
              String(pageNumber) == requestedPage else { return nil }
        var urlComponents = URLComponents(string: url.absoluteString)
        var queryItems = (urlComponents?.queryItems ?? []).filter { $0.name != "page" }
        queryItems.append(URLQueryItem(name: "page", value: requestedPage))
        queryItems.append(URLQueryItem(name: "address", value: address))
        queryItems.append(URLQueryItem(name: "symbol", value: asset.symbol))

        switch asset.ethereumType {
        case .erc20:
            queryItems.append(URLQueryItem(name: "protocolType", value: "token_20"))
        case .bep20, .normal, .none:
            break
        }

        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }

    private func createOperation(
        address: String,
        url: URL,
        chainAsset: ChainAsset,
        page: String?
    ) -> BaseOperation<OklinkHistoryResponse> {
        guard let urlWithParameters = Self.historyURL(
            address: address, url: url, asset: chainAsset.asset, page: page
        ) else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            var apiKey: String
            #if DEBUG
                apiKey = BlockExplorerApiKeysDebug.oklinkApiKey
            #else
                apiKey = BlockExplorerApiKeys.oklinkApiKey
            #endif
            request.setValue(apiKey, forHTTPHeaderField: "Ok-Access-Key")

            return request
        }

        let resultFactory = AnyNetworkResultFactory<OklinkHistoryResponse> { data, response, error in
            do {
                if let error {
                    return .failure(error)
                }
                return try .success(Self.decodeResponse(data, response: response))
            } catch {
                return .failure(error)
            }
        }

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )
    }

    static func mapResponse(
        _ response: OklinkHistoryResponse,
        address: String,
        asset: AssetModel,
        chain: ChainModel,
        requestedPage: String = "1"
    ) throws -> AssetTransactionPageData {
        guard let data = try response.validatedData().first else {
            return AssetTransactionPageData(transactions: [])
        }
        guard let currentPage = Int(data.page), currentPage > 0,
              data.page == requestedPage,
              let totalPage = Int(data.totalPage), totalPage >= 0,
              currentPage <= totalPage || (totalPage == 0 && data.transactionLists.isEmpty)
        else { throw OklinkHistoryError.invalidPagination }

        let transactions = data.transactionLists
            .filter { asset.ethereumType == .normal ? true : $0.tokenContractAddress.lowercased() == asset.id.lowercased() }
            .sorted(by: { $0.transactionTime > $1.transactionTime })
            .compactMap {
                AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
            }.filter { $0.amount.decimalValue > 0 }

        // Advance from provider metadata even when asset filtering removes every row.
        // currentPage < totalPage also makes incrementing currentPage overflow-safe.
        let context = currentPage < totalPage ? ["page": String(currentPage + 1)] : nil
        return AssetTransactionPageData(transactions: transactions, context: context)
    }

    private func createMapOperation(
        dependingOn remoteOperation: BaseOperation<OklinkHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel,
        requestedPage: String
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            try Self.mapResponse(
                remoteOperation.extractNoCancellableResultData(),
                address: address, asset: asset, chain: chain, requestedPage: requestedPage
            )
        }
    }
}

extension OklinkHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard let baseUrl = chain.externalApi?.history?.url else {
            return CompoundOperationWrapper.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let remoteOperation = createOperation(
            address: address,
            url: baseUrl,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            page: pagination.context?["page"]
        )

        let mapOperation = createMapOperation(
            dependingOn: remoteOperation,
            address: address,
            asset: asset,
            chain: chain,
            requestedPage: pagination.context?["page"] ?? "1"
        )

        mapOperation.addDependency(remoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteOperation])
    }
}

struct OklinkHistoryResponse: Codable {
    let code, msg: String
    let data: [OklinkData]

    func validatedData() throws -> [OklinkData] {
        guard code == "0" else {
            throw OklinkHistoryError.providerRejected
        }
        return data
    }
}

enum OklinkHistoryError: Error, Equatable {
    case invalidHTTPResponse
    case providerRejected
    case invalidPagination
}

struct OklinkData: Codable {
    let page, limit, totalPage, chainFullName: String
    let chainShortName: String
    let transactionLists: [OklinkTransactionItem]
}

struct OklinkTransactionItem: Codable {
    let txID, methodID, blockHash, height: String
    let transactionTime, from, to: String
    let isFromContract, isToContract: Bool
    let amount, transactionSymbol, txFee, state: String
    let tokenID, tokenContractAddress, challengeStatus, l1OriginHash: String

    enum CodingKeys: String, CodingKey {
        case txID = "txId"
        case methodID = "methodId"
        case blockHash, height, transactionTime, from, to, isFromContract, isToContract, amount, transactionSymbol, txFee, state
        case tokenID = "tokenId"
        case tokenContractAddress, challengeStatus, l1OriginHash
    }
}
