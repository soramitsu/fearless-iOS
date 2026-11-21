import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkBackupWalletViewModelFactoryTests: XCTestCase {
    private let locale = CovJBkFixture.locale
    private var languages: [String]? { CovJBkFixture.languages }

    private func makeFactory() -> BackupWalletViewModelFactory {
        BackupWalletViewModelFactory()
    }

    private func formatter(for wallet: MetaAccountModel) -> TokenFormatter {
        AssetBalanceFormatterFactory()
            .createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(wallet.selectedCurrency), usageCase: .detailsCrypto)
            .value(for: locale)
    }

    func testLocalExportOptionsAreListedWithoutGoogleWhenDriveWasNotChecked() {
        let wallet = CovJBkFixture.wallet(name: "Savings")

        let viewModel = makeFactory().createViewModel(
            from: wallet,
            locale: locale,
            balance: nil,
            exportOptions: [.mnemonic, .seed, .keystore],
            backupAccounts: nil
        )

        XCTAssertEqual(viewModel.profileOptionViewModel.map(\.title), [
            R.string.localizable.backupRisksWarningsContinueButton(preferredLanguages: languages),
            R.string.localizable.backupWalletSeed(preferredLanguages: languages),
            R.string.localizable.backupWalletJson(preferredLanguages: languages)
        ])
        XCTAssertTrue(viewModel.profileOptionViewModel.allSatisfy { $0.icon != nil && $0.accessoryTitle == nil })
        XCTAssertTrue(viewModel.profileOptionViewModel.allSatisfy { $0.accessoryImage == nil && $0.option == nil })

        let user = viewModel.profileUserViewModel
        XCTAssertEqual(user.walletName, "Savings")
        XCTAssertEqual(user.fiatBalance, "")
        XCTAssertNil(user.dayChange)
        XCTAssertNil(user.balanceCaption)
        XCTAssertFalse(user.isSelected)

        XCTAssertEqual(viewModel.logoutViewModel.title, R.string.localizable.profileLogoutTitle(preferredLanguages: languages))
        XCTAssertNotNil(viewModel.logoutViewModel.icon)
    }

    func testGoogleBackupIsOfferedWhenDriveHoldsOnlyOtherWallets() {
        let wallet = CovJBkFixture.wallet()

        let viewModel = makeFactory().createViewModel(
            from: wallet,
            locale: locale,
            balance: nil,
            exportOptions: [.keystore],
            backupAccounts: [OpenBackupAccount(name: "Other", address: "5OtherWalletAddress")]
        )

        XCTAssertEqual(viewModel.profileOptionViewModel.map(\.title), [
            R.string.localizable.backupWalletJson(preferredLanguages: languages),
            R.string.localizable.backupWalletBackupGoogle(preferredLanguages: languages)
        ])
        XCTAssertNotNil(viewModel.profileOptionViewModel.last?.icon)
    }

    func testGoogleRemovalIsOfferedWhenDriveHoldsThisWallet() {
        let wallet = CovJBkFixture.wallet()

        let viewModel = makeFactory().createViewModel(
            from: wallet,
            locale: locale,
            balance: nil,
            exportOptions: [],
            backupAccounts: [OpenBackupAccount(name: wallet.name, address: wallet.backupAddress)]
        )

        XCTAssertEqual(
            viewModel.profileOptionViewModel.map(\.title),
            [R.string.localizable.backupWalletDeleteGoogle(preferredLanguages: languages)]
        )
    }

    func testBalanceShowsTheTotalAndARisingDayChangeWithTheHiddenCaption() throws {
        let wallet = CovJBkFixture.wallet()
        let balance = CovJBkFixture.balance(for: wallet, total: 1234.5, dayChangePercent: 0.05, dayChangeValue: -12, hiddenFiat: 3)
        let formatter = formatter(for: wallet)

        let viewModel = makeFactory().createViewModel(
            from: wallet,
            locale: locale,
            balance: balance,
            exportOptions: [.mnemonic],
            backupAccounts: []
        )

        let user = viewModel.profileUserViewModel
        XCTAssertEqual(user.fiatBalance, formatter.stringFromDecimal(1234.5))
        XCTAssertNotEqual(user.fiatBalance, "")
        XCTAssertEqual(user.balanceCaption, balance.allHoldingsCaption)
        XCTAssertNotNil(user.balanceCaption)

        let percent = try XCTUnwrap(Decimal(0.05).percentString(locale: locale))
        let value = "(\(formatter.stringFromDecimal(12) ?? ""))"
        let dayChange = try XCTUnwrap(user.dayChange)
        XCTAssertEqual(dayChange.string, "\(percent) \(value)")
        let percentColor = dayChange.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(percentColor, FWSunlit.Palette.change(0.05))
        XCTAssertNotNil(dayChange.attribute(.foregroundColor, at: percent.count + 1, effectiveRange: nil))
        XCTAssertEqual(viewModel.profileOptionViewModel.count, 2)
    }

    func testFallingAndFlatDayChangesTakeTheirOwnColours() throws {
        let wallet = CovJBkFixture.wallet()
        let factory = makeFactory()

        let falling = factory.createViewModel(
            from: wallet,
            locale: locale,
            balance: CovJBkFixture.balance(for: wallet, total: 10, dayChangePercent: -0.25, dayChangeValue: -2.5),
            exportOptions: [],
            backupAccounts: nil
        )
        let fallingChange = try XCTUnwrap(falling.profileUserViewModel.dayChange)
        XCTAssertTrue(fallingChange.string.hasPrefix(try XCTUnwrap(Decimal(-0.25).percentString(locale: locale))))
        XCTAssertEqual(
            fallingChange.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            FWSunlit.Palette.change(-0.25)
        )
        XCTAssertNil(falling.profileUserViewModel.balanceCaption)

        let flat = factory.createViewModel(
            from: wallet,
            locale: locale,
            balance: CovJBkFixture.balance(for: wallet, total: 0, dayChangePercent: 0, dayChangeValue: 0),
            exportOptions: [],
            backupAccounts: nil
        )
        let flatChange = try XCTUnwrap(flat.profileUserViewModel.dayChange)
        XCTAssertEqual(flatChange.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, FWSunlit.Palette.change(0))
        XCTAssertEqual(flat.profileUserViewModel.fiatBalance, formatter(for: wallet).stringFromDecimal(0))
    }

    func testSeedOnlyExportListsOnlyTheSeedOption() {
        let wallet = CovJBkFixture.wallet()

        let viewModel = makeFactory().createViewModel(
            from: wallet,
            locale: locale,
            balance: nil,
            exportOptions: [.seed],
            backupAccounts: nil
        )

        XCTAssertEqual(
            viewModel.profileOptionViewModel.map(\.title),
            [R.string.localizable.backupWalletSeed(preferredLanguages: languages)]
        )
    }
}
