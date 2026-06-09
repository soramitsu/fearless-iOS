import Foundation

public enum CIKeysGeneratorError: Error, Equatable, CustomStringConvertible {
    case unknownArgument(String)

    public var description: String {
        switch self {
        case let .unknownArgument(argument):
            return "Unknown CI key template argument: \(argument)"
        }
    }
}

public enum CIKeysGenerator {
    private struct EnvironmentValue {
        let key: String
        let fallbackKey: String?

        func resolve(from environment: [String: String]) -> String {
            let value = environment[key] ?? ""

            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }

            return fallbackKey.flatMap { environment[$0] } ?? ""
        }
    }

    private static let argumentMap: [String: EnvironmentValue] = [
        "moonPaySecretKey": .init(key: "MOONPAY_PRODUCTION_SECRET", fallbackKey: nil),
        "moonPayTestSecretKey": .init(key: "MOONPAY_TEST_SECRET", fallbackKey: nil),
        "soraCardAPIKey": .init(key: "SORA_CARD_API_KEY", fallbackKey: nil),
        "soraCardDomain": .init(key: "SORA_CARD_DOMAIN", fallbackKey: nil),
        "soraCardKycEndpoint": .init(key: "SORA_CARD_KYC_ENDPOINT_URL", fallbackKey: nil),
        "soraCardKycUsername": .init(key: "SORA_CARD_KYC_USERNAME", fallbackKey: nil),
        "soraCardKycPassword": .init(key: "SORA_CARD_KYC_PASSWORD", fallbackKey: nil),
        "rampHostApiKey": .init(key: "RAMP_HOST_API_KEY", fallbackKey: nil),
        "moonbeamCrowdloanDevApiKey": .init(key: "MOONBEAM_CROWDLOAN_DEV_API_KEY", fallbackKey: nil),
        "moonbeamCrowdloanProdApiKey": .init(key: "MOONBEAM_CROWDLOAN_PROD_API_KEY", fallbackKey: nil),
        "ethereumApiKey": .init(key: "FL_BLAST_API_ETHEREUM_KEY", fallbackKey: nil),
        "bscApiKey": .init(key: "FL_BLAST_API_BSC_KEY", fallbackKey: nil),
        "sepoliaApiKey": .init(key: "FL_BLAST_API_SEPOLIA_KEY", fallbackKey: nil),
        "goerliApiKey": .init(key: "FL_BLAST_API_GOERLI_KEY", fallbackKey: nil),
        "polygonApiKey": .init(key: "FL_BLAST_API_POLYGON_KEY", fallbackKey: nil),
        "ethereumApiKeyDebug": .init(
            key: "FL_BLAST_API_ETHEREUM_KEY_DEBUG",
            fallbackKey: "FL_BLAST_API_ETHEREUM_KEY"
        ),
        "bscApiKeyDebug": .init(key: "FL_BLAST_API_BSC_KEY_DEBUG", fallbackKey: "FL_BLAST_API_BSC_KEY"),
        "sepoliaApiKeyDebug": .init(
            key: "FL_BLAST_API_SEPOLIA_KEY_DEBUG",
            fallbackKey: "FL_BLAST_API_SEPOLIA_KEY"
        ),
        "goerliApiKeyDebug": .init(key: "FL_BLAST_API_GOERLI_KEY_DEBUG", fallbackKey: "FL_BLAST_API_GOERLI_KEY"),
        "polygonApiKeyDebug": .init(
            key: "FL_BLAST_API_POLYGON_KEY_DEBUG",
            fallbackKey: "FL_BLAST_API_POLYGON_KEY"
        ),
        "webClientIdRelease": .init(key: "WEB_CLIENT_ID_RELEASE", fallbackKey: nil),
        "fearlessGoogleUrlSchemeRelease": .init(key: "FEARLESS_GOOGLE_URL_SCHEME_RELEASE", fallbackKey: nil),
        "webClientIdDebug": .init(key: "WEB_CLIENT_ID_DEBUG", fallbackKey: "WEB_CLIENT_ID_RELEASE"),
        "fearlessGoogleUrlSchemeDebug": .init(
            key: "FEARLESS_GOOGLE_URL_SCHEME_DEBUG",
            fallbackKey: "FEARLESS_GOOGLE_URL_SCHEME_RELEASE"
        ),
        "walletConnectProjectId": .init(key: "FL_WALLET_CONNECT_PROJECT_ID", fallbackKey: nil),
        "walletConnectProjectIdDebug": .init(
            key: "FL_WALLET_CONNECT_PROJECT_ID_DEBUG",
            fallbackKey: "FL_WALLET_CONNECT_PROJECT_ID"
        ),
        "etherscanApiKey": .init(key: "FL_IOS_ETHERSCAN_API_KEY", fallbackKey: nil),
        "polygonscanApiKey": .init(key: "FL_IOS_POLYGONSCAN_API_KEY", fallbackKey: nil),
        "bscscanApiKey": .init(key: "FL_IOS_BSCSCAN_API_KEY", fallbackKey: nil),
        "oklinkApiKey": .init(key: "FL_OKLINK_API_KEY", fallbackKey: nil),
        "opMainnetApiKey": .init(key: "FL_IOS_OPTIMISTIC_ETHERSCAN_API_KEY", fallbackKey: nil),
        "alchemyApiKey": .init(key: "FL_IOS_ALCHEMY_API_ETHEREUM_KEY", fallbackKey: nil),
        "dwellirApiKey": .init(key: "FL_DWELLIR_API_KEY", fallbackKey: nil),
        "coinbaseSessionToken": .init(key: "COINBASE_SESSION_TOKEN", fallbackKey: nil),
        "tonApiKey": .init(key: "FL_TON_API_KEY", fallbackKey: nil),
        "tonApiKeyDebug": .init(key: "FL_TON_API_KEY_DEBUG", fallbackKey: "FL_TON_API_KEY"),
        "okxApiKey": .init(key: "FL_OKX_API_KEY", fallbackKey: nil),
        "okxSecretKey": .init(key: "FL_OKX_SECRET_KEY", fallbackKey: nil),
        "okxPassphrase": .init(key: "FL_OKX_PASSPHRASE", fallbackKey: nil),
        "okxProjectId": .init(key: "FL_OKX_PROJECT_ID", fallbackKey: nil),
        "nomisClientId": .init(key: "FL_NOMIS_CLIENT_ID", fallbackKey: nil),
        "nomisApiKey": .init(key: "FL_NOMIS_API_KEY", fallbackKey: nil)
    ]

    public static func render(template: String, environment: [String: String]) throws -> String {
        let pattern = #"\{\{\s*argument\.([A-Za-z0-9_]+)\s*\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: range).reversed()

        var output = template

        for match in matches {
            guard
                let argumentRange = Range(match.range(at: 1), in: template),
                let placeholderRange = Range(match.range(at: 0), in: output)
            else {
                continue
            }

            let argument = String(template[argumentRange])
            guard let environmentValue = argumentMap[argument] else {
                throw CIKeysGeneratorError.unknownArgument(argument)
            }

            let value = environmentValue.resolve(from: environment)
            output.replaceSubrange(placeholderRange, with: value.swiftEscapedForStringLiteral)
        }

        return output
    }
}

private extension String {
    var swiftEscapedForStringLiteral: String {
        unicodeScalars.reduce(into: "") { result, scalar in
            switch scalar {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            default:
                if CharacterSet.controlCharacters.contains(scalar) {
                    result += "\\u{\(String(scalar.value, radix: 16))}"
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
    }
}
