import Foundation

struct OKXToken: Decodable {
    enum CodingKeys: String, CodingKey {
        case decimals
        case tokenContractAddress
        case tokenLogoUrl
        case tokenName
        case tokenSymbol
    }

    let decimals: String?
    let tokenContractAddress: String
    let tokenLogoUrl: String?
    let tokenName: String?
    let tokenSymbol: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        tokenContractAddress = try container.decode(String.self, forKey: .tokenContractAddress)
        tokenLogoUrl = try container.decodeIfPresent(String.self, forKey: .tokenLogoUrl)
        tokenName = try container.decodeIfPresent(String.self, forKey: .tokenName)
        tokenSymbol = try container.decode(String.self, forKey: .tokenSymbol)

        do {
            decimals = try container.decodeIfPresent(String.self, forKey: .decimals)
        } catch {
            let decimalsValue = try container.decode(UInt32.self, forKey: .decimals)
            decimals = "\(decimalsValue)"
        }
    }
}
