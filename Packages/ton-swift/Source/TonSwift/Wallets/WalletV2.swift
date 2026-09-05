import Foundation
import BigInt
import TweetNacl

public enum WalletContractV2Revision {
    case r1, r2
}

public final class WalletV2: WalletContract {
    public let workchain: Int8
    public let stateInit: StateInit
    public let publicKey: Data
    public let revision: WalletContractV2Revision
    
    public init(workchain: Int8, publicKey: Data, revision: WalletContractV2Revision) throws {
        self.workchain = workchain
        self.publicKey = publicKey
        self.revision = revision
        
        var bocString: String
        switch revision {
        case .r1:
            bocString = "te6cckEBAQEAVwAAqv8AIN0gggFMl7qXMO1E0NcLH+Ck8mCDCNcYINMf0x8B+CO78mPtRNDTH9P/0VExuvKhA/kBVBBC+RDyovgAApMg10qW0wfUAvsA6NGkyMsfy//J7VShNwu2"
            
        case .r2:
            bocString = "te6cckEBAQEAYwAAwv8AIN0gggFMl7ohggEznLqxnHGw7UTQ0x/XC//jBOCk8mCDCNcYINMf0x8B+CO78mPtRNDTH9P/0VExuvKhA/kBVBBC+RDyovgAApMg10qW0wfUAvsA6NGkyMsfy//J7VQETNeh"
        }
        
        let cell = try Cell.fromBoc(src: Data(base64Encoded: bocString)!)[0]
        let data = try Builder().store(uint: UInt64(0), bits: 32) // Seqno
        try data.store(data: publicKey)
        
        self.stateInit = StateInit(code: cell, data: try data.endCell())
    }
    
    public func createTransfer(args: WalletTransferData) throws -> WalletTransfer {
        guard args.messages.count <= 4 else {
            throw TonError.custom("Maximum number of messages in a single transfer is 4")
        }
        
        let signingMessage = try Builder().store(uint: args.seqno, bits: 32)
        let defaultTimeout = UInt64(Date().timeIntervalSince1970) + 60 // Default timeout: 60 seconds
        try signingMessage.store(uint: args.timeout ?? defaultTimeout, bits: 32)
        
        for message in args.messages {
            try signingMessage.store(uint: UInt64(args.sendMode.rawValue), bits: 8)
            try signingMessage.store(ref:try Builder().store(message))
        }
        
        return WalletTransfer(signingMessage: signingMessage)
    }
}
