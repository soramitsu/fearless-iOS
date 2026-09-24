import Foundation

enum KaiaHistoryError: Error, Equatable {
    case invalidEndpoint
    case missingAPIKey
    case invalidPagination
    case invalidHTTPResponse
    case providerRejected
}

/// KaiaScan native OAPI amounts and fees are decimal KAIA/token units, not wei.
/// Keep them as Decimal through decoding and mapping to avoid a second scaling step.
struct KaiaHistoryResponse: Decodable {
    let results: [KaiaHistoryTransaction]
    let paging: KaiaHistoryPaging

    func validatedTransactions(page: Int, address: String, tokenContract: String?) throws -> [KaiaHistoryTransaction] {
        let documentedEmptyPage = page == 1 && paging.currentPage == 0 &&
            paging.totalCount == 0 && paging.totalPage == 0 && paging.last && results.isEmpty
        guard paging.currentPage == page || documentedEmptyPage,
              paging.totalCount >= 0,
              paging.totalPage >= 0,
              !(!paging.last && results.isEmpty) else {
            throw KaiaHistoryError.providerRejected
        }

        for transaction in results {
            let involvedAddresses = [transaction.fromAddress, transaction.toAddress, transaction.feePayer]
                .compactMap { $0 }
            let matchesAccount = involvedAddresses.contains {
                $0.caseInsensitiveCompare(address) == .orderedSame
            }
            guard transaction.amount >= 0,
                  !transaction.transactionHash.isEmpty,
                  transaction.timestampInSeconds != nil,
                  matchesAccount else {
                throw KaiaHistoryError.providerRejected
            }

            if let tokenContract {
                guard transaction.contract?.contractAddress.caseInsensitiveCompare(tokenContract) == .orderedSame else {
                    throw KaiaHistoryError.providerRejected
                }
            } else {
                guard let fee = transaction.transactionFee, fee >= 0,
                      let status = transaction.status?.status,
                      ["Success", "Fail"].contains(status) else {
                    throw KaiaHistoryError.providerRejected
                }
            }
        }

        return results
    }
}

struct KaiaHistoryPaging: Decodable {
    let totalCount: Int64
    let currentPage: Int
    let last: Bool
    let totalPage: Int
}

struct KaiaHistoryTransaction: Decodable {
    struct Contract: Decodable {
        let contractAddress: String
    }

    struct Status: Decodable {
        let status: String
    }

    let transactionHash: String
    let datetime: String
    let fromAddress: String
    let toAddress: String?
    let amount: Decimal
    let transactionFee: Decimal?
    let feePayer: String?
    let status: Status?
    let contract: Contract?

    private enum CodingKeys: String, CodingKey {
        case transactionHash, datetime, amount, transactionFee, feePayer, status, contract
        case fromAddress = "from"
        case toAddress = "to"
    }

    var timestampInSeconds: Int64? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: datetime) {
            return Int64(date.timeIntervalSince1970)
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: datetime).map { Int64($0.timeIntervalSince1970) }
    }
}
