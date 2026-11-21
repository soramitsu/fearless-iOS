import XCTest
import UIKit
import SSFModels
@testable import fearless

final class CovJFinancialLayoutsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testStatisticsBindsValuesAndRating() throws {
        let view = AccountStatisticsViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.bind(viewModel: AccountStatisticsViewModel(
            rating: 4.2, scoreLabelText: "84", rate: .high, addressViewText: "alice",
            updatedLabelText: "Today", nativeBalanceUsdLabelText: "$10", holdTokensUsdLabelText: "$20",
            walletAgeLabelText: "2 years", totalTransactionsLabelText: "42", rejectedTransactionsLabelText: "1",
            avgTransactionTimeLabelText: "3 sec", maxTransactionTimeLabelText: "8 sec", minTransactionTimeLabelText: "1 sec"
        ))
        XCTAssertEqual(view.scoreLabel.text, "84")
        XCTAssertEqual(view.ratingView.rating, 4.2)
        XCTAssertEqual(view.ratingView.settings.filledColor, AccountScoreRate.high.color)
        XCTAssertEqual(view.addressView.accessibilityValue, "alice")
        let rows = [view.updatedView, view.nativeBalanceUsdView, view.holdTokensUsdView, view.walletAgeView,
                    view.totalTransactionsView, view.rejectedTransactionsView, view.avgTransactionTimeView,
                    view.maxTransactionTimeView, view.minTransactionTimeView]
        XCTAssertEqual(rows.map { $0.valueLabel.text }, ["Today", "$10", "$20", "2 years", "42", "1", "3 sec", "8 sec", "1 sec"])
        XCTAssertTrue(rows.allSatisfy { !$0.isHidden && $0.borderView.isHidden })
        XCTAssertEqual(view.stackView.arrangedSubviews.count, 9)
        XCTAssertEqual(view.closeButton.frame.height, 48, accuracy: 0.5)
        XCTAssertEqual(view.topBar.titleLabel.text, R.string.localizable.accountStatsTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.closeButton.imageWithTitleView?.title, R.string.localizable.commonClose(preferredLanguages: locale.rLanguages))
    }

    func testStatisticsLoadingMissingAndEmptyStates() {
        let view = AccountStatisticsViewLayout()
        view.bind(viewModel: nil)
        XCTAssertFalse(view.updatedView.isHidden)
        XCTAssertNil(view.scoreLabel.text)
        view.bind(viewModel: AccountStatisticsViewModel(
            rating: nil, scoreLabelText: nil, rate: .low, addressViewText: nil,
            updatedLabelText: nil, nativeBalanceUsdLabelText: nil, holdTokensUsdLabelText: nil,
            walletAgeLabelText: nil, totalTransactionsLabelText: nil, rejectedTransactionsLabelText: nil,
            avgTransactionTimeLabelText: nil, maxTransactionTimeLabelText: nil, minTransactionTimeLabelText: nil
        ))
        XCTAssertTrue(view.stackView.arrangedSubviews.allSatisfy(\.isHidden))
        XCTAssertEqual(view.ratingView.rating, 5)
        view.setupEmptyState()
        XCTAssertTrue(view.stackView.isHidden)
        XCTAssertTrue(view.addressView.isHidden)
        XCTAssertEqual(view.ratingView.rating, 0)
        XCTAssertEqual(view.ratingView.settings.emptyBorderColor, R.color.colorLightGray())
    }

    func testBalanceLocksSectionsAndLocalizedRowTitles() throws {
        let view = BalanceLocksDetailViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.stakingStackView.arrangedSubviews.count, 4)
        XCTAssertEqual(view.poolsStackView.arrangedSubviews.count, 5)
        XCTAssertEqual(view.contentView.stackView.arrangedSubviews.count, 8)
        XCTAssertTrue(view.liquidityPoolsView.isHidden)
        XCTAssertFalse(view.governanceView.isHidden)
        XCTAssertEqual(view.stakingStakedRowView.titleLabel.text, R.string.localizable.stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.poolsStakedRowView.titleLabel.text, view.stakingStakedRowView.titleLabel.text)
        XCTAssertEqual(view.poolsUnstakingRowView.titleLabel.text, view.stakingUnstakingRowView.titleLabel.text)
        XCTAssertEqual(view.poolsRedeemableRowView.titleLabel.text, view.stakingRedeemableRowView.titleLabel.text)
        XCTAssertEqual(view.totalView.titleLabel.text, R.string.localizable.commonTotal(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.balanceLocksScreenTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.frozenView.frame.height, 56, accuracy: 0.5)
        XCTAssertEqual(view.totalView.frame.height, 56, accuracy: 0.5)
        XCTAssertEqual(view.stakingStakedRowView.valueBottom.lineBreakMode, .byTruncatingMiddle)
        XCTAssertTrue(view.stakingStakedRowView.borderView.isHidden)
    }

    func testSwapDetailsBindAndExplorerVisibility() throws {
        let view = SwapTransactionDetailViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.bind(viewModel: SwapTransactionViewModel(
            doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel(
                leftViewModel: nil,
                rightViewModel: nil,
                leftShadowColor: nil,
                rightShadowColor: nil
            ),
            amountsText: NSAttributedString(string: "1 XOR → 2 VAL"), status: NSAttributedString(string: "Success"),
            walletName: "Savings", address: "0x123", date: "16 Nov", networkFee: BalanceViewModel(amount: "0.1 XOR", price: "$0.01"), txHash: "0xabcdef"
        ))
        XCTAssertEqual(view.amountsLabel.attributedText?.string, "1 XOR → 2 VAL")
        XCTAssertEqual(view.statusView.valueTop.attributedText?.string, "Success")
        XCTAssertEqual(view.fromView.valueTop.text, "Savings")
        XCTAssertEqual(view.fromView.valueBottom.text, "0x123")
        XCTAssertEqual(view.dateView.valueTop.text, "16 Nov")
        XCTAssertEqual(view.networkFeeView.valueTop.text, "0.1 XOR")
        XCTAssertEqual(view.networkFeeView.valueBottom.text, "$0.01")
        let hash = try XCTUnwrap(view.infoViewsStackView.arrangedSubviews.first as? TitleValueView)
        XCTAssertTrue(hash.valueLabel.attributedText?.string.hasPrefix("0xabcdef  ") == true)
        XCTAssertTrue(hash.valueLabel.isUserInteractionEnabled)
        XCTAssertEqual(hash.valueLabel.gestureRecognizers?.count, 1)
        var copies = 0
        view.copyOnTap = { copies += 1 }
        view.perform(NSSelectorFromString("handleHashCopyTapped"))
        XCTAssertEqual(copies, 1)
        view.updateState(for: nil)
        XCTAssertTrue(view.shareButton.isHidden)
        XCTAssertTrue(view.subscanButton.isHidden)
        view.updateState(for: ChainModel.ExternalApiExplorer(type: .subscan, types: [], url: "https://explorer.invalid"))
        XCTAssertFalse(view.shareButton.isHidden)
        XCTAssertFalse(view.subscanButton.isHidden)
        XCTAssertEqual(view.infoViewsStackView.arrangedSubviews.count, 5)
    }

    func testCrowdloanRewardsHintCanBeBoundAndCleared() throws {
        let view = ClaimCrowdloanRewardsViewLayout()
        view.locale = Locale(identifier: "de_DE")
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        let icon = try XCTUnwrap(UIImage(systemName: "info.circle"))
        view.bind(hintViewModel: DetailsTriangularedAttributedViewModel(icon: icon, title: NSAttributedString(string: "Unlock in 7 days")))
        XCTAssertEqual(view.hintView.detailsLabel.attributedText?.string, "Unlock in 7 days")
        XCTAssertEqual(view.hintView.imageView.image, icon)
        XCTAssertEqual(view.infoStackView.arrangedSubviews.count, 3)
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.lockedRewardsView.titleLabel.text, R.string.localizable.vestingLockedTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.feeView.frame.height, UIConstants.cellHeight, accuracy: 0.5)
        view.bind(hintViewModel: nil)
        XCTAssertNil(view.hintView.detailsLabel.attributedText)
        XCTAssertNil(view.hintView.imageView.image)
    }
}

