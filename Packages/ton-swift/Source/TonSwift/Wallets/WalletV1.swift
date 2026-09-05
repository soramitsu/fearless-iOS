import Foundation
import BigInt
import TweetNacl

public enum WalletContractV1Revision {
    case r1, r2, r3
}

public final class WalletV1: WalletContract {
    public let workchain: Int8
    public let stateInit: StateInit
    public let publicKey: Data
    public let revision: WalletContractV1Revision
    
    public init(workchain: Int8, publicKey: Data, revision: WalletContractV1Revision) throws {
        self.workchain = workchain
        self.publicKey = publicKey
        self.revision = revision
        
        var bocString: String
        switch revision {
        case .r1:
            bocString = "te6cckEBAQEARAAAhP8AIN2k8mCBAgDXGCDXCx/tRNDTH9P/0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVEH98Ik="
            
        case .r2:
            bocString = "te6cckEBAQEAUwAAov8AIN0gggFMl7qXMO1E0NcLH+Ck8mCBAgDXGCDXCx/tRNDTH9P/0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVNDieG8="
            
        case .r3:
            bocString = "te6cckEBAQEAXwAAuv8AIN0gggFMl7ohggEznLqxnHGw7UTQ0x/XC//jBOCk8mCBAgDXGCDXCx/tRNDTH9P/0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVLW4bkI="
        }
        
        let cell = try Cell.fromBoc(src: Data(base64Encoded: bocString)!)[0]
        let data = try Builder().store(uint: UInt64(0), bits: 32) // Seqno
        try data.store(data: publicKey)
        
        self.stateInit = StateInit(code: cell, data: try data.endCell())
    }
    
    public func createTransfer(args: WalletTransferData) throws -> WalletTransfer {
        let signingMessage = try Builder().store(uint: args.seqno, bits: 32)
        
        if let message = args.messages.first {
            try signingMessage.store(uint: UInt64(args.sendMode.rawValue), bits: 8)
            try signingMessage.store(ref:try Builder().store(message))
        }
        
        return WalletTransfer(signingMessage: signingMessage)
    }
}
