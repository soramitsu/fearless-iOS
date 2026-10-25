import Foundation

public struct PayExternalMessage {
    let address: Address
    let message: Cell
    let body: Cell
}

public struct SubscriptionV1: Contract {
    public let code: Cell
    public var workchain: Int8
    public var wallet: Address
    public var beneficiary: Address
    public var amount: Coins
    public var period: UInt64
    public var timeout: UInt64
    public var startAt: UInt64
    public var subscriptionId: UInt64
    
    public init(
        workchain: Int8,
        wallet: Address,
        beneficiary: Address,
        amount: Coins,
        period: UInt64,
        timeout: UInt64,
        startAt: UInt64,
        subscriptionId: UInt64
    ) {
        self.workchain = workchain
        self.wallet = wallet
        self.beneficiary = beneficiary
        self.amount = amount
        self.period = period
        self.timeout = timeout
        self.startAt = startAt
        self.subscriptionId = subscriptionId
        
        let boc = "te6cckECDwEAAmIAART/APSkE/S88sgLAQIBIAIDAgFIBAUDavIw2zxTNaEnqQT4IyehKKkEAbxRNaD4I7kTsPKe+AByUhC+lFOH8AeOhVOG2zyk4vgjAts8CwwNAgLNBgcBIaDQybZ4E/SI3gQR9IjeBBATCwSP1tngXoaYGY/SAYKYRjgsdOL4QZmemPmEEIMjm6OV1JeAPwGLhBCDq3NbvtnnAphOOC2cdGiEYvhjhBCDq3NbvtnnAVa6TgkECwoKCAJp8Q/SIYQJOIbZ58EsEIMjm6OThACGRlgqgDZ4soAf0BCmW1ZY+JZZ/kuf2AP8EIMjm6OW2eQOCgTwjo0QjF8McIIQdW5rd9s84ArTHzCCEHBsdWeDHrFSELqPSDBTJKEmqQT4IyahJ6kEvvJxCfpEMKYZ+DPQeNch1ws/UmChG76OkjA2+CNwcIIQc3VicydZ2zxQd94QaRBYEEcQNkUTUELbPOA5XwdsIjKCEGRzdHK6CgoNCQEajol/ghBkc3Ry2zzgMAoAaCGzmYIQBAAAAHL7At5w+CdvEYAQyMsFUAXPFiH6AhT0ABPLaRLLH4MGApSBAKAy3skB+wAAMO1E0PpA+kD6ANMf0x/TH9Mf0x/TB9MfMAGAIfpEMCCBOpjbPAGmGfgz0HjXIdcLP6Bw+CWCEHBsdWcigBjIywVQB88WUAT6AhXLahLLHxPLPwH6AssAyXP7AA4AQMhQCs8WUAjPFlAG+gIUyx8Syx/LH8sfyx/LB8sfye1UAFgBphX4M9Ag1wsHgQDRupWBAIjXId7TByGBAN26AoEA3roSsfLgR9M/MKirD+WFWrQ="
        self.code = try! Cell.fromBoc(src: Data(base64Encoded: boc)!)[0]
    }
    
    public var stateInit: StateInit {
        let data = try! Builder()
            .store(wallet)
            .store(beneficiary)
            .store(coins: amount)
            .store(uint: period, bits: 32)
            .store(uint: startAt, bits: 32) // start_time
            .store(uint: timeout, bits: 32)
            .store(uint: 0, bits: 32) // last_payment_time
            .store(uint: 0, bits: 32) // last_request_time
            .store(uint: 0, bits: 8) // failed_attempts
            .store(uint: subscriptionId, bits: 32) // subscription_id
            .endCell()
        
        return StateInit(code: code, data: data)
    }
    
    public func createPayExternalMessage() throws -> PayExternalMessage {
        let selfAddress = try address()
        let header = Message(
            info: CommonMsgInfo.externalInInfo(
                info: .init(
                    src: nil,
                    dest: selfAddress,
                    importFee: Coins(0)
                )
            ),
            stateInit: nil,
            body: .empty
        )
        
        let message = try Builder().store(header).endCell()
        
        let defaultTimeout = UInt64(Date().timeIntervalSince1970) + 60 // Default timeout: 60 seconds
        let body = try Builder().store(uint: defaultTimeout, bits: 64).endCell() // this is not required by the contract; just to make it easier to distinguish messages
        
        return PayExternalMessage(address: selfAddress, message: message, body: body)
    }
}
