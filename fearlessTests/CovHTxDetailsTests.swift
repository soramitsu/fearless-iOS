import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// Transaction details: view-model factory, presenter, interactor, view controller, layout bindings, view factory,
/// plus the history module's view factory and wireframe that open it.
final class CovHTxDetailsFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let account = "5CovHAccountAddress"

    private func build(
        _ transaction: AssetTransactionData,
        chain: ChainModel = CovHTxHistoryFixture.chain()
    ) -> WalletTransactionDetailsViewModel? {
        WalletTransactionDetailsViewModelFactory(
            accountAddress: account,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            asset: CovHTxHistoryFixture.main
        ).buildViewModel(transaction: transaction, locale: locale, chain: chain)
    }

    private func fee(_ value: Decimal) -> AssetTransactionFee {
        AssetTransactionFee(identifier: "fee", assetId: CovHTxHistoryFixture.main.id, amount: AmountDecimal(value: value), context: nil)
    }

    func testTransfersPutTheAccountOnTheirSideAndSumTheFee() throws {
        let languages = locale.rLanguages
        let outgoing = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xout", type: TransactionType.outgoing.rawValue, status: .pending, peerName: "receiver", amount: 2, fees: [fee(0.25)]
        )) as? TransferTransactionDetailsViewModel)
        XCTAssertEqual(outgoing.from, account)
        XCTAssertEqual(outgoing.to, "receiver")
        XCTAssertTrue(outgoing.amount?.hasPrefix("-") == true)
        XCTAssertTrue(outgoing.total?.contains("2.25") == true, outgoing.total ?? "")
        XCTAssertTrue(outgoing.fee?.contains("0.25") == true, outgoing.fee ?? "")
        XCTAssertEqual(outgoing.status, R.string.localizable.transactionStatusPending(preferredLanguages: languages))
        XCTAssertEqual(outgoing.extrinsicHash, "0xout")
        XCTAssertNotNil(outgoing.statusIcon)
        XCTAssertNotNil(outgoing.dateString)

        let incoming = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xin", type: TransactionType.incoming.rawValue, peerName: "sender"
        )) as? TransferTransactionDetailsViewModel)
        XCTAssertEqual(incoming.from, "sender")
        XCTAssertEqual(incoming.to, account)
        XCTAssertTrue(incoming.amount?.hasPrefix("+") == true)
        XCTAssertEqual(incoming.status, R.string.localizable.transactionStatusCompleted(preferredLanguages: languages))

        let withoutUtility = ChainModel(
            rank: nil, disabled: false, chainId: "cov-h-no-utility", paraId: nil, name: "No utility",
            assets: [CovHTxHistoryFixture.other], xcm: nil, nodes: [], addressPrefix: 42, icon: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
        let noFee = try XCTUnwrap(build(
            CovHTxHistoryFixture.transaction("0xnofee", type: TransactionType.outgoing.rawValue, fees: [fee(1)]),
            chain: withoutUtility
        ) as? TransferTransactionDetailsViewModel)
        XCTAssertNil(noFee.fee, "Without a utility asset there is no fee formatter")

        let swap = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xswap", type: TransactionType.swap.rawValue, peerName: "pool", fees: [fee(1)]
        )) as? TransferTransactionDetailsViewModel)
        XCTAssertEqual(swap.from, "pool")
        XCTAssertEqual(swap.to, "pool")
        XCTAssertFalse(swap.amount?.hasPrefix("-") == true)
        XCTAssertNotNil(swap.fee)
    }

    func testStakingAndExtrinsicRowsKeepTheirOwnFields() throws {
        let languages = locale.rLanguages
        let reward = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xreward", type: TransactionType.reward.rawValue, status: .rejected, firstName: "validator", details: "1234", amount: 3
        )) as? RewardTransactionDetailsViewModel)
        XCTAssertEqual(reward.era, "1234")
        XCTAssertEqual(reward.validator, "validator")
        XCTAssertTrue(reward.reward?.contains("3") == true)
        XCTAssertEqual(reward.status, R.string.localizable.transactionStatusFailed(preferredLanguages: languages))

        let slash = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xslash", type: TransactionType.slash.rawValue, firstName: "offender", details: "77", amount: 4
        )) as? SlashTransactionDetailsViewModel)
        XCTAssertEqual(slash.era, "77")
        XCTAssertEqual(slash.validator, "offender")
        XCTAssertTrue(slash.slash?.contains("4") == true)

        let extrinsic = try XCTUnwrap(build(CovHTxHistoryFixture.transaction(
            "0xext", type: TransactionType.extrinsic.rawValue, peerId: "signer", firstName: "balances", lastName: "transfer", fees: [fee(0.5)]
        )) as? ExtrinsicTransactionDetailsViewModel)
        XCTAssertEqual(extrinsic.module, "balances")
        XCTAssertEqual(extrinsic.call, "transfer")
        XCTAssertEqual(extrinsic.sender, "signer")
        XCTAssertTrue(extrinsic.fee?.contains("0.5") == true, extrinsic.fee ?? "")

        XCTAssertNil(build(CovHTxHistoryFixture.transaction("0xunused", type: TransactionType.unused.rawValue)))
        XCTAssertNil(build(CovHTxHistoryFixture.transaction("0xbad", type: "Teleport")))
    }
}

