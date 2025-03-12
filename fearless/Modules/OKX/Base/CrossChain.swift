struct CrossChain {
    enum Constants {
        static let approveTxSecondsDelay: Int = 6
        static let refreshSecondsDelay: Int = 1
        static let txReasonCrossChain: String = "cross-chain"
        static let txReasonSwap: String = "swap"
        
        static let referrerAddress: String = "0x6f854d0d24ad6f5c4fa46373488e2fffb562d86c"
        static let walletFeePercent: String = "0.5"
    }
}
