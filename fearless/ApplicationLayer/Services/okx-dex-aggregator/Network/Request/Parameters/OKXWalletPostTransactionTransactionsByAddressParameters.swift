final class OKXWalletPostTransactionTransactionsByAddressParameters: NetworkRequestUrlParameters, Decodable {
    let address: String
    let chains: String
    let tokenAddress: String?
    
    init(address: String, chains: String, tokenAddress: String?) {
        self.address = address
        self.chains = chains
        self.tokenAddress = tokenAddress
    }
}