final class CovHTxDetailsPresenterTests: XCTestCase {
    private func makePresenter(load: Bool = true) -> (WalletTransactionDetailsPresenter, CovHTxDetailsViewSpy, CovHTxDetailsWireframeSpy, CovHTxDetailsInteractorSpy) {
        let view = CovHTxDetailsViewSpy()
        let wireframe = CovHTxDetailsWireframeSpy()
        let interactor = CovHTxDetailsInteractorSpy()
        let presenter = WalletTransactionDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletTransactionDetailsViewModelFactory(
                accountAddress: "5CovHAccountAddress",
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
                asset: CovHTxHistoryFixture.main
            ),
            localizationManager: LocalizationManager.shared,
            chain: CovHTxHistoryFixture.chain()
        )
        if load {
            presenter.view = view
        }
        return (presenter, view, wireframe, interactor)
    }

    func testTapsOpenTheRightAccountAndHashOptions() {
        let (presenter, view, wireframe, interactor) = makePresenter()
        presenter.setup()
        XCTAssertEqual(interactor.setups, 1)

        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction("0xout", type: TransactionType.outgoing.rawValue, peerName: "receiver"))
        guard case .loaded? = view.states.last else { return XCTFail("Expected loaded details") }
        presenter.didTapSenderView()
        presenter.didTapReceiverOrValidatorView()
        XCTAssertEqual(view.presented.count, 2)
        XCTAssertTrue(view.presented.allSatisfy { $0 is UIAlertController })
        presenter.didTapExtrinsicView()
        XCTAssertEqual(wireframe.hashes, ["0xout"])

        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction(
            "0xext", type: TransactionType.extrinsic.rawValue, peerId: "signer", firstName: "balances", lastName: "transfer"
        ))
        presenter.didTapSenderView()
        presenter.didTapReceiverOrValidatorView()
        XCTAssertEqual(view.presented.count, 3, "An extrinsic has a sender but no receiver")

        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction("0xreward", type: TransactionType.reward.rawValue, firstName: "validator"))
        presenter.didTapReceiverOrValidatorView()
        presenter.didTapSenderView()
        XCTAssertEqual(view.presented.count, 4, "A reward names its validator only")

        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction("0xslash", type: TransactionType.slash.rawValue, firstName: "offender"))
        presenter.didTapReceiverOrValidatorView()
        XCTAssertEqual(view.presented.count, 5)

        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction("0xbad", type: "Teleport"))
        guard case .empty? = view.states.last else { return XCTFail("An unknown type shows no details") }
        presenter.didTapExtrinsicView()
        presenter.didTapSenderView()
        XCTAssertEqual(wireframe.hashes, ["0xout"], "Without details there is no hash to offer")
        XCTAssertEqual(view.presented.count, 5)

        presenter.didTapCloseButton()
        XCTAssertEqual(wireframe.closes, 1)
        presenter.applyLocalization()
    }

    func testWithoutAViewNothingIsPresented() {
        let (presenter, view, wireframe, _) = makePresenter(load: false)
        presenter.didReceiveTransaction(CovHTxHistoryFixture.transaction("0xout", type: TransactionType.outgoing.rawValue))
        presenter.didTapSenderView()
        presenter.didTapReceiverOrValidatorView()
        XCTAssertTrue(view.presented.isEmpty)
        XCTAssertTrue(view.states.isEmpty)
        presenter.didTapExtrinsicView()
        XCTAssertEqual(wireframe.hashes, ["0xout"])
    }

    func testInteractorDeliversItsTransaction() {
        let transaction = CovHTxHistoryFixture.transaction("0xdeliver", type: TransactionType.incoming.rawValue)
        let interactor = WalletTransactionDetailsInteractor(transaction: transaction)
        let output = CovHTxDetailsOutputSpy()
        interactor.presenter = output
        interactor.setup()
        XCTAssertEqual(output.transactions, [transaction])
    }
}

final class CovHTxDetailsViewTests: XCTestCase {
    private func viewModel(_ transaction: AssetTransactionData) throws -> WalletTransactionDetailsViewModel {
        try XCTUnwrap(WalletTransactionDetailsViewModelFactory(
            accountAddress: "5CovHAccountAddress",
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            asset: CovHTxHistoryFixture.main
        ).buildViewModel(transaction: transaction, locale: Locale(identifier: "en_US"), chain: CovHTxHistoryFixture.chain()))
    }

    func testControllerForwardsTapsAndShowsStates() throws {
        let presenter = CovHTxDetailsPresenterSpy()
        let controller = WalletTransactionDetailsViewController(presenter: presenter)
        controller.loadViewIfNeeded()
        let layout = controller.rootView
        XCTAssertEqual(presenter.events, ["setup"])
        XCTAssertFalse(layout.navigationTitleLabel.text?.isEmpty ?? true)

        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        layout.senderView.sendActions(for: .touchUpInside)
        layout.receiverView.sendActions(for: .touchUpInside)
        layout.extrinsicHashView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.events, ["setup", "close", "sender", "receiver", "extrinsic"])

        controller.didReceiveState(.loading)
        XCTAssertTrue(layout.contentView.isHidden)
        controller.didReceiveState(.loaded(viewModel: try viewModel(CovHTxHistoryFixture.transaction(
            "0xshown", type: TransactionType.outgoing.rawValue, peerName: "receiver"
        ))))
        XCTAssertFalse(layout.contentView.isHidden)
        XCTAssertEqual(layout.extrinsicHashView.subtitleLabel?.text, "0xshown")
        XCTAssertEqual(layout.receiverView.subtitleLabel?.text, "receiver")
        controller.didReceiveState(.empty)
        XCTAssertTrue(layout.contentView.isHidden)
        controller.applyLocalization()
    }

    func testLayoutShowsOnlyTheRowsOfEachStakingAndExtrinsicKind() throws {
        let reward = WalletTransactionDetailsViewLayout()
        reward.bind(to: try viewModel(CovHTxHistoryFixture.transaction(
            "0xreward", type: TransactionType.reward.rawValue, firstName: "validator", details: "12", amount: 3
        )))
        XCTAssertTrue(reward.amountView.isHidden)
        XCTAssertTrue(reward.senderView.isHidden)
        XCTAssertFalse(reward.receiverView.isHidden)
        XCTAssertEqual(reward.eraView.valueLabel.text, "12")
        XCTAssertEqual(reward.receiverView.subtitleLabel?.text, "validator")
        XCTAssertTrue(reward.rewardView.valueLabel.text?.contains("3") == true)

        let slash = WalletTransactionDetailsViewLayout()
        slash.bind(to: try viewModel(CovHTxHistoryFixture.transaction(
            "0xslash", type: TransactionType.slash.rawValue, firstName: "", details: "13", amount: 4
        )))
        XCTAssertTrue(slash.rewardView.isHidden)
        XCTAssertTrue(slash.receiverView.isHidden, "An empty validator is not shown")
        XCTAssertEqual(slash.eraView.valueLabel.text, "13")
        XCTAssertTrue(slash.slashView.valueLabel.text?.contains("4") == true)

        let extrinsic = WalletTransactionDetailsViewLayout()
        extrinsic.bind(to: try viewModel(CovHTxHistoryFixture.transaction(
            "0xext", type: TransactionType.extrinsic.rawValue, peerId: "signer", firstName: "staking", lastName: "bond"
        )))
        XCTAssertTrue(extrinsic.eraView.isHidden)
        XCTAssertTrue(extrinsic.receiverView.isHidden)
        XCTAssertFalse(extrinsic.senderView.isHidden)
        XCTAssertEqual(extrinsic.moduleView.valueLabel.text, "staking")
        XCTAssertEqual(extrinsic.callView.valueLabel.text, "bond")
        XCTAssertEqual(extrinsic.senderView.subtitleLabel?.text, "signer")

        let swap = WalletTransactionDetailsViewLayout()
        swap.bind(to: try viewModel(CovHTxHistoryFixture.transaction("0xswap", type: TransactionType.swap.rawValue)))
        XCTAssertEqual(swap.extrinsicHashView.subtitleLabel?.text, "0xswap")
    }

    func testFactoriesAndWireframesOpenTheScreens() throws {
        let chain = CovHTxHistoryFixture.chain()
        let wallet = AccountGenerator.generateMetaAccount()
        let transaction = CovHTxHistoryFixture.transaction("0xopen", type: TransactionType.outgoing.rawValue)
        XCTAssertTrue(
            WalletTransactionDetailsViewFactory.createView(
                transaction: transaction, asset: CovHTxHistoryFixture.main, chain: chain, selectedAccount: wallet
            ) is WalletTransactionDetailsViewController
        )
        let ethereumOnly = MetaAccountModel(
            metaId: "cov-h-eth", name: "Eth", substrateAccountId: nil, substrateCryptoType: 0, substratePublicKey: nil,
            ethereumAddress: Data(repeating: 1, count: 20), ethereumPublicKey: Data(repeating: 1, count: 33), chainAccounts: [],
            assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil, selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true, favouriteChainIds: []
        )
        XCTAssertNil(WalletTransactionDetailsViewFactory.createView(
            transaction: transaction, asset: CovHTxHistoryFixture.main, chain: chain, selectedAccount: ethereumOnly
        ))

        let host = CovHTxDetailsViewSpy()
        let wireframe = WalletTransactionHistoryWireframe()
        wireframe.showTransactionDetails(
            from: host, transaction: transaction, chain: chain, asset: CovHTxHistoryFixture.main, selectedAccount: wallet
        )
        XCTAssertTrue(host.presented.last is WalletTransactionDetailsViewController)
        wireframe.showTransactionDetails(
            from: host, transaction: transaction, chain: chain, asset: CovHTxHistoryFixture.main, selectedAccount: ethereumOnly
        )
        XCTAssertEqual(host.presented.count, 1)
        wireframe.showHistoryExplorer(url: try XCTUnwrap(URL(string: "https://explorer.invalid/address/x")), from: host)
        XCTAssertEqual(host.presented.count, 2)
        XCTAssertEqual(host.presented.last?.modalPresentationStyle, .overFullScreen)

        WalletTransactionDetailsWireframe().close(view: host)
        XCTAssertEqual(host.dismissals, 1)

        let module = try XCTUnwrap(WalletTransactionHistoryViewFactory.createView(
            asset: CovHTxHistoryFixture.main, chain: CovHTxHistoryFixture.chain(history: nil), selectedAccount: wallet
        ))
        XCTAssertTrue(module.view is WalletTransactionHistoryViewController)
        XCTAssertTrue(module.moduleInput is WalletTransactionHistoryPresenter)
    }
}

