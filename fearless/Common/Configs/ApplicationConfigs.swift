import Foundation
import os
import SSFXCM

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

    var chainsSourceUrl: URL { get }
    var chainTypesSourceUrl: URL { get }
    var appVersionURL: URL? { get }
    var scamListCsvURL: URL? { get }
    var polkaswapSettingsURL: URL? { get }
}

final class ApplicationConfig {
    static let shared = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol, XcmConfigProtocol {
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
        URL(string: "https://forum.polkadot.network/t/the-future-of-polkadot-staking/1848?ref=cms.polkadot.network#deprecating-controller-6")!
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

    var chainsSourceUrl: URL {
        #if F_DEV
            GitHubUrl.url(suffix: "chains/v10/chains_dev.json", branch: .developFree)
        #else
            GitHubUrl.url(suffix: "chains/v10/chains.json")
        #endif
    }

    var chainTypesSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/all_chains_types.json")
    }

    // MARK: - xcm

    var destinationFeeSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_fees.json")
    }

    var tokenLocationsSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_token_locations.json")
    }

    var appVersionURL: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "appVersionSupport/ios_app_support_dev.json")
        #else
            GitHubUrl.url(suffix: "appVersionSupport/ios_app_support.json")
        #endif
    }

    var polkaswapSettingsURL: URL? {
        GitHubUrl.url(suffix: "polkaswapSettings.json", url: .fearlessUtils, branch: .v4)
    }

    var fiatsURL: URL? {
        URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/android/v2/fiat/fiats.json")
    }

    var poolStakingAboutURL: URL? {
        URL(string: "https://wiki.polkadot.network/docs/learn-nomination-pools")
    }

    var scamListCsvURL: URL? {
        GitHubUrl.url(suffix: "scamDetection/Polkadot_Hot_Wallet_Attributions.csv")
    }

    var featureToggleURL: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "appConfigs/feature_toggle", branch: .developFree)
        #else
            GitHubUrl.url(suffix: "appConfigs/feature_toggle")
        #endif
    }

    var onboardingConfig: URL? {
        #if F_DEV
            GitHubUrl.url(suffix: "appConfigs/onboarding/mobile v2.json", branch: .developFree)
        #else
            GitHubUrl.url(suffix: "appConfigs/onboarding/mobile v2.json")
        #endif
    }
}

private enum GitHubUrl {
    enum BaseUrl: String {
        case sharedUtils = "https://raw.githubusercontent.com/soramitsu/shared-features-utils/"
        case fearlessUtils = "https://raw.githubusercontent.com/soramitsu/fearless-utils/"
    }

    enum DefaultBranch: String {
        case master
        case develop
        case v4
        case developFree = "develop-free"
        case xcmLocationDevelop = "updated-xcm-locations"
        case rococo = "feature/rococo"
        case newEvms = "new-evms"
        case masterReef = "master-reef"
    }

    static func url(suffix: String, url: BaseUrl = .sharedUtils, branch: DefaultBranch = .master) -> URL {
        URL(string: url.rawValue)!.appendingPathComponent(branch.rawValue).appendingPathComponent(suffix)
    }
}
