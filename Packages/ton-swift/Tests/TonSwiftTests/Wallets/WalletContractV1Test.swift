import XCTest
import TweetNacl
import BigInt
@testable import TonSwift

final class WalletContractV1Test: XCTestCase {
    
    private let publicKey = Data(hex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    private let secretKey = Data(hex: "34aebb9ea454967f16c407c0f8877763e86212116468169d93a3dcbcafe530c95754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    
    func testR1() throws {
        let contractR1 = try WalletV1(workchain: 0, publicKey: publicKey, revision: .r1)
        
        XCTAssertEqual(try contractR1.address(), try Address.parse("EQCtW_zzk6n82ebaVQFq8P_04wOemYhtwqMd3NuArmPODRvD"))
        XCTAssertEqual(try contractR1.stateInit.data?.toString(), "x{000000005754865E86D0ADE1199301BBB0319A25ED6B129C4B0A57F28F62449B3DF9C522}")
        XCTAssertEqual(try contractR1.stateInit.code?.toString(), "x{FF0020DDA4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54}")
        
        let transfer = try contractR1.createTransfer(args: try args())
        let transferCell = try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: secretKey))
        XCTAssertEqual(try transferCell.toString(), "x{44811DCDDFD331B4CF82F2AE62532E0EDCA1976BDF50B48E6EC3E108347CBB47DDDFCCB4A8980F3AED4417084B62268F8F19CCCD3940835DE54C5151722957030000003E01}\n x{62007D507CF9B4D00622B6DC23E0BA7F3CA9584A13C5A3830F3DA8E9B76F27EFF641202FAF0800000000000000000000000000000000000048656C6C6F2C20776F726C6421}")
    }
    
    func testR2() throws {
        let contractR2 = try WalletV1(workchain: 0, publicKey: publicKey, revision: .r2)
        
        XCTAssertEqual(try contractR2.address(), try Address.parse("EQATDkvcCA2fFWbSTHMpGCrjkNGqgEywES15ZS11HHY3UuxK"))
        XCTAssertEqual(try contractR2.stateInit.data?.toString(), "x{000000005754865E86D0ADE1199301BBB0319A25ED6B129C4B0A57F28F62449B3DF9C522}")
        XCTAssertEqual(try contractR2.stateInit.code?.toString(), "x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54}")
        
        let transfer = try contractR2.createTransfer(args: try args())
        let transferCell = try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: secretKey))
        XCTAssertEqual(try transferCell.toString(), "x{44811DCDDFD331B4CF82F2AE62532E0EDCA1976BDF50B48E6EC3E108347CBB47DDDFCCB4A8980F3AED4417084B62268F8F19CCCD3940835DE54C5151722957030000003E01}\n x{62007D507CF9B4D00622B6DC23E0BA7F3CA9584A13C5A3830F3DA8E9B76F27EFF641202FAF0800000000000000000000000000000000000048656C6C6F2C20776F726C6421}")
    }
    
    func testR3() throws {
        let contractR3 = try WalletV1(workchain: 0, publicKey: publicKey, revision: .r3)
        
        XCTAssertEqual(try contractR3.address(), try Address.parse("EQBRRPBUtgzq5om6O4rtxwPW4hyDxiXYeIko27tvsm97kUw3"))
        XCTAssertEqual(try contractR3.stateInit.data?.toString(), "x{000000005754865E86D0ADE1199301BBB0319A25ED6B129C4B0A57F28F62449B3DF9C522}")
        XCTAssertEqual(try contractR3.stateInit.code?.toString(), "x{FF0020DD2082014C97BA218201339CBAB19C71B0ED44D0D31FD70BFFE304E0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54}")
        
        let transfer = try contractR3.createTransfer(args: try args())
        let transferCell = try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: secretKey))
        XCTAssertEqual(try transferCell.toString(), "x{44811DCDDFD331B4CF82F2AE62532E0EDCA1976BDF50B48E6EC3E108347CBB47DDDFCCB4A8980F3AED4417084B62268F8F19CCCD3940835DE54C5151722957030000003E01}\n x{62007D507CF9B4D00622B6DC23E0BA7F3CA9584A13C5A3830F3DA8E9B76F27EFF641202FAF0800000000000000000000000000000000000048656C6C6F2C20776F726C6421}")
    }
    
    private func args() throws -> WalletTransferData {
        return try WalletTransferData(
            seqno: 62,
            messages: [
                .internal(
                    to: Address.parse("kQD6oPnzaaAMRW24R8F0_nlSsJQni0cGHntR027eT9_sgtwt"),
                    value: BigUInt(0.1 * 1000000000),
                    textPayload: "Hello, world!"
                )
            ],
            sendMode: SendMode(payMsgFees: true),
            timeout: nil
        )
    }
}
