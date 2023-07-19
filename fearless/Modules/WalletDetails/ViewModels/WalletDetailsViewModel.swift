enum WalletDetailsViewState {
    case normal(viewModel: WalletDetailsViewModel)
    case export(viewModel: WalletExportViewModel)
}

struct WalletDetailsViewModel {
    let navigationTitle: String
    let walletName: String
    let sections: [WalletDetailsSection]
}

struct WalletExportViewModel {
    let navigationTitle: String
    let walletName: String
    let sections: [WalletDetailsSection]
}

struct WalletDetailsSection {
    let title: String
    let viewModels: [WalletDetailsCellViewModel]
}
