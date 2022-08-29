import Foundation

protocol NetworkIssuesNotificationViewModelFactoryProtocol {
    func buildViewModel(
        for issues: [ChainIssue],
        locale: Locale
    ) -> [NetworkIssuesNotificationCellViewModel]
}

final class NetworkIssuesNotificationViewModelFactory: NetworkIssuesNotificationViewModelFactoryProtocol {
    func buildViewModel(
        for issues: [ChainIssue],
        locale: Locale
    ) -> [NetworkIssuesNotificationCellViewModel] {
        issues.map { issue in
            switch issue {
            case let .network(chains: chains):
                return chains.map { chain in

                    let imageViewViewModel = chain.icon.map { buildRemoteImageViewModel(url: $0) }

                    let chainNameTitle = chain.name + " "
                        + R.string.localizable.commonNetwork(
                            preferredLanguages: locale.rLanguages
                        )

                    var issueDescription: String
                    var buttonType: NetworkIssuesActionButtonType

                    if chain.nodes.count == 1 {
                        issueDescription = "Network is unavailible"
                        buttonType = .networkUnavailible
                    } else {
                        issueDescription = "Node is unavailible "
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
            case let .missingAccount(chains: chains):
                return chains.map { chain in

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
        }.reduce([], +)
    }
}

extension NetworkIssuesNotificationViewModelFactory: RemoteImageViewModelFactoryProtocol {}
