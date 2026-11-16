import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkBackupWalletOutput: BackupWalletViewOutput {
    private(set) var loads = 0
    private(set) var backs = 0
    private(set) var appears = 0
    private(set) var selected: [IndexPath] = []

    func didLoad(view _: BackupWalletViewInput) { loads += 1 }
    func backButtonDidTapped() { backs += 1 }
    func didSelectRowAt(_ indexPath: IndexPath) { selected.append(indexPath) }
    func viewDidAppear() { appears += 1 }
}

final class CovJBkBalanceAdapter: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var subscriptions: [(wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener)] = []

    func subscribeWalletBalance(wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener) {
        subscriptions.append((wallet, listener))
    }

    func subscribeWalletsBalances(listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetBalance(wallet _: MetaAccountModel, chainAsset _: ChainAsset, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetsBalance(chainAssets _: [ChainAsset], wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

final class CovJBkExportOptionsProvider: AvailableExportOptionsProviderProtocol {
    var options: [ExportOption] = [.mnemonic, .keystore]
    private(set) var requests: [(metaId: String, accountId: AccountId?)] = []

    func getAvailableExportOptions(for account: MetaAccountModel, accountId: AccountId?, isEthereum _: Bool) -> [ExportOption] {
        requests.append((account.metaId, accountId))
        return options
    }

    func getAvailableExportOptions(for wallet: MetaAccountModel, accountId: AccountId?) -> [ExportOption] {
        requests.append((wallet.metaId, accountId))
        return options
    }
}

final class CovJBkBackupWalletInteractorOutput: BackupWalletInteractorOutput {
    private(set) var balances: [WalletBalancesResult] = []
    private(set) var chains: [[ChainModel]] = []
    private(set) var options: [[ExportOption]] = []
    private(set) var errors: [Error] = []
    private(set) var backupResults: [Result<[OpenBackupAccount], Error>] = []
    private(set) var removals: [Result<Void, Error>] = []

    func didReceiveBalances(result: WalletBalancesResult) { balances.append(result) }
    func didReceive(chains: [ChainModel]) { self.chains.append(chains) }
    func didReceive(options: [ExportOption]) { self.options.append(options) }
    func didReceive(error: Error) { errors.append(error) }
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>) { backupResults.append(result) }
    func didReceiveRemove(result: Result<Void, Error>) { removals.append(result) }
}

final class CovJBkBackupWalletControllerTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private func makeController(_ output: CovJBkBackupWalletOutput) throws -> BackupWalletViewController {
        BackupWalletViewController(output: output, localizationManager: try CovJBkFixture.localization())
    }

    func testLoadedScreenShowsTheWalletItsOptionsAndTheFooter() throws {
        let output = CovJBkBackupWalletOutput()
        let controller = try makeController(output)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.rootView.tableView

        XCTAssertEqual(output.loads, 1)
        XCTAssertTrue(table.dataSource === controller)
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 0)

        controller.didReceive(viewModel: CovJBkFixture.profileViewModel(name: "Main", options: ["Phrase", "Seed"]))
        table.layoutIfNeeded()

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 2)
        let walletCell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? WalletsManagmentTableCell)
        let texts = CovJViewFixture.descendants(UILabel.self, in: walletCell).compactMap(\.text)
        XCTAssertTrue(texts.contains("Main"))
        XCTAssertTrue(texts.contains("$1.00"))
        let optionCell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 1)) as? ProfileTableViewCell)
        XCTAssertEqual(optionCell.viewModel?.title, "Seed")

        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 86)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 1)), 48)
        XCTAssertNil(controller.tableView(table, viewForFooterInSection: 0))
        XCTAssertEqual(controller.tableView(table, heightForFooterInSection: 0), 0)
        XCTAssertEqual(controller.tableView(table, heightForFooterInSection: 1), UITableView.automaticDimension)
        let footer = try XCTUnwrap(controller.tableView(table, viewForFooterInSection: 1))
        let footerTexts = CovJViewFixture.descendants(UILabel.self, in: footer).compactMap(\.text)
        XCTAssertEqual(footerTexts, [R.string.localizable.backupWalletFooterViewText(preferredLanguages: languages)])
    }

    func testRowsBackButtonAndAppearanceAreForwarded() throws {
        let output = CovJBkBackupWalletOutput()
        let controller = try makeController(output)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.rootView.tableView
        controller.didReceive(viewModel: CovJBkFixture.profileViewModel(options: ["Phrase"]))

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        let appearances = output.appears
        controller.viewDidAppear(false)

        XCTAssertEqual(output.selected, [IndexPath(row: 0, section: 1)])
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.appears, appearances + 1)
    }

    func testLocalizationTitlesTheScreenAndLoadingCoversIt() throws {
        let controller = try makeController(CovJBkBackupWalletOutput())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        controller.applyLocalization()
        controller.didStartLoading()

        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.exportWallet(preferredLanguages: languages)
        )
        XCTAssertTrue(controller.view.subviews.contains {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        })
        XCTAssertFalse(controller.view.isUserInteractionEnabled)
        controller.didStopLoading()
    }
}

