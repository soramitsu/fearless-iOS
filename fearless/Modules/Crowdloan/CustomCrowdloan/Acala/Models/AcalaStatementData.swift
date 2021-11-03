import Foundation

struct AcalaStatementData: Decodable {
    let paraId: ParaId
    let statementMsgHash: String
    let statement: String
    let proxyAddress: String
}