final class CovJBackupLayoutsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testCreatePasswordInitialStateAndValidationMessages() throws {
        let view = BackupCreatePasswordViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertTrue(view.passwordTextField.animatedInputField.textField.isSecureTextEntry)
        XCTAssertTrue(view.confirmPasswordTextField.animatedInputField.textField.isSecureTextEntry)
        XCTAssertFalse(view.continueButton.isEnabled)
        XCTAssertFalse(view.confirmButton.isChecked)
        XCTAssertFalse(view.passwordTextField.rightButton.isHidden)
        XCTAssertEqual(view.contentView.stackView.arrangedSubviews.count, 5)
        XCTAssertEqual(view.continueButton.frame.height, UIConstants.actionHeight, accuracy: 0.5)
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
        view.setPassword(isMatched: true)
        XCTAssertEqual(view.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordMatched(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.passwordMatchLabel.textColor, R.color.colorStrokeGray())
        view.setPassword(isMatched: false)
        XCTAssertEqual(view.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordNotMatched(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.passwordMatchLabel.textColor, R.color.colorRed())
        view.setPasswordTooShort()
        XCTAssertEqual(view.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordTooShort(
            "\(NSPredicate.backupPasswordMinimumLength)", preferredLanguages: locale.rLanguages
        ))
        XCTAssertEqual(view.passwordMatchLabel.textColor, R.color.colorStrokeGray())
    }

    func testRestorePasswordDisplaysWalletWithSecureEntry() throws {
        let view = BackupPasswordViewLayout()
        view.locale = locale
        view.bind(walletName: "Restored wallet")
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.walletNameLabel.text, "Restored wallet")
        XCTAssertTrue(view.passwordTextField.animatedInputField.textField.isSecureTextEntry)
        XCTAssertFalse(view.continueButton.isEnabled)
        XCTAssertFalse(view.passwordTextField.rightButton.isHidden)
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.backupPasswordTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.passwordTextField.frame.height, 64, accuracy: 0.5)
        XCTAssertEqual(view.triangularedView.frame.height, 72, accuracy: 0.5)
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
    }

    func testImportedWalletDisplaysSuccessAndBothActions() throws {
        let view = BackupWalletImportedViewLayout()
        view.locale = locale
        view.bind(walletName: "Imported wallet")
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.walletNameLabel.text, "Imported wallet")
        XCTAssertTrue(view.navigationBar.backButton.isHidden)
        XCTAssertNotNil(view.iconImageView.image)
        XCTAssertEqual(view.importMoreButton.imageWithTitleView?.title, R.string.localizable.backupWalletImportedImportMore(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.continueButton.imageWithTitleView?.title, R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.continueButton.frame.height, UIConstants.actionHeight, accuracy: 0.5)
        XCTAssertGreaterThan(view.importMoreButton.frame.minY, view.continueButton.frame.maxY)
    }
}
