import UIKit

protocol ExportGenericViewModelBinding {
    func bind(stringViewModel: ExportStringViewModel, locale: Locale) -> UIView
}

protocol ExportGenericViewModelProtocol {
    var option: ExportOption { get }
    var networkType: Chain { get }
    var derivationPath: String? { get }
    var cryptoType: CryptoType { get }

    func accept(binder: ExportGenericViewModelBinding, locale: Locale) -> UIView
}

struct ExportStringViewModel: ExportGenericViewModelProtocol {
    let option: ExportOption

    let networkType: Chain

    let derivationPath: String?

    let cryptoType: CryptoType

    let data: String

    func accept(binder: ExportGenericViewModelBinding, locale: Locale) -> UIView {
        binder.bind(stringViewModel: self, locale: locale)
    }
}
