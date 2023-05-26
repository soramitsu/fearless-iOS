import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var devStatusURL: URL { get }
    var roadmapURL: URL { get }
    var supportEmail: String { get }
    var websiteURL: URL { get }
    var version: String { get }
    var opensourceURL: URL { get }
    var appName: String { get }
    var logoURL: URL { get }
    var purchaseAppName: String { get }
    var moonPayApiKey: String { get }
    var purchaseRedirect: URL { get }
    var phishingListURL: URL { get }
    var learnPayoutURL: URL { get }
    var learnControllerAccountURL: URL { get }
    var twitter: URL { get }
    var youTube: URL { get }
    var instagram: URL { get }
    var medium: URL { get }
    var wiki: URL { get }
    var fearlessWallet: URL { get }
    var fearlessAnnouncements: URL { get }
    var fearlessHappiness: URL { get }
    var crowdloanWiki: URL { get }

    // MARK: - GitHub

    var chainListURL: URL? { get }
    var assetListURL: URL? { get }
    var chainsTypesURL: URL? { get }
    var appVersionURL: URL? { get }
    var scamListCsvURL: URL? { get }
    var polkaswapSettingsURL: URL? { get }
}

final class ApplicationConfig {
    static let shared = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {
    var termsURL: URL {
        URL(string: "https://fearlesswallet.io/terms")!
    }

    var privacyPolicyURL: URL {
        URL(string: "https://fearlesswallet.io/privacy")!
    }

    var devStatusURL: URL {
        URL(string: "https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2")!
    }

    var roadmapURL: URL {
        URL(string: "https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14")!
    }

    var supportEmail: String {
        "fearless@soramitsu.co.jp"
    }

    var websiteURL: URL {
        URL(string: "https://fearlesswallet.io")!
    }

    // swiftlint:disable force_cast
    var version: String {
        let bundle = Bundle(for: ApplicationConfig.self)

        let mainVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as! String
        let buildNumber = bundle.infoDictionary?["CFBundleVersion"] as! String

        return "\(mainVersion).\(buildNumber)"
    }

    // swiftlint:enable force_cast

    var opensourceURL: URL {
        URL(string: "https://github.com/soramitsu/fearless-iOS")!
    }

    // swiftlint:disable force_cast
    var appName: String {
        let bundle = Bundle(for: ApplicationConfig.self)
        return bundle.infoDictionary?["CFBundleDisplayName"] as! String
    }

    // swiftlint:enable force_cast

    var logoURL: URL {
        // swiftlint:disable:next line_length
        let logoString = "https://raw.githubusercontent.com/sora-xor/sora-branding/master/Fearless-Wallet-brand/fearless-wallet-logo-ramp.png"
        return URL(string: logoString)!
    }

    var purchaseAppName: String {
        "Fearless Wallet"
    }

    var moonPayApiKey: String {
        "pk_live_Boi6Rl107p7XuJWBL8GJRzGWlmUSoxbz"
    }

    var purchaseRedirect: URL {
        URL(string: "fearless://fearless.io/redirect")!
    }

    var phishingListURL: URL {
        URL(string: "https://polkadot.js.org/phishing/address.json")!
    }

    var learnPayoutURL: URL {
        URL(string: "https://wiki.polkadot.network/docs/learn-staking-advanced#simple-payouts")!
    }

    var learnControllerAccountURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://wiki.polkadot.network/docs/en/maintain-guides-how-to-nominate-polkadot#setting-up-stash-and-controller-keys")!
    }

    var twitter: URL {
        URL(string: "https://twitter.com/fearlesswallet")!
    }

    var youTube: URL {
        URL(string: "https://youtube.com/fearlesswallet")!
    }

    var instagram: URL {
        URL(string: "https://instagram.com/fearless_wallet")!
    }

    var medium: URL {
        URL(string: "https://medium.com/fearlesswallet")!
    }

    var wiki: URL {
        URL(string: "https://wiki.fearlesswallet.io")!
    }

    var fearlessWallet: URL {
        URL(string: "https://t.me/fearlesswallet")!
    }

    var fearlessAnnouncements: URL {
        URL(string: "https://t.me/fearless_announcements")!
    }

    var fearlessHappiness: URL {
        URL(string: "https://t.me/fearlesshappiness")!
    }

    var crowdloanWiki: URL {
        URL(string: "https://wiki.fearlesswallet.io/crowdloans")!
    }

    // MARK: - GitHub

    var chainListURL: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "chains/chains_dev.json", branch: "develop")
        #else
            GitHubUrl.url(suffix: "chains/chains.json")
        #endif
    }

    var assetListURL: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "chains/assets_dev.json", branch: "develop")
        #else
            GitHubUrl.url(suffix: "chains/assets.json")
        #endif
    }

    var chainsTypesURL: URL? {
        GitHubUrl.url(suffix: "chains/all_chains_types.json")
    }

    var appVersionURL: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "appVersionSupport/ios_app_support_dev.json")
        #else
            GitHubUrl.url(suffix: "appVersionSupport/ios_app_support.json")
        #endif
    }

    var polkaswapSettingsURL: URL? {
        URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/v4/polkaswapSettings.json")
    }

    var fiatsURL: URL? {
        URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/android/v2/fiat/fiats.json")
    }

    var poolStakingAboutURL: URL? {
        URL(string: "https://wiki.polkadot.network/docs/learn-nomination-pools")
    }

    var scamListCsvURL: URL? {
        GitHubUrl.url(suffix: "Polkadot_Hot_Wallet_Attributions.csv", branch: "master")
    }

    var soraCardCountriesBlacklist: URL? {
        URL(string: "https://soracard.com/blacklist")
    }

    var xcmFeesURL: URL? {
        URL(string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/develop/xcm_fees.json")
    }
}

private enum GitHubUrl {
    private static var baseUrl: URL {
        URL(string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/")!
    }

    private static let defaultBranch = "master"

    static func url(suffix: String, branch: String = defaultBranch) -> URL {
        baseUrl.appendingPathComponent(branch).appendingPathComponent(suffix)
    }
}
