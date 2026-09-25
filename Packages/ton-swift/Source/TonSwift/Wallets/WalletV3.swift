import Foundation
import BigInt
import TweetNacl

public enum WalletContractV3Revision {
    case r1, r2
}

public final class WalletV3: WalletContract {
    public let workchain: Int8
    public let stateInit: StateInit
    public let publicKey: Data
    public let walletId: UInt64
    public let revision: WalletContractV3Revision
    
    public init(workchain: Int8, publicKey: Data, walletId: UInt64? = nil, revision: WalletContractV3Revision) throws {
        self.workchain = workchain
        self.publicKey = publicKey
        self.revision = revision
        
        if let walletId {
            self.walletId = walletId
        } else {
            self.walletId = 698983191 + UInt64(workchain)
        }
        
        var bocString: String
        switch revision {
        case .r1:
            bocString = "te6cckEBAQEAYgAAwP8AIN0gggFMl7qXMO1E0NcLH+Ck8mCDCNcYINMf0x/TH/gjE7vyY+1E0NMf0x/T/9FRMrryoVFEuvKiBPkBVBBV+RDyo/gAkyDXSpbTB9QC+wDo0QGkyMsfyx/L/8ntVD++buA="
            
        case .r2:
            bocString = "te6cckEBAQEAcQAA3v8AIN0gggFMl7ohggEznLqxn3Gw7UTQ0x/THzHXC//jBOCk8mCDCNcYINMf0x/TH/gjE7vyY+1E0NMf0x/T/9FRMrryoVFEuvKiBPkBVBBV+RDyo/gAkyDXSpbTB9QC+wDo0QGkyMsfyx/L/8ntVBC9ba0="
        }
        
        let cell = try Cell.fromBoc(src: Data(base64Encoded: bocString)!)[0]
        let data = try Builder()
            .store(uint: UInt64(0), bits: 32) // Seqno
            .store(uint: self.walletId, bits: 32)
        try data.store(data: publicKey)
        
        self.stateInit = StateInit(code: cell, data: try data.endCell())
    }
    
    public func createTransfer(args: WalletTransferData) throws -> WalletTransfer {
        guard args.messages.count <= 4 else {
            throw TonError.custom("Maximum number of messages in a single transfer is 4")
        }
        
        let signingMessage = try Builder().store(uint: walletId, bits: 32)
        let defaultTimeout = UInt64(Date().timeIntervalSince1970) + 60 // Default timeout: 60 seconds
        try signingMessage.store(uint: args.timeout ?? defaultTimeout, bits: 32)
        
        try signingMessage.store(uint: args.seqno, bits: 32)
        for message in args.messages {
            try signingMessage.store(uint: UInt64(args.sendMode.rawValue), bits: 8)
            try signingMessage.store(ref: try Builder().store(message))
        }
      
        return WalletTransfer(signingMessage: signingMessage)
    }
}
