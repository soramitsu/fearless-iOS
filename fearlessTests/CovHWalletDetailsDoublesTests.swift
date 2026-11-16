import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
@testable import fearless

enum CovHWalletDetailsFixture {
    static func explorerChain() -> ChainModel {
        let template = "https://scan.invalid/{type}/{value}"
        let explorers: [ChainModel.ExternalApiExplorer] = [
            .init(type: .subscan, types: [.account], url: template),
            .init(type: .polkascan, types: [.account], url: template),
            .init(type: .etherscan, types: [.address], url: template),
            .init(type: .reef, types: [.account], url: template),
            .init(type: .oklink, types: [.address], url: template),
            .init(type: .unknown, types: [.account], url: template),
            .init(type: .subscan, types: [.extrinsic], url: template)
        ]
        return CovHChainAccountFixture.chain(name: "Explorer chain", externalApi: ChainModel.ExternalApiSet(explorers: explorers))
    }

    static func storedAccount(for chain: ChainModel, byte: UInt8 = 5) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chain.chainId,
            accountId: Data(repeating: byte, count: 32),
            publicKey: Data(repeating: byte, count: 32),
            cryptoType: 0,
            ethereumBased: false
        )
    }

    static func chainAccountResponse(for chain: ChainModel, wallet: MetaAccountModel, isChainAccount: Bool) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: chain.chainId,
            accountId: Data(repeating: 3, count: 32),
            publicKey: Data(repeating: 3, count: 32),
            name: wallet.name,
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: isChainAccount,
            walletId: wallet.metaId
        )
    }

    static func solanaResponse(wallet: MetaAccountModel) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            accountId: Data(repeating: 4, count: 32),
            publicKey: Data(repeating: 4, count: 32),
            name: wallet.name,
            cryptoType: .ed25519,
            addressPrefix: 0,
            isEthereumBased: false,
            isChainAccount: true,
            walletId: wallet.metaId
        )
    }

    static func cell(chain: ChainModel, account: ChainAccountResponse?, address: String? = "cell-address", missing: Bool = false) -> WalletDetailsCellViewModel {
        WalletDetailsCellViewModel(
            chainImageViewModel: nil,
            account: account,
            chain: chain,
            address: address,
            accountMissing: missing,
            actionsAvailable: true,
            locale: Locale(identifier: "en"),
            chainUnused: false
        )
    }

    static func normalModel(sections: [WalletDetailsSection]) -> WalletDetailsViewModel {
        WalletDetailsViewModel(navigationTitle: "Details", walletName: "Cov wallet", sections: sections)
    }

    static func exportModel(sections: [WalletDetailsSection]) -> WalletExportViewModel {
        WalletExportViewModel(navigationTitle: "Export", walletName: "Cov export", sections: sections)
    }
}

final class CovHWalletDetailsViewSpy: UIViewController, WalletDetailsViewProtocol {
    var states: [WalletDetailsViewState] = []
    var locales: [Locale] = []
    func didReceive(state: WalletDetailsViewState) { states.append(state) }
    func didReceive(locale: Locale) { locales.append(locale) }
}

final class CovHWalletDetailsInteractorSpy: WalletDetailsInteractorInputProtocol {
    var calls: [String] = []
    var exportRequests: [ChainAccountInfo] = []
    var unusedChains: [ChainModel] = []
    var selections: [ChainAccountSelection] = []
    var switches: [UniversalWalletNoPasswordAccount] = []

    func setup() { calls.append("setup") }
    func getAvailableExportOptions(for chainAccount: ChainAccountInfo) { exportRequests.append(chainAccount) }
    func markUnused(chain: ChainModel) { unusedChains.append(chain) }
    func selectChainAccount(_ selection: ChainAccountSelection, chain _: ChainModel) { selections.append(selection) }
    func switchToPasswordAccount(_ account: UniversalWalletNoPasswordAccount) { switches.append(account) }
}

final class CovHWalletDetailsFactorySpy: WalletDetailsViewModelFactoryProtocol {
    var normalChains: [[ChainModel]] = []
    var storedChains: [[ChainModel]] = []
    var exportChains: [[ChainModel]] = []
    var searchTexts: [String?] = []

    func buildNormalViewModel(
        flow _: WalletDetailsFlow, chains: [ChainModel], chainsWithStoredAccounts: [ChainModel], locale _: Locale, searchText: String?
    ) -> WalletDetailsViewModel {
        normalChains.append(chains)
        storedChains.append(chainsWithStoredAccounts)
        searchTexts.append(searchText)
        return CovHWalletDetailsFixture.normalModel(sections: [])
    }

    func buildExportViewModel(flow _: WalletDetailsFlow, chains: [ChainModel], locale _: Locale, searchText: String?) -> WalletExportViewModel {
        exportChains.append(chains)
        searchTexts.append(searchText)
        return CovHWalletDetailsFixture.exportModel(sections: [])
    }
}

final class CovHWalletDetailsWireframeSpy: WalletDetailsWireframeProtocol {
    var calls: [String] = []
    var actionItems: [[ChainAction]] = []
    var actionCallbacks: [ModalPickerSelectionCallback] = []
    var exportFlows: [ExportFlow] = []
    var urls: [URL] = []
    var replaceCallbacks: [ModalPickerSelectionCallback] = []
    var accountOptions: [[MissingAccountOption]] = []
    var skipBlocks: [(ChainModel) -> Void] = []
    var sheets: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var presentsErrors = true

    func presentActions(from _: ControllerBackedProtocol?, items: [ChainAction], chain _: ChainModel, callback: @escaping ModalPickerSelectionCallback) {
        calls.append("actions"); actionItems.append(items); actionCallbacks.append(callback)
    }

    func showExport(flow: ExportFlow, options _: [ExportOption], locale _: Locale?, from _: ControllerBackedProtocol?) {
        calls.append("export"); exportFlows.append(flow)
    }

    func presentNodeSelection(from _: ControllerBackedProtocol?, chain _: ChainModel) { calls.append("node") }
    func present(from _: ControllerBackedProtocol, url: URL) { calls.append("url"); urls.append(url) }
    func showUniqueChainSourceSelection(from _: ControllerBackedProtocol?, items _: [ReplaceChainOption], callback: @escaping ModalPickerSelectionCallback) {
        calls.append("replace"); replaceCallbacks.append(callback)
    }

    func showCreate(uniqueChainModel _: UniqueChainModel, from _: ControllerBackedProtocol?) { calls.append("create") }
    func showImport(uniqueChainModel _: UniqueChainModel, from _: ControllerBackedProtocol?) { calls.append("import") }
    func presentAccountOptions(
        from _: ControllerBackedProtocol?,
        locale _: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel _: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    ) {
        calls.append("options"); accountOptions.append(options); skipBlocks.append(skipBlock)
    }

    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return presentsErrors
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func presentSuccessNotification(_: String, from _: ControllerBackedProtocol?, completion _: (() -> Void)?) { calls.append("success") }
}

final class CovHWalletDetailsPresenterContext {
    let view = CovHWalletDetailsViewSpy()
    let interactor = CovHWalletDetailsInteractorSpy()
    let wireframe = CovHWalletDetailsWireframeSpy()
    let factory = CovHWalletDetailsFactorySpy()
    let wallet: MetaAccountModel
    let presenter: WalletDetailsPresenter

    init(flow: WalletDetailsFlow) {
        wallet = flow.wallet
        presenter = WalletDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )
        presenter.didLoad(ui: view)
    }

    convenience init(wallet: MetaAccountModel = CovHChainAccountFixture.wallet()) {
        self.init(flow: .normal(wallet: wallet))
    }
}
