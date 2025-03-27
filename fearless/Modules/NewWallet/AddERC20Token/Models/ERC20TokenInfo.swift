import Foundation
import BigInt

struct ERC20TokenInfo {
    let address: String
    let name: String
    let symbol: String
    let decimals: UInt8
    let totalSupply: BigUInt
    let iconURL: URL?
} 