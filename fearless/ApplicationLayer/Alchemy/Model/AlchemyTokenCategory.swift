import Foundation

enum AlchemyTokenCategory: String, Encodable {
    case external
    case `internal`
    case erc20
    case erc721
    case erc1155
    case specialnft
}