final class CovHTxDetailsViewSpy: UIViewController, WalletTransactionDetailsViewProtocol {
    private(set) var states: [WalletTransactionDetailsViewState] = []
    private(set) var presented: [UIViewController] = []
    private(set) var dismissals = 0

    func didReceiveState(_ state: WalletTransactionDetailsViewState) { states.append(state) }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1
        completion?()
    }
}

final class CovHTxDetailsWireframeSpy: WalletTransactionDetailsWireframeProtocol {
    private(set) var closes = 0
    private(set) var hashes: [String] = []

    func close(view _: ControllerBackedProtocol?) { closes += 1 }

    func presentOptions(with extrinsicHash: String, locale _: Locale, chain _: ChainModel, from _: ControllerBackedProtocol?) {
        hashes.append(extrinsicHash)
    }
}

final class CovHTxDetailsInteractorSpy: WalletTransactionDetailsInteractorInputProtocol {
    private(set) var setups = 0

    func setup() { setups += 1 }
}

final class CovHTxDetailsOutputSpy: WalletTransactionDetailsInteractorOutputProtocol {
    private(set) var transactions: [AssetTransactionData] = []

    func didReceiveTransaction(_ transaction: AssetTransactionData) { transactions.append(transaction) }
}

final class CovHTxDetailsPresenterSpy: WalletTransactionDetailsPresenterProtocol {
    private(set) var events: [String] = []

    func setup() { events.append("setup") }
    func didTapCloseButton() { events.append("close") }
    func didTapReceiverOrValidatorView() { events.append("receiver") }
    func didTapSenderView() { events.append("sender") }
    func didTapExtrinsicView() { events.append("extrinsic") }
}
