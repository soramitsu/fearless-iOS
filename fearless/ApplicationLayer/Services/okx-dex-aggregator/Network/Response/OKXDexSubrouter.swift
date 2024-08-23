import Foundation

struct OKXDexSubrouter: Decodable {
    let dexProtocol: [OKXDexProtocol]
    let fromToken: OKXToken
    let toToken: OKXToken
}
