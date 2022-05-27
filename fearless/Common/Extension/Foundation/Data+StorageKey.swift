import Foundation

extension Data {
    func getAccountIdFromKey(accountIdLenght: Int) -> Data { suffix(accountIdLenght) }
}
