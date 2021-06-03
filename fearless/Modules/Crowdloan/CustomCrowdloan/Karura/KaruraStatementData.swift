import Foundation

struct KaruraStatementData: Decodable {
    let paraId: ParaId
    let statementMsgHash: String
    let statement: String
}
