import Foundation

protocol AllDoneViewModelFactoryProtocol {
    func buildViewModel(
        title: String?,
        description: String?,
        extrinsicHash: String,
        locale: Locale
    ) -> AllDoneViewModel
}

final class AllDoneViewModelFactory: AllDoneViewModelFactoryProtocol {
    func buildViewModel(
        title: String?,
        description: String?,
        extrinsicHash: String,
        locale: Locale
    ) -> AllDoneViewModel {
        let defaultTitle = R.string.localizable
            .allDoneAlertAllDoneStub(preferredLanguages: locale.rLanguages)
        let defaultDesription = R.string.localizable
            .allDoneAlertDescriptionStub(preferredLanguages: locale.rLanguages)

        return AllDoneViewModel(
            title: title ?? defaultTitle,
            description: description ?? defaultDesription,
            extrinsicHash: extrinsicHash
        )
    }
}
