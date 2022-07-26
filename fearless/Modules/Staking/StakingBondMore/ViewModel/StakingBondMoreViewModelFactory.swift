import SoraFoundation

protocol NetworkFeeFooterViewModelProtocol {
    var actionTitle: LocalizableResource<String> { get }
    var feeTitle: LocalizableResource<String> { get }
    var balanceViewModel: LocalizableResource<BalanceViewModelProtocol> { get }
}

struct NetworkFeeFooterViewModel: NetworkFeeFooterViewModelProtocol {
    var actionTitle: LocalizableResource<String>
    var feeTitle: LocalizableResource<String>
    var balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
}

protocol NetworkFeeViewModelFactoryProtocol {
    func createViewModel(
        from balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
    ) -> LocalizableResource<NetworkFeeFooterViewModelProtocol>
}

final class NetworkFeeViewModelFactory: NetworkFeeViewModelFactoryProtocol {
    func createViewModel(
        from balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
    ) -> LocalizableResource<NetworkFeeFooterViewModelProtocol> {
        LocalizableResource { locale in
            let actionTitle = LocalizableResource { locale in
                R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
            }
            let feeTitle = LocalizableResource { locale in
                R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
            }
            return NetworkFeeFooterViewModel(
                actionTitle: actionTitle,
                feeTitle: feeTitle,
                balanceViewModel: balanceViewModel
            )
        }
    }
}
