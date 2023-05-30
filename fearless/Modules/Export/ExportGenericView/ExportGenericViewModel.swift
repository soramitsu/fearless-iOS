import UIKit
import SSFModels

protocol ExportGenericViewModelBinding {
    func bind(stringViewModel: ExportStringViewModel, locale: Locale) -> UIView
    func bind(multilineViewModel: ExportStringViewModel, locale: Locale) -> UIView
    func bind(mnemonicViewModel: ExportMnemonicViewModel, locale: Locale) -> UIView
}

protocol MultipleExportGenericViewModelProtocol {
    var viewModels: [ExportGenericViewModelProtocol] { get }
    var option: ExportOption { get }
    var flow: ExportFlow { get }
}

protocol ExportGenericViewModelProtocol {
    var chain: ChainModel? { get }
    var cryptoType: CryptoType? { get }
    var derivationPath: String? { get }
    var ethereumBased: Bool { get }

    func accept(binder: ExportGenericViewModelBinding, locale: Locale) -> UIView
}

struct MultiExportViewModel: MultipleExportGenericViewModelProtocol {
    let viewModels: [ExportGenericViewModelProtocol]
    let option: ExportOption
    let flow: ExportFlow
}

struct ExportStringViewModel: ExportGenericViewModelProtocol {
    let option: ExportOption

    let chain: ChainModel?

    let cryptoType: CryptoType?

    let derivationPath: String?

    let data: String

    let ethereumBased: Bool

    func accept(binder: ExportGenericViewModelBinding, locale: Locale) -> UIView {
        if option == .seed {
            return binder.bind(multilineViewModel: self, locale: locale)
        } else {
            return binder.bind(stringViewModel: self, locale: locale)
        }
    }
}

struct ExportMnemonicViewModel: ExportGenericViewModelProtocol {
    let option: ExportOption

    let chain: ChainModel?

    let cryptoType: CryptoType?

    let derivationPath: String?

    let mnemonic: [String]

    let ethereumBased: Bool

    func accept(binder: ExportGenericViewModelBinding, locale: Locale) -> UIView {
        binder.bind(mnemonicViewModel: self, locale: locale)
    }
}
