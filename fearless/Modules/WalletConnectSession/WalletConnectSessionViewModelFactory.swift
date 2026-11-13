import Foundation
import FearlessWalletConnect
import SoraFoundation
import SSFModels
import SSFUtils
import SoraKeystore

protocol WalletConnectSessionViewModelFactory {
    func buildViewModel(
        signingRequest: WalletConnectSigningRequest,
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) -> WalletConnectSessionViewModel
}

final class WalletConnectSessionViewModelFactoryImpl: WalletConnectSessionViewModelFactory {
    private let session: Session?
    private let verification: WalletConnectVerification
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let accountScoreFetcher: AccountStatisticsFetching
    private let settings: SettingsManagerProtocol

    init(
        session: Session?,
        verification: WalletConnectVerification,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        accountScoreFetcher: AccountStatisticsFetching,
        settings: SettingsManagerProtocol
    ) {
        self.session = session
        self.verification = verification
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.accountScoreFetcher = accountScoreFetcher
        self.settings = settings
    }

    func buildViewModel(
        signingRequest: WalletConnectSigningRequest,
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) -> WalletConnectSessionViewModel {
        var dApp: String?
        if let session = session {
            dApp = verification.website(claimed: session.peer.url)
        }

        let walletViewModel = createWalletViewModel(
            wallet: signingRequest.wallet,
            balanceInfo: balanceInfo,
            locale: locale
        )

        return WalletConnectSessionViewModel(
            dApp: dApp,
            verification: verification.title(for: locale),
            verificationColor: verification.color,
            warning: createWarning(locale: locale),
            walletViewModel: walletViewModel,
            messagePreview: messagePreview(for: signingRequest),
            signingRequest: signingRequest
        )
    }

    // MARK: - Private methods

    private func messagePreview(for signingRequest: WalletConnectSigningRequest) -> String {
        switch signingRequest.content {
        case let .ethereumMessage(message), let .polkadotMessage(message):
            return message.displayText
        case let .ethereumTypedData(typedData):
            return [typedData.domainName, typedData.primaryType]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .ethereumTransaction, .polkadotTransaction:
            return signingRequest.preview
        }
    }

    private func createWalletViewModel(
        wallet: MetaAccountModel,
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) -> WalletsManagmentCellViewModel {
        let address = wallet.ethereumAddress?.toHex(includePrefix: true)
        let accountScoreViewModel = AccountScoreViewModel(
            fetcher: accountScoreFetcher,
            address: address,
            chain: nil,
            settings: settings,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        guard let balance = balanceInfo?[wallet.metaId] else {
            return WalletsManagmentCellViewModel(
                isSelected: false,
                walletName: wallet.name,
                fiatBalance: nil,
                dayChange: nil,
                accountScoreViewModel: accountScoreViewModel
            )
        }
        let balanceTokenFormatterValue = tokenFormatter(
            for: balance.currency,
            locale: locale
        )

        let totalFiatValue = balanceTokenFormatterValue
            .stringFromDecimal(balance.totalFiatValue)

        let dayChange = getDayChangeAttributedString(
            currency: balance.currency,
            dayChange: balance.totalDayChangePercent,
            dayChangeValue: balance.totalDayChangeValue,
            locale: locale
        )

        let viewModel = WalletsManagmentCellViewModel(
            isSelected: false,
            walletName: wallet.name,
            fiatBalance: totalFiatValue,
            dayChange: dayChange,
            accountScoreViewModel: accountScoreViewModel,
            balanceCaption: balance.allHoldingsCaption
        )

        return viewModel
    }

    private func createWarning(locale: Locale) -> NSAttributedString {
        let warningLabel = R.string.localizable.commonWarningCapitalized(preferredLanguages: locale.rLanguages)
        // A domain mismatch, or a site Verify could not check, is the more specific warning.
        let warningMessage = verification.warning(for: locale) ??
            R.string.localizable.walletConnectSignWarningMessage(preferredLanguages: locale.rLanguages)
        let warningFullString = [warningLabel, warningMessage].joined(separator: " ")
        let warning = NSMutableAttributedString(string: warningFullString)

        warning.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorOrange()!.cgColor,
            range: NSRange(
                location: 0,
                length: warningLabel.count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.h6Title,
            range: NSRange(
                location: 0,
                length: warningLabel.count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.p2Paragraph,
            range: NSRange(
                location: warningLabel.count,
                length: warning.string.count - warningLabel.count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorStrokeGray()!.cgColor,
            range: NSRange(
                location: warningLabel.count,
                length: warning.string.count - warningLabel.count
            )
        )
        return warning
    }

    private func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .fiat)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
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

        let color = FWSunlit.Palette.change(dayChange)

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
