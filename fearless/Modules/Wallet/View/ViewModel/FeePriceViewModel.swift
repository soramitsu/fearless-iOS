import CommonWallet

struct FeePriceViewModel: BalanceViewModelProtocol, FeeViewModelProtocol {
    let amount: String
    let price: String?

    let title: String
    let details: String
    let isLoading: Bool
    let allowsEditing: Bool
}
