import Foundation

protocol AllDoneViewModelFactoryProtocol {
    func buildViewModel(
        title: String?,
        description: String?,
        extrinsicHash: String?,
        locale: Locale,
        isWalletConnectResult: Bool
    ) -> AllDoneViewModel
}

final class AllDoneViewModelFactory: AllDoneViewModelFactoryProtocol {
    func buildViewModel(
        title: String?,
        description: String?,
        extrinsicHash: String?,
        locale: Locale,
        isWalletConnectResult: Bool
    ) -> AllDoneViewModel {
        let defaultTitle = R.string.localizable
            .commonTransactionSent(preferredLanguages: locale.rLanguages)
        let defaultDesription = R.string.localizable
            .commonTransactionSentDescription(preferredLanguages: locale.rLanguages)

        return AllDoneViewModel(
            title: title ?? defaultTitle,
            description: description ?? defaultDesription,
            extrinsicHash: extrinsicHash,
            isWalletConnectResult: isWalletConnectResult
        )
    }
}
