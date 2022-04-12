import UIKit
import FearlessUtils

protocol WalletDetailsViewModelFactoryProtocol {
    func buildNormalViewModel(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> WalletDetailsViewModel

    func buildExportViewModel(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> WalletExportViewModel
}

class WalletDetailsViewModelFactory {
    private func buildSection(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> WalletDetailsSection {
        WalletDetailsSection(
            title: R.string.localizable.accountsWithOneKey(preferredLanguages: locale.rLanguages),
            viewModels: chainAccounts.compactMap { chainAccount in
                let icon = chainAccount.chain.icon.map { RemoteImageViewModel(url: $0) }
                let address = chainAccount.account.toAddress()
                var addressImage: UIImage?
                if let address = address {
                    addressImage = try? PolkadotIconGenerator().generateFromAddress(address)
                        .imageWithFillColor(
                            R.color.colorBlack()!,
                            size: UIConstants.normalAddressIconSize,
                            contentScale: UIScreen.main.scale
                        )
                }

                return WalletDetailsCellViewModel(
                    chainImageViewModel: icon,
                    chainAccount: chainAccount,
                    addressImage: addressImage,
                    address: address,
                    actionsAvailable: flow.actionsAvailable
                )
            }
        )
    }

    private func buildSections(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> [WalletDetailsSection] {
        let nativeAccounts = chainAccounts.filter { $0.account.isChainAccount == false }
        let customAccounts = chainAccounts.filter { $0.account.isChainAccount == true }
        let nativeSection = buildSection(flow: flow, chainAccounts: nativeAccounts, locale: locale)
        let customSection = buildSection(flow: flow, chainAccounts: customAccounts, locale: locale)

        return [nativeSection, customSection]
    }
}

extension WalletDetailsViewModelFactory: WalletDetailsViewModelFactoryProtocol {
    func buildNormalViewModel(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> WalletDetailsViewModel {
        let sections = buildSections(flow: flow, chainAccounts: chainAccounts, locale: locale)
        return WalletDetailsViewModel(
            navigationTitle: R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages),
            sections: sections
        )
    }

    func buildExportViewModel(
        flow: WalletDetailsFlow,
        chainAccounts: [ChainAccountInfo],
        locale: Locale
    ) -> WalletExportViewModel {
        let sections = buildSections(flow: flow, chainAccounts: chainAccounts, locale: locale)
        return WalletExportViewModel(
            navigationTitle: R.string.localizable.accountsForExport(preferredLanguages: locale.rLanguages),
            sections: sections
        )
    }
}
