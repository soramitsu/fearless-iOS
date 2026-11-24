import XCTest
import UIKit
@testable import fearless

final class CovJWalletLayoutsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testWalletOptionsDisplayLocalizedActions() throws {
        let view = WalletOptionViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.titleLabel.text, R.string.localizable.walletOptionsTitle(preferredLanguages: locale.rLanguages))
        let buttons = [view.backupWalletButton, view.walletDetailsButton, view.changeWalletNameButton, view.deleteWalletButton]
        XCTAssertEqual(buttons.map { $0.imageWithTitleView?.title }, [
            R.string.localizable.walletOptionsExport(preferredLanguages: locale.rLanguages),
            R.string.localizable.walletOptionsDetails(preferredLanguages: locale.rLanguages),
            R.string.localizable.backupWalletNameEditingTitle(preferredLanguages: locale.rLanguages),
            R.string.localizable.walletOptionsDelete(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertTrue(buttons.allSatisfy { $0.isDescendant(of: view) && $0.bounds.height > 0 })
        XCTAssertEqual(view.deleteWalletButton.imageWithTitleView?.titleColor, R.color.colorPink())
    }

    func testContactCreationBindsAddressAndControlsValidity() throws {
        let view = CreateContactViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertFalse(view.createButton.isEnabled)
        view.bind(viewModel: CreateContactViewModel(address: "0x1234", chainName: "Ethereum", iconViewModel: nil))
        XCTAssertEqual(view.contactAddressField.textField.text, "0x1234")
        XCTAssertEqual(view.networkView.subtitle, "Ethereum")
        XCTAssertNil(view.networkView.iconView.image)
        XCTAssertEqual(view.contactNameField.textField.placeholder, R.string.localizable.contactsContactName(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.contactAddressField.textField.placeholder, R.string.localizable.contactsContactAddress(preferredLanguages: locale.rLanguages))
        view.updateState(isValid: true)
        XCTAssertTrue(view.createButton.isEnabled)
        view.updateState(isValid: false)
        XCTAssertFalse(view.createButton.isEnabled)
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
    }

    func testContactsEmptyStateHidesTableAndKeepsCreationAvailable() throws {
        let view = ContactsViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.showEmptyView()
        XCTAssertTrue(view.tableView.isHidden)
        XCTAssertFalse(view.emptyView.isHidden)
        XCTAssertTrue(view.createButton.isEnabled)
        XCTAssertEqual(view.createButton.imageWithTitleView?.title, R.string.localizable.contactsCreateContact(preferredLanguages: locale.rLanguages))
        let texts = CovJViewFixture.descendants(UILabel.self, in: view.emptyView).compactMap(\.text)
        XCTAssertTrue(texts.contains(R.string.localizable.nftStubTitle(preferredLanguages: locale.rLanguages)))
        XCTAssertTrue(texts.contains(R.string.localizable.historyEmptyDescription(preferredLanguages: locale.rLanguages)))
        XCTAssertGreaterThanOrEqual(view.tableView.contentInset.bottom, UIConstants.actionHeight)
    }

    func testWalletNameModesUseDifferentGuidanceAndAction() throws {
        let create = WalletNameViewLayout(mode: .create)
        create.locale = locale
        let window = try CovJViewFixture.host(create)
        defer { window.isHidden = true }
        XCTAssertEqual(create.navigationBar.titleLabel.text, R.string.localizable.backupWalletNameCreateTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(create.bottomDescriptionLabel.text, R.string.localizable.backupWalletNameCreateBottomDecription(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(create.continueButton.imageWithTitleView?.title, R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages))
        XCTAssertFalse(create.continueButton.isEnabled)
        XCTAssertNotNil(create.keyboardAdoptableConstraint)
        XCTAssertGreaterThan(create.nameTextField.frame.height, 0)
        let edit = WalletNameViewLayout(mode: .editing(AccountGenerator.generateMetaAccount()))
        edit.locale = locale
        XCTAssertEqual(edit.navigationBar.titleLabel.text, R.string.localizable.backupWalletNameEditingTitle(preferredLanguages: locale.rLanguages))
        XCTAssertNil(edit.bottomDescriptionLabel.text)
        XCTAssertEqual(edit.continueButton.imageWithTitleView?.title, R.string.localizable.commonSave(preferredLanguages: locale.rLanguages))
        XCTAssertFalse(edit.continueButton.isEnabled)
    }

    func testBackupRiskWarningsRequireAllAcknowledgementsInitially() throws {
        let view = BackupRiskWarningsViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        let confirmations = [view.confirm1Button, view.confirm2Button, view.confirm3Button]
        XCTAssertTrue(confirmations.allSatisfy { !$0.isChecked })
        XCTAssertEqual(confirmations.map { $0.title(for: .normal) }, [
            R.string.localizable.backupRisksWarnings1(preferredLanguages: locale.rLanguages),
            R.string.localizable.backupRisksWarnings2(preferredLanguages: locale.rLanguages),
            R.string.localizable.backupRisksWarnings3(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertTrue(confirmations.allSatisfy { $0.titleLabel?.numberOfLines == 0 })
        XCTAssertFalse(view.continueButton.isEnabled)
        XCTAssertEqual(view.continueButton.imageWithTitleView?.title, R.string.localizable.backupRisksWarningsContinueButton(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.continueButton.frame.height, UIConstants.actionHeight, accuracy: 0.5)
    }

    func testWarningSheetBindsBlockingAndDismissibleConfigurations() throws {
        let view = WarningAlertViewLayout()
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        let icon = try XCTUnwrap(UIImage(systemName: "exclamationmark.triangle"))
        view.bind(viewModel: WarningAlertConfig(title: "Update needed", iconImage: icon, text: "Please update", buttonTitle: "Update", blocksUi: true))
        XCTAssertEqual(view.titleLabel.text, "Update needed")
        XCTAssertEqual(view.textLabel.text, "Please update")
        XCTAssertEqual(view.warningIconImageView.image, icon)
        XCTAssertEqual(view.actionButton.imageWithTitleView?.title, "Update")
        XCTAssertTrue(view.closeButton.isHidden)
        view.bind(viewModel: WarningAlertConfig(title: "Notice", iconImage: nil, text: nil, buttonTitle: "Continue", blocksUi: false))
        XCTAssertFalse(view.closeButton.isHidden)
        XCTAssertNil(view.textLabel.text)
        XCTAssertNil(view.warningIconImageView.image)
        XCTAssertEqual(view.actionButton.imageWithTitleView?.title, "Continue")
        XCTAssertEqual(view.textLabel.numberOfLines, 0)
    }

    func testRawDataPreservesMultilinePayloadAndCloseCaption() throws {
        let view = RawDataViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.set(text: "{\n  \"method\": \"transfer\"\n}")
        XCTAssertEqual(view.label.text, "{\n  \"method\": \"transfer\"\n}")
        XCTAssertEqual(view.label.numberOfLines, 0)
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonTransactionRawData(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.closeButton.imageWithTitleView?.title, R.string.localizable.commonClose(preferredLanguages: locale.rLanguages))
        XCTAssertGreaterThanOrEqual(view.contentView.scrollView.contentInset.bottom, UIConstants.actionHeight)
        view.set(text: "")
        XCTAssertEqual(view.label.text, "")
    }

    func testBackupWalletSelectionAndExportCaptions() throws {
        let selection = BackupSelectWalletViewLayout()
        selection.locale = locale
        let window = try CovJViewFixture.host(selection)
        defer { window.isHidden = true }
        XCTAssertEqual(selection.navigationBar.titleLabel.text, R.string.localizable.backupSelectWalletTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(selection.createButton.imageWithTitleView?.title, R.string.localizable.backupSelectWalletCreateButton(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(selection.tableView.separatorStyle, .none)
        XCTAssertGreaterThan(selection.tableView.frame.height, 0)
        let export = BackupWalletViewLayout()
        export.locale = locale
        XCTAssertEqual(export.navigationBar.titleLabel.text, R.string.localizable.exportWallet(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(export.tableView.separatorStyle, .none)
        XCTAssertTrue(export.tableView.isDescendant(of: export))
    }

    func testBannerPaginationHidesEmptyAndSinglePageIndicators() throws {
        let view = BannersViewLayout()
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.setPageControl(pageCount: 0)
        XCTAssertTrue(view.collectionView.isHidden)
        XCTAssertTrue(view.pageControl.isHidden)
        view.setPageControl(pageCount: 1)
        XCTAssertFalse(view.collectionView.isHidden)
        XCTAssertTrue(view.pageControl.isHidden)
        view.setPageControl(pageCount: 3)
        XCTAssertFalse(view.collectionView.isHidden)
        XCTAssertFalse(view.pageControl.isHidden)
        XCTAssertEqual(view.pageControl.numberOfPages, 3)
        XCTAssertFalse(view.pageControl.isUserInteractionEnabled)
        XCTAssertEqual(view.collectionView.decelerationRate, .fast)
    }
}
