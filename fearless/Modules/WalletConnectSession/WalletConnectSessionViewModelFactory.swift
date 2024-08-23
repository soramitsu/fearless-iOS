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
    private let variant: ConnectRequestVariant
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let walletConnectPayloaFactory: WalletConnectPayloadFactory
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        variant: ConnectRequestVariant,
        walletConnectModelFactory: WalletConnectModelFactory,
        walletConnectPayloaFactory: WalletConnectPayloadFactory,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.variant = variant
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
        switch variant {
        case let .walletConnect(request, session):
            return try await buildWalletConnectViewModel(
                request: request,
                session: session,
                wallets: wallets,
                chains: chains,
                balanceInfo: balanceInfo,
                locale: locale
            )
        case let .tonJsBridge(_, wallet, dapp, request, _):
            return try buildTonViewModel(
                wallet: wallet,
                app: dapp.url.host,
                request: request,
                balanceInfo: balanceInfo,
                locale: locale
            )
        case let .tonConnect(request: request, walletId: walletId, app: app):
            guard let wallet = wallets.first(where: { $0.metaId == walletId }) else {
                throw ConvenienceError(error: "Wallet not found")
            }
            return try buildTonViewModel(
                wallet: wallet,
                app: app.appUrl.host,
                request: request,
                balanceInfo: balanceInfo,
                locale: locale
            )
        }
    }

    // MARK: - Private methods

    private func buildWalletConnectViewModel(
        request: Request,
        session: Session?,
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) async throws -> WalletConnectSessionViewModel {
        var dApp: String?
        if let session = session {
            dApp = URL(string: session.peer.url)?.host
        }

        let payload = try await prepareSignPayload(chains: chains, request: request)
        let wallet = try findWallet(for: payload.address, wallets: wallets, chains: chains, request: request)
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

    private func buildTonViewModel(
        wallet: MetaAccountModel,
        app: String?,
        request: TonConnect.AppRequest,
        balanceInfo: WalletBalanceInfos?,
        locale: Locale
    ) throws -> WalletConnectSessionViewModel {
        let walletViewModel = createWalletViewModel(
            wallet: wallet,
            balanceInfo: balanceInfo,
            locale: locale
        )

        let payload = WalletConnectPayload(
            address: nil,
            payload: AnyCodable(any: ""),
            stringRepresentation: request.method.rawValue,
            txDetails: try request.toScaleCompatibleJSON()
        )

        return WalletConnectSessionViewModel(
            dApp: app,
            warning: createWarning(locale: locale),
            walletViewModel: walletViewModel,
            payload: payload,
            wallet: wallet
        )
    }

    private func prepareSignPayload(
        chains: [ChainModel],
        request: Request
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
        for address: String?,
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        request: Request
    ) throws -> MetaAccountModel {
        let blockchain = request.chainId
        let chain = try walletConnectModelFactory.resolveChain(for: blockchain, chains: chains)

        let wallet = wallets.first { wallet in
            let accountRequest = chain.accountRequest()
            let walletAddress = wallet.fetch(for: accountRequest)?.toAddress()
            return walletAddress?.lowercased() == address?.lowercased()
        }
        guard let wallet = wallet else {
            throw AutoNamespacesError.requiredAccountsNotSatisfied
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

    private func createWarning(locale: Locale) -> NSAttributedString {
        let warningLabel = R.string.localizable.commonWarningCapitalized(preferredLanguages: locale.rLanguages)
        let warningMessage = R.string.localizable.walletConnectSignWarningMessage(preferredLanguages: locale.rLanguages)
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
