import BigInt
import Foundation

/// All wallets implement a compatible interface for sending messages
public protocol WalletContract: Contract {
    func createTransfer(args: WalletTransferData) throws -> WalletTransfer
}

public struct WalletTransferData {
    public let seqno: UInt64
    public let messages: [MessageRelaxed]
    public let sendMode: SendMode
    public let timeout: UInt64?
    
    public init(seqno: UInt64,
                messages: [MessageRelaxed],
                sendMode: SendMode,
                timeout: UInt64?) {
        self.seqno = seqno
        self.messages = messages
        self.sendMode = sendMode
        self.timeout = timeout
    }
}

public struct WalletTransfer {
    private let signingMessage: Builder
    
    public init(signingMessage: Builder) {
        self.signingMessage = signingMessage
    }
    
    public func signMessage(signer: WalletTransferSigner) throws -> Cell {
        let signature = try signer.signMessage(signingMessage.endCell().hash())
        let body = Builder()
        try body.store(data: signature)
        try body.store(signingMessage)
        
        return try body.endCell()
    }
}
