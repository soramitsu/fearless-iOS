import Foundation

enum FWAppearance {
    static var receivePresentationRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleReceivePresentation") as? String == "YES"
    }

    static var sendPresentationRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleSendPresentation") as? String == "YES"
    }

    static var assetManagementRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleAssetManagement") as? String == "YES"
    }

    static var portfolioListRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestylePortfolioList") as? String == "YES"
    }

    static var walletHeaderRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleWalletHeader") as? String == "YES"
    }

    static var startupRecoveryRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleStartupRecovery") as? String == "YES"
    }

    static var exportGenericRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleExportGeneric") as? String == "YES"
    }

    static var accountExportPasswordRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleAccountExportPassword") as? String == "YES"
    }

    static var accountConfirmRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleAccountConfirm") as? String == "YES"
    }

    static var accountCreateRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleAccountCreate") as? String == "YES"
    }

    static var walletEntryRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleWalletEntry") as? String == "YES"
    }

    /// A build-time rollback changes presentation only; startup and wallet routes stay shared.
    static var welcomeRestyled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FWRestyleWelcome") as? String == "YES"
    }
}
