import Foundation
import BigInt
import TweetNacl

public class WalletV4R1: WalletV4 {
    public init(seqno: Int64 = 0,
                workchain: Int8 = 0,
                publicKey: Data,
                walletId: UInt32? = nil,
                plugins: Set<Address> = []
    ) {
        let code = try! Cell.fromBoc(src: Data(base64Encoded: "te6cckECFQEAAvUAART/APSkE/S88sgLAQIBIAIDAgFIBAUE+PKDCNcYINMf0x/THwL4I7vyY+1E0NMf0x/T//QE0VFDuvKhUVG68qIF+QFUEGT5EPKj+AAkpMjLH1JAyx9SMMv/UhD0AMntVPgPAdMHIcAAn2xRkyDXSpbTB9QC+wDoMOAhwAHjACHAAuMAAcADkTDjDQOkyMsfEssfy/8REhMUA+7QAdDTAwFxsJFb4CHXScEgkVvgAdMfIYIQcGx1Z70ighBibG5jvbAighBkc3RyvbCSXwPgAvpAMCD6RAHIygfL/8nQ7UTQgQFA1yH0BDBcgQEI9ApvoTGzkl8F4ATTP8glghBwbHVnupEx4w0kghBibG5juuMABAYHCAIBIAkKAFAB+gD0BDCCEHBsdWeDHrFwgBhQBcsFJ88WUAP6AvQAEstpyx9SEMs/AFL4J28ighBibG5jgx6xcIAYUAXLBSfPFiT6AhTLahPLH1Iwyz8B+gL0AACSghBkc3Ryuo41BIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UghBkc3Rygx6xcIAYUATLBVjPFiL6AhLLassfyz+UEDRfBOLJgED7AAIBIAsMAFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQCAVgNDgARuMl+1E0NcLH4AD2ynftRNCBAUDXIfQEMALIygfL/8nQAYEBCPQKb6ExgAgEgDxAAGa3OdqJoQCBrkOuF/8AAGa8d9qJoQBBrkOuFj8AAbtIH+gDU1CL5AAXIygcVy//J0Hd0gBjIywXLAiLPFlAF+gIUy2sSzMzJcfsAyEAUgQEI9FHypwIAbIEBCNcYyFQgJYEBCPRR8qeCEG5vdGVwdIAYyMsFywJQBM8WghAF9eEA+gITy2oSyx/JcfsAAgBygQEI1xgwUgKBAQj0WfKn+CWCEGRzdHJwdIAYyMsFywJQBc8WghAF9eEA+gIUy2oTyx8Syz/Jc/sAAAr0AMntVEap808=")!)[0]
        super.init(code:code, seqno: seqno, workchain: workchain, publicKey: publicKey, walletId: walletId, plugins: plugins)
    }
}

public class WalletV4R2: WalletV4 {
    public init(seqno: Int64 = 0,
                workchain: Int8 = 0,
                publicKey: Data,
                walletId: UInt32? = nil,
                plugins: Set<Address> = []
    ) {
        let code = try! Cell.fromBoc(src: Data(base64Encoded: "te6ccgECFAEAAtQAART/APSkE/S88sgLAQIBIAIDAgFIBAUE+PKDCNcYINMf0x/THwL4I7vyZO1E0NMf0x/T//QE0VFDuvKhUVG68qIF+QFUEGT5EPKj+AAkpMjLH1JAyx9SMMv/UhD0AMntVPgPAdMHIcAAn2xRkyDXSpbTB9QC+wDoMOAhwAHjACHAAuMAAcADkTDjDQOkyMsfEssfy/8QERITAubQAdDTAyFxsJJfBOAi10nBIJJfBOAC0x8hghBwbHVnvSKCEGRzdHK9sJJfBeAD+kAwIPpEAcjKB8v/ydDtRNCBAUDXIfQEMFyBAQj0Cm+hMbOSXwfgBdM/yCWCEHBsdWe6kjgw4w0DghBkc3RyupJfBuMNBgcCASAICQB4AfoA9AQw+CdvIjBQCqEhvvLgUIIQcGx1Z4MesXCAGFAEywUmzxZY+gIZ9ADLaRfLH1Jgyz8gyYBA+wAGAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+ICASAKCwBZvSQrb2omhAgKBrkPoCGEcNQICEekk30pkQzmkD6f+YN4EoAbeBAUiYcVnzGEAgFYDA0AEbjJftRNDXCx+AA9sp37UTQgQFA1yH0BDACyMoHy//J0AGBAQj0Cm+hMYAIBIA4PABmtznaiaEAga5Drhf/AABmvHfaiaEAQa5DrhY/AAG7SB/oA1NQi+QAFyMoHFcv/ydB3dIAYyMsFywIizxZQBfoCFMtrEszMyXP7AMhAFIEBCPRR8qcCAHCBAQjXGPoA0z/IVCBHgQEI9FHyp4IQbm90ZXB0gBjIywXLAlAGzxZQBPoCFMtqEssfyz/Jc/sAAgBsgQEI1xj6ANM/MFIkgQEI9Fnyp4IQZHN0cnB0gBjIywXLAlAFzxZQA/oCE8tqyx8Syz/Jc/sAAAr0AMntVA==")!)[0]
        super.init(code:code, seqno: seqno, workchain: workchain, publicKey: publicKey, walletId: walletId, plugins: plugins)
    }
}

/// Internal WalletV4 implementation. Use specific revision `WalletV4R1` instead.
public class WalletV4: WalletContract {
    public let seqno: Int64
    public let workchain: Int8
    public let publicKey: Data
    public let walletId: UInt32
    public let plugins: Set<Address>
    public let code: Cell

    fileprivate init(code: Cell,
         seqno: Int64 = 0,
         workchain: Int8 = 0,
         publicKey: Data,
         walletId: UInt32? = nil,
         plugins: Set<Address> = []
    ) {
        self.code = code
        self.seqno = seqno
        self.workchain = workchain
        self.publicKey = publicKey
        
        if let walletId {
            self.walletId = walletId
        } else {
            self.walletId = 698983191 + UInt32(workchain)
        }
        self.plugins = plugins
    }
    
    public var stateInit: StateInit {
        let data = try! Builder()
            .store(uint: 0, bits: 32) // initial seqno = 0
            .store(uint: self.walletId, bits: 32)
            .store(data: publicKey)
            .store(dict: Set<CompactAddress>()) // initial plugins list = []
            .endCell()
        
        return StateInit(code: self.code, data: data)
    }
    
    func pluginsCompact() -> Set<CompactAddress> {
        Set(self.plugins.map{ a in CompactAddress(a) })
    }
    
    public func createTransfer(args: WalletTransferData) throws -> WalletTransfer {
        guard args.messages.count <= 4 else {
            throw TonError.custom("Maximum number of messages in a single transfer is 4")
        }
        
        let signingMessage = try Builder().store(uint: walletId, bits: 32)
        let defaultTimeout = UInt64(Date().timeIntervalSince1970) + 60 // Default timeout: 60 seconds
        try signingMessage.store(uint: args.timeout ?? defaultTimeout, bits: 32)
        
        try signingMessage.store(uint: args.seqno, bits: 32)
        try signingMessage.store(uint: 0, bits: 8) // Simple order
        for message in args.messages {
            try signingMessage.store(uint: UInt64(args.sendMode.rawValue), bits: 8)
            try signingMessage.store(ref: try Builder().store(message))
        }
        
        return WalletTransfer(signingMessage: signingMessage)
    }
}