final class CovJBkBackupWalletInteractorTests: XCTestCase {
    private struct Parts {
        let interactor: BackupWalletInteractor
        let output: CovJBkBackupWalletInteractorOutput
        let adapter: CovJBkBalanceAdapter
        let provider: CovJBkExportOptionsProvider
        let repository: CovJMemoryRepository<ChainModel>
    }

    private func makeParts(wallet: MetaAccountModel, chains: [ChainModel] = []) -> Parts {
        let adapter = CovJBkBalanceAdapter()
        let provider = CovJBkExportOptionsProvider()
        let repository = CovJMemoryRepository<ChainModel>(chains)
        let interactor = BackupWalletInteractor(
            wallet: wallet,
            walletBalanceSubscriptionAdapter: adapter,
            availableExportOptionsProvider: provider,
            chainRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManager()
        )
        return Parts(
            interactor: interactor,
            output: CovJBkBackupWalletInteractorOutput(),
            adapter: adapter,
            provider: provider,
            repository: repository
        )
    }

    func testSetupSendsOptionsSubscribesToTheBalanceAndLoadsChains() throws {
        let wallet = CovJBkFixture.wallet()
        let chain = CovJFixture.chain(id: "covjbk-setup", name: "Setup")
        let parts = makeParts(wallet: wallet, chains: [chain])

        parts.interactor.setup(with: parts.output)

        XCTAssertEqual(parts.output.options, [[.mnemonic, .keystore]])
        XCTAssertEqual(parts.provider.requests.map(\.metaId), [wallet.metaId])
        XCTAssertNil(parts.provider.requests.first?.accountId)
        let subscription = try XCTUnwrap(parts.adapter.subscriptions.first)
        XCTAssertEqual(subscription.wallet.metaId, wallet.metaId)
        XCTAssertTrue(subscription.listener === parts.interactor)
        guard case let .wallet(listened) = parts.interactor.type else {
            return XCTFail("The interactor listens to its own wallet")
        }
        XCTAssertEqual(listened.metaId, wallet.metaId)
        XCTAssertTrue(CovJWait.until { parts.output.chains.count == 1 })
        XCTAssertEqual(parts.output.chains.first?.map(\.chainId), [chain.chainId])
        XCTAssertTrue(parts.output.errors.isEmpty)
    }

