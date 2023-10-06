import Foundation
import WalletConnectSign
import SoraFoundation
import SSFModels
import SSFUtils

protocol WalletConnectSessionViewModelFactory {
    func buildViewModel(
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) async throws -> WalletConnectSessionViewModel
}

final class WalletConnectSessionViewModelFactoryImpl: WalletConnectSessionViewModelFactory {
    private let request: Request
    private let session: Session?
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let walletConnectPayloaFactory: WalletConnectPayloadFactory
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        request: Request,
        session: Session?,
        walletConnectModelFactory: WalletConnectModelFactory,
        walletConnectPayloaFactory: WalletConnectPayloadFactory,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.request = request
        self.session = session
        self.walletConnectModelFactory = walletConnectModelFactory
        self.walletConnectPayloaFactory = walletConnectPayloaFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) async throws -> WalletConnectSessionViewModel {
        var dApp: String?
        if let session = session {
            dApp = URL(string: session.peer.url)?.host
        }

        let payload = try await prepareSignPayload(chains: chains)
        let wallet = try findWallet(for: payload.address, wallets: wallets, chains: chains)
        let walletViewModel = createWalletViewModel(
            wallet: wallet,
            balanceInfo: balanceInfo,
            locale: locale
        )

        return WalletConnectSessionViewModel(
            dApp: dApp,
            warning: createWarning(locale: locale),
            walletViewModel: walletViewModel,
            payload: payload,
            wallet: wallet
        )
    }

    // MARK: - Private methods

    private func prepareSignPayload(
        chains: [ChainModel]
    ) async throws -> WalletConnectPayload {
        let method = try walletConnectModelFactory.parseMethod(from: request)
        let chain = try walletConnectModelFactory.resolveChain(for: request.chainId, chains: chains)
        let payload = try await walletConnectPayloaFactory.createTransactionPayload(
            request: request,
            method: method,
            chain: chain
        )

        return payload
    }

    private func findWallet(
        for address: String,
        wallets: [MetaAccountModel],
        chains: [ChainModel]
    ) throws -> MetaAccountModel {
        let blockchain = request.chainId
        let chain = try walletConnectModelFactory.resolveChain(for: blockchain, chains: chains)

        let wallet = wallets.first { wallet in
            let accountRequest = chain.accountRequest()
            let walletAddress = wallet.fetch(for: accountRequest)?.toAddress()
            return walletAddress?.lowercased() == address.lowercased()
        }
        guard let wallet = wallet else {
            throw JSONRPCError.unsupportedAccounts
        }
        return wallet
    }

    private func createWalletViewModel(
        wallet: MetaAccountModel,
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) -> WalletsManagmentCellViewModel {
        guard let balance = balanceInfo?[wallet.metaId] else {
            return WalletsManagmentCellViewModel(
                isSelected: false,
                walletName: wallet.name,
                fiatBalance: nil,
                dayChange: nil
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
            dayChange: balance.dayChangePercent,
            dayChangeValue: balance.dayChangeValue,
            locale: locale
        )

        let viewModel = WalletsManagmentCellViewModel(
            isSelected: false,
            walletName: wallet.name,
            fiatBalance: totalFiatValue,
            dayChange: dayChange
        )

        return viewModel
    }

    private func createWarning(locale _: Locale) -> NSAttributedString {
        let warning = NSMutableAttributedString(string: "WARNING: Signing this message can have dangerous side effect. Only sign message from sites you fully trust with your entire account.")

        warning.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorOrange()!.cgColor,
            range: NSRange(
                location: 0,
                length: "WARNING:".count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.h6Title,
            range: NSRange(
                location: 0,
                length: "WARNING:".count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.p2Paragraph,
            range: NSRange(
                location: "WARNING:".count,
                length: warning.string.count - "WARNING:".count
            )
        )

        warning.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorStrokeGray()!.cgColor,
            range: NSRange(
                location: "WARNING:".count,
                length: warning.string.count - "WARNING:".count
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
