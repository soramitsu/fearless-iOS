import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupWalletViewModelFactoryProtocol {
    func createViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        balance: WalletBalanceInfo?,
        exportOptions: [ExportOption],
        backupAccounts: [OpenBackupAccount]
    ) -> ProfileViewModelProtocol
}

enum BackupWalletOptions: Int, CaseIterable {
    case phrase
    case seed
    case json
    case backupGoogle
    case removeGoogle

    init(exportOptions: ExportOption) {
        switch exportOptions {
        case .mnemonic:
            self = .phrase
        case .seed:
            self = .seed
        case .keystore:
            self = .json
        }
    }
}

final class BackupWalletViewModelFactory: BackupWalletViewModelFactoryProtocol {
    private lazy var assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

    func createViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        balance: WalletBalanceInfo?,
        exportOptions: [ExportOption],
        backupAccounts: [OpenBackupAccount]
    ) -> ProfileViewModelProtocol {
        let profileUserViewModel = createUserViewModel(
            from: wallet,
            balance: balance,
            locale: locale
        )
        let profileOptionViewModel = createOptionViewModels(
            wallet: wallet,
            exportOptions: exportOptions,
            backupAccounts: backupAccounts,
            locale: locale
        )
        let logoutViewModel = createLogoutViewModel(locale: locale)
        return ProfileViewModel(
            profileUserViewModel: profileUserViewModel,
            profileOptionViewModel: profileOptionViewModel,
            logoutViewModel: logoutViewModel
        )
    }

    // MARK: - Private methods

    private func createOptionViewModels(
        wallet: MetaAccountModel,
        exportOptions: [ExportOption],
        backupAccounts: [OpenBackupAccount],
        locale: Locale
    ) -> [ProfileOptionViewModelProtocol] {
        var backupOptions: [BackupWalletOptions] = exportOptions.map { BackupWalletOptions(exportOptions: $0) }
        if backupAccounts.contains(where: { $0.address == wallet.substrateAccountId.toHex() }) {
            backupOptions.append(.removeGoogle)
        } else if !backupAccounts.contains(where: { $0.address == wallet.substrateAccountId.toHex() }) {
            backupOptions.append(.backupGoogle)
        }

        let optionViewModels = backupOptions.compactMap { (option) -> ProfileOptionViewModel? in
            switch option {
            case .phrase:
                let title = R.string.localizable
                    .backupRisksWarningsContinueButton(preferredLanguages: locale.rLanguages)
                return ProfileOptionViewModel(
                    title: title,
                    icon: R.image.iconPassPhrase(),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: nil
                )
            case .seed:
                let title = R.string.localizable
                    .backupWalletSeed(preferredLanguages: locale.rLanguages)
                return ProfileOptionViewModel(
                    title: title,
                    icon: R.image.iconKey(),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: nil
                )
            case .json:
                let title = R.string.localizable
                    .backupWalletJson(preferredLanguages: locale.rLanguages)
                return ProfileOptionViewModel(
                    title: title,
                    icon: R.image.arrowUpRectangle(),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: nil
                )
            case .backupGoogle:
                let title = R.string.localizable
                    .backupWalletBackupGoogle(preferredLanguages: locale.rLanguages)
                return ProfileOptionViewModel(
                    title: title,
                    icon: R.image.iconGoogle(),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: nil
                )
            case .removeGoogle:
                let title = R.string.localizable
                    .backupWalletDeleteGoogle(preferredLanguages: locale.rLanguages)
                return ProfileOptionViewModel(
                    title: title,
                    icon: R.image.iconGoogle(),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: nil
                )
            }
        }

        return optionViewModels
    }

    private func createUserViewModel(
        from wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        locale: Locale
    ) -> WalletsManagmentCellViewModel {
        var fiatBalance: String = ""
        var dayChange: NSAttributedString?
        if let balance = balance {
            let formatter = tokenFormatter(for: balance.currency, locale: locale)
            fiatBalance = formatter.stringFromDecimal(balance.totalFiatValue) ?? ""
            dayChange = getDayChangeAttributedString(
                currency: balance.currency,
                dayChange: balance.dayChangePercent,
                dayChangeValue: balance.dayChangeValue,
                locale: locale
            )
        }

        return WalletsManagmentCellViewModel(
            isSelected: false,
            walletName: wallet.name,
            fiatBalance: fiatBalance,
            dayChange: dayChange
        )
    }

    private func createLogoutViewModel(locale: Locale) -> ProfileOptionViewModelProtocol {
        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLogout()!,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: nil
        )
        return viewModel
    }

    private func tokenFormatter(for currency: Currency, locale: Locale) -> TokenFormatter {
        let balanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo, usageCase: .detailsCrypto)
        let balanceTokenFormatterValue = balanceTokenFormatter.value(for: locale)
        return balanceTokenFormatterValue
    }

    private func getDayChangeAttributedString(
        currency: Currency,
        dayChange: Decimal,
        dayChangeValue: Decimal,
        locale: Locale
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)
        let dayChangePercent = dayChange.percentString(locale: locale) ?? ""

        var dayChangeValue: String = balanceTokenFormatterValue.stringFromDecimal(abs(dayChangeValue)) ?? ""
        dayChangeValue = "(\(dayChangeValue))"
        let priceWithChangeString = [dayChangePercent, dayChangeValue].joined(separator: " ")
        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = dayChange > 0
            ? R.color.colorGreen()
            : R.color.colorRed()

        if let color = color, let colorLightGray = R.color.colorStrokeGray() {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: 0,
                    length: dayChangePercent.count
                )
            )
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: colorLightGray],
                range: NSRange(
                    location: dayChangePercent.count + 1,
                    length: dayChangeValue.count
                )
            )
        }

        return priceWithChangeAttributed
    }
}