    func testChainStorageFailureIsReported() {
        let parts = makeParts(wallet: CovJBkFixture.wallet())
        parts.repository.failure = CovJError("storage")

        parts.interactor.setup(with: parts.output)

        XCTAssertTrue(CovJWait.until { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? CovJError, CovJError("storage"))
        XCTAssertTrue(parts.output.chains.isEmpty)
    }

    func testBalanceUpdatesArePassedOn() {
        let wallet = CovJBkFixture.wallet()
        let parts = makeParts(wallet: wallet)
        parts.interactor.setup(with: parts.output)

        parts.interactor.handle(result: .success([wallet.metaId: CovJBkFixture.balance(for: wallet, total: 5)]))
        parts.interactor.handle(result: .failure(CovJError("balance")))

        XCTAssertEqual(parts.output.balances.count, 2)
        if case let .success(infos) = parts.output.balances.first {
            XCTAssertEqual(infos[wallet.metaId]?.totalFiatValue, 5)
        } else {
            XCTFail("The first balance succeeded")
        }
    }

    func testDriveBackupsArriveWhenTheScreenAppears() throws {
        let parts = makeParts(wallet: CovJBkFixture.wallet())
        let cloud = CovJBkCloudStorage()
        cloud.accountsResult = .success([OpenBackupAccount(name: "One", address: "5CovJBkOne")])
        parts.interactor.cloudStorage = cloud
        parts.interactor.setup(with: parts.output)

        parts.interactor.viewDidAppear()

        XCTAssertTrue(CovJWait.until { parts.output.backupResults.count == 1 })
        let accounts = try XCTUnwrap(parts.output.backupResults.first).get()
        XCTAssertEqual(accounts.map(\.address), ["5CovJBkOne"])
        XCTAssertEqual(cloud.calls, ["list"])
    }

    func testDriveFailureDisconnectsAndIsReported() {
        let parts = makeParts(wallet: CovJBkFixture.wallet())
        let cloud = CovJBkCloudStorage()
        cloud.accountsResult = .failure(CloudStorageServiceError.notAuthorized)
        parts.interactor.cloudStorage = cloud
        parts.interactor.setup(with: parts.output)

        parts.interactor.viewDidAppear()

        XCTAssertTrue(CovJWait.until { parts.output.backupResults.count == 1 })
        if case let .failure(error) = parts.output.backupResults.first {
            XCTAssertEqual(error as? CloudStorageServiceError, .notAuthorized)
        } else {
            XCTFail("Listing failed")
        }
        XCTAssertEqual(Array(cloud.calls.prefix(2)), ["list", "disconnect"])
    }

    func testWithoutCloudStorageNothingIsListed() {
        let parts = makeParts(wallet: CovJBkFixture.wallet())
        parts.interactor.setup(with: parts.output)

        parts.interactor.viewDidAppear()
        CovJWait.drain(0.2)

        XCTAssertTrue(parts.output.backupResults.isEmpty)
    }

    func testRemovingTheBackupDeletesTheWalletsAddress() {
        let wallet = CovJBkFixture.wallet()
        let parts = makeParts(wallet: wallet)
        let cloud = CovJBkCloudStorage()
        parts.interactor.cloudStorage = cloud
        parts.interactor.setup(with: parts.output)

        parts.interactor.removeBackupFromGoogle()

        XCTAssertTrue(CovJWait.until { parts.output.removals.count == 1 })
        if case .failure = parts.output.removals.first {
            XCTFail("Removal succeeded")
        }
        XCTAssertEqual(cloud.calls, ["delete:\(wallet.backupAddress)"])

        cloud.deleteError = FearlessExtensionError.cantRemoveExtensionBackup
        parts.interactor.removeBackupFromGoogle()

        XCTAssertTrue(CovJWait.until { parts.output.removals.count == 2 })
        if case let .failure(error) = parts.output.removals.last {
            XCTAssertEqual(error as? FearlessExtensionError, .cantRemoveExtensionBackup)
        } else {
            XCTFail("Removal failed")
        }
    }

    func testReleasingTheInteractorDisconnectsDrive() {
        let cloud = CovJBkCloudStorage()
        autoreleasepool {
            let parts = makeParts(wallet: CovJBkFixture.wallet())
            parts.interactor.cloudStorage = cloud
        }

        XCTAssertEqual(cloud.calls, ["disconnect"])
    }
}
