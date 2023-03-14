import Foundation

protocol NetworkIssuesNotificationViewModelFactoryProtocol {
    func buildViewModel(
        for issues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> [NetworkIssuesNotificationCellViewModel]
}

// swiftlint:disable type_name
final class NetworkIssuesNotificationViewModelFactory: NetworkIssuesNotificationViewModelFactoryProtocol {
    func buildViewModel(
        for issues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> [NetworkIssuesNotificationCellViewModel] {
        issues.map { issue in
            switch issue {
            case let .network(chains: chains):
                return buildNetworkIssueViewModel(for: chains, locale: locale, chainSettings: chainSettings)
            case let .missingAccount(chains: chains):
                return buildMissingAccountViewModel(for: chains, locale: locale)
            }
        }.reduce([], +)
    }

    private func buildNetworkIssueViewModel(
        for chains: [ChainModel],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> [NetworkIssuesNotificationCellViewModel] {
        let mutedChainIds = chainSettings.filter { $0.issueMuted }.map { $0.chainId }

        return chains.filter { !mutedChainIds.contains($0.chainId) }.map { chain in

            let imageViewViewModel = chain.icon.map { buildRemoteImageViewModel(url: $0) }

            let chainNameTitle = chain.name + " "
                + R.string.localizable.commonNetwork(
                    preferredLanguages: locale.rLanguages
                )

            var issueDescription: String
            var buttonType: NetworkIssuesActionButtonType

            if chain.nodes.count == 1 {
                issueDescription = R.string.localizable.networkIssueStub(
                    preferredLanguages: locale.rLanguages
                )
                buttonType = .networkUnavailible
            } else {
                issueDescription = R.string.localizable.networkIssueNodeUnavailable(
                    preferredLanguages: locale.rLanguages
                )
                buttonType = .switchNode(
                    title: R.string.localizable.switchNode(
                        preferredLanguages: locale.rLanguages
                    )
                )
            }

            return NetworkIssuesNotificationCellViewModel(
                imageViewViewModel: imageViewViewModel,
                chainNameTitle: chainNameTitle,
                issueDescription: issueDescription,
                buttonType: buttonType,
                chain: chain
            )
        }
    }

    private func buildMissingAccountViewModel(
        for chains: [ChainModel],
        locale: Locale
    ) -> [NetworkIssuesNotificationCellViewModel] {
        chains.map { chain in

            let imageViewViewModel = chain.icon.map { buildRemoteImageViewModel(url: $0) }
            let issueDescription = R.string.localizable.manageAssetsAccountMissingText(
                preferredLanguages: locale.rLanguages
            )

            return NetworkIssuesNotificationCellViewModel(
                imageViewViewModel: imageViewViewModel,
                chainNameTitle: chain.name,
                issueDescription: issueDescription,
                buttonType: .missingAccount(
                    title: R.string.localizable.accountsAddAccount(preferredLanguages: locale.rLanguages)
                ),
                chain: chain
            )
        }
    }
}

extension NetworkIssuesNotificationViewModelFactory: RemoteImageViewModelFactoryProtocol {}
