import CryptoKit
@testable import fearless
import UIKit
import XCTest

/// Mathematical contract against compiled UIKit colours. Screen pixels and state cues have separate gates.
@MainActor
final class FWContrastContractTests: XCTestCase {
    private let contractDigest = "c1cda5d513e1095459004426104ef8d2e80f4bb3dc96d6b2012904ccfd180737"

    func testPinnedSharedInputsMatchEveryCompiledColorAndGeneratedGradient() throws {
        let model = try Model()
        XCTAssertEqual(digest(model.tokenData), FWTokens.sourceSHA256)
        XCTAssertEqual(digest(model.contractData), contractDigest)
        XCTAssertEqual(model.groups.count, 33)
        XCTAssertEqual(model.semantic.count, 45)
        let assets = try model.semantic.values.compactMap { try model.extensions($0)["ios"] as? String }
        XCTAssertEqual(Set(assets), Set(FWTokens.colorsets))
        XCTAssertEqual(assets.count, 41)
        for high in [false, true] {
            let recipes = Recipes(model: model, high: high, byteAlpha: false)
            for (name, token) in model.semantic {
                let expected = try model.paint(model.highContrast[name].flatMap { high ? $0 : nil } ?? token)
                let actual = try recipes.native(name)
                XCTAssertEqual(actual.rgb, expected.rgb, name)
                XCTAssertEqual(actual.alpha, expected.alpha, accuracy: 0.000_001, name)
            }
        }
        for (name, gradient) in generatedGradients {
            let spec = try dictionary(model.gradients[name])
            let stops = try XCTUnwrap(spec["$value"] as? [[String: Any]])
            XCTAssertEqual(gradient.colors.count, stops.count, name)
            XCTAssertEqual(gradient.locations.map(\.doubleValue), try stops.map { try number($0["position"]) }, name)
            XCTAssertEqual(Double(gradient.angle), try number(model.extensions(spec)["angle"]), name)
            for (color, stop) in zip(gradient.colors, stops) {
                let actual = try Paint(color: color)
                let expected = try model.paint(["$value": dictionary(stop["color"])])
                XCTAssertEqual(actual.rgb, expected.rgb, name)
                XCTAssertEqual(actual.alpha, expected.alpha, accuracy: 0.000_001, name)
            }
        }
        let containers = try dictionary(model.color["statusContainerAlpha"])
        XCTAssertEqual(Double(FWTokens.Alpha.statusContainer), try number(dictionary(containers["default"])["$value"]))
        XCTAssertEqual(Double(FWTokens.Alpha.infoContainer), try number(dictionary(containers["info"])["$value"]))
    }

    func testEveryAllowedPairAgainstActualUIKitPalettesAndBothAlphaEncodings() throws {
        let model = try Model()
        var rows = [[String: Any]]()
        for high in [false, true] {
            for byteAlpha in [false, true] {
                rows += try Recipes(model: model, high: high, byteAlpha: byteAlpha).checkPairs()
            }
        }
        XCTAssertEqual(rows.count, 688, "172 combinations × two palettes × source/8-bit alpha")
        let report = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: report, uniformTypeIdentifier: "public.json")
        attachment.name = "UIKit-contrast-688-pair-results"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNativeByteCompositesIncludeWorstAuroraAndWhiteScrollingContent() throws {
        let recipes = try Recipes(model: Model(), high: false, byteAlpha: true)
        XCTAssertEqual(try recipes.resolve("peakAllDither").map(\.rgb), [[71, 50, 107]])
        XCTAssertEqual(try recipes.resolve("chromeSurface").count, 7)
        let glass = try XCTUnwrap(recipes.resolve("glassSurface").last)
        XCTAssertEqual(glass.rgb, [43, 40, 74])
        let control = try XCTUnwrap(recipes.resolve("strokeControl").first)
        XCTAssertGreaterThanOrEqual(contrast(over(control, glass), glass.rgb), 3.5)
        XCTAssertGreaterThan(try recipes.resolve("primaryFill").count, 50)
        XCTAssertEqual(contrast([0, 0, 0], [255, 255, 255]), 21)
    }

    func testPriceColorsMeetBothCVDDeclaredFloorsAndRejectLegacyRedGreen() throws {
        let model = try Model()
        let pairs = try XCTUnwrap(model.contract["cvd"] as? [[String: Any]])
        XCTAssertEqual(pairs.count, 1)
        let pair = try XCTUnwrap(pairs.first)
        XCTAssertEqual(pair["id"] as? String, "price-up-down")
        XCTAssertEqual(pair["foreground"] as? String, "priceUp")
        XCTAssertEqual(pair["background"] as? String, "priceDown")
        XCTAssertEqual(pair["simulations"] as? [String], ["protan", "deutan"])
        XCTAssertEqual(try number(pair["minimumDeltaE76"]), 40)
        for high in [false, true] {
            let recipes = Recipes(model: model, high: high, byteAlpha: false)
            let priceUp = try recipes.native("priceUp").rgb
            let down = try recipes.native("priceDown").rgb
            for (simulation, rounded) in [("protan", 54.0), ("deutan", 67.0)] {
                let distance = try deltaE(priceUp, down, simulation)
                XCTAssertGreaterThanOrEqual(distance, 40)
                XCTAssertEqual(distance.rounded(), rounded)
            }
            XCTAssertEqual(try deltaE(priceUp, priceUp, "protan"), 0)
        }
        XCTAssertLessThan(try deltaE([14, 211, 59], [240, 0, 4], "deutan"), 40)
    }

    func testDecorativeOpacityCannotReplaceInteractiveBoundary() throws {
        let recipes = try Recipes(
            model: Model(),
            high: false,
            byteAlpha: false,
            overrides: ["strokeControl": Paint(rgb: [255, 255, 255], alpha: 0.28)]
        )
        XCTAssertThrowsError(try recipes.checkPairs()) { error in
            XCTAssertTrue(String(describing: error).contains("control-boundary"))
        }
    }

    func testGradientRetainsExactMidpointWithOpposingChannelTransitions() throws {
        let colors = try gradient([Paint(rgb: [0, 1, 0]), Paint(rgb: [1, 0, 0])])
        XCTAssertTrue(colors.contains(Paint(rgb: [1, 1, 0])))
        XCTAssertTrue(colors.contains(Paint(rgb: [0, 1, 0])))
        XCTAssertTrue(colors.contains(Paint(rgb: [1, 0, 0])))
    }

    func testMissingEmptyCyclicAndWeakenedContractsFailClosed() throws {
        var model = try Model()
        XCTAssertThrowsError(try Recipes(model: model, high: false, byteAlpha: false).resolve("missing"))
        model.recipes["loop"] = ["token": "loop"]
        XCTAssertThrowsError(try Recipes(model: model, high: false, byteAlpha: false).resolve("loop"))
        model.recipes["empty"] = ["variants": [String]()]
        XCTAssertThrowsError(try Recipes(model: model, high: false, byteAlpha: false).resolve("empty"))
        model.groups = []
        XCTAssertThrowsError(try Recipes(model: model, high: false, byteAlpha: false).checkPairs())
        model = try Model()
        model.groups[0]["minimum"] = 1
        XCTAssertThrowsError(try Recipes(model: model, high: false, byteAlpha: false).checkPairs())
    }
}

private typealias Object = [String: Any]
private struct ContractFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw ContractFailure(description: message)
    }
}

private func dictionary(_ value: Any?) throws -> Object {
    guard let result = value as? Object else { throw ContractFailure(description: "Missing object") }
    return result
}

private func number(_ value: Any?) throws -> Double {
    guard let result = value as? Double,
          result.isFinite else { throw ContractFailure(description: "Missing finite number") }
    return result
}

private let generatedGradients: [String: FWTokens.Gradient] = [
    "hairline": FWTokens.Gradients.hairline,
    "accent": FWTokens.Gradients.accent,
    "primaryFill": FWTokens.Gradients.primaryFill
]

private struct Paint: Hashable {
    let rgb: [Double]
    var alpha: Double = 1

    init(rgb: [Double], alpha: Double = 1) {
        self.rgb = rgb; self.alpha = alpha
    }

    init(color: UIColor) throws {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        try require(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), "Non-RGB UIKit colour")
        rgb = [red, green, blue].map { (Double($0) * 255).rounded() }
        self.alpha = Double(alpha)
    }
}

private struct Model {
    let tokenData: Data
    let contractData: Data
    let color: Object
    let semantic: [String: Object]
    let highContrast: [String: Object]
    let gradients: [String: Object]
    let contract: Object
    var recipes: [String: Object]
    var groups: [Object]

    init() throws {
        let bundle = Bundle(for: FWContrastContractTests.self)
        guard let tokensURL = bundle.url(forResource: "fw.tokens", withExtension: "json"),
              let contractURL = bundle.url(forResource: "fw.contrast-pairs", withExtension: "json") else {
            throw ContractFailure(description: "Missing compiled shared contract resources")
        }
        tokenData = try Data(contentsOf: tokensURL)
        contractData = try Data(contentsOf: contractURL)
        let tokens = try dictionary(JSONSerialization.jsonObject(with: tokenData))
        color = try dictionary(tokens["color"])
        semantic = try dictionary(color["semantic"]).compactMapValues { $0 as? Object }
        highContrast = try dictionary(color["highContrast"]).compactMapValues { $0 as? Object }
        gradients = try dictionary(tokens["gradient"]).compactMapValues { $0 as? Object }
        contract = try dictionary(JSONSerialization.jsonObject(with: contractData))
        recipes = try dictionary(contract["recipes"]).compactMapValues { $0 as? Object }
        guard let pairs = contract["pairs"] as? [Object] else { throw ContractFailure(description: "Missing pairs") }
        groups = pairs
        try require(
            contract["format"] as? String == "fearless.contrast-pairs" && number(contract["version"]) == 1,
            "Wrong contract format"
        )
    }

    func extensions(_ token: Object) throws -> Object {
        try dictionary(dictionary(token["$extensions"])["fw"])
    }

    func paint(_ token: Object) throws -> Paint {
        let value = try dictionary(token["$value"])
        guard let hex = value["hex"] as? String, hex.count == 7, hex.first == "#",
              let rgb = UInt32(hex.dropFirst(), radix: 16)
        else { throw ContractFailure(description: "Invalid RGB token") }
        return try Paint(
            rgb: [16, 8, 0].map { Double((rgb >> $0) & 255) },
            alpha: value["alpha"].map { try number($0) } ?? 1
        )
    }
}

private struct Recipes {
    let model: Model
    let high: Bool
    let byteAlpha: Bool
    var overrides: [String: Paint] = [:]

    func native(_ name: String) throws -> Paint {
        if let override = overrides[name] {
            return override
        }
        guard let token = model.semantic[name]
        else { throw ContractFailure(description: "Missing semantic colour \(name)") }
        if let asset = try model.extensions(token)["ios"] as? String {
            let traits = UITraitCollection(traitsFrom: [
                .init(userInterfaceStyle: .dark),
                .init(accessibilityContrast: high ? .high : .normal)
            ])
            guard let color = UIColor(named: asset, in: .main, compatibleWith: traits) else {
                throw ContractFailure(description: "Missing compiled asset \(asset)")
            }
            return try Paint(color: color.resolvedColor(with: traits))
        }
        let alphas = ["glassSheen": FWTokens.Alpha.glassSheen, "glassElevatedSheen": FWTokens.Alpha.glassElevatedSheen,
                      "chromeSheen": FWTokens.Alpha.chromeSheen]
        if let alpha = alphas[name] {
            return try Paint(color: UIColor.white.withAlphaComponent(alpha))
        }
        if name == "violet" {
            return try Paint(color: FWTokens.Gradients.accent.colors[1].withAlphaComponent(1))
        }
        throw ContractFailure(description: "Unmapped compiled colour \(name)")
    }

    func alpha(_ value: Double) throws -> Double {
        try require(value.isFinite && (0 ... 1).contains(value), "Invalid alpha")
        return byteAlpha ? (value * 255).rounded() / 255 : value
    }

    func resolve(_ name: String, visiting: Set<String> = []) throws -> [Paint] {
        try require(!visiting.contains(name), "Cyclic recipe \(name)")
        let next = visiting.union([name])
        if model.semantic[name] != nil {
            var paint = try native(name); paint.alpha = try alpha(paint.alpha); return [paint]
        }
        guard let recipe = model.recipes[name] else { throw ContractFailure(description: "Unknown recipe \(name)") }
        if let token = recipe["token"] as? String {
            return try resolve(token, visiting: next)
        }
        if let name = recipe["aurora"] as? String {
            let token = try dictionary(dictionary(model.color["aurora"])[name])
            var paint = try model.paint(token); paint.alpha = try alpha(paint.alpha); return [paint]
        }
        if let variants = recipe["variants"] as? [String] {
            try require(!variants.isEmpty, "Empty recipe \(name)")
            return try variants.flatMap { try resolve($0, visiting: next) }
        }
        if let name = recipe["gradient"] as? String {
            guard let source = generatedGradients[name]
            else { throw ContractFailure(description: "Unknown generated gradient") }
            return try gradient(source.colors.map { try Paint(color: $0) })
        }
        guard let bgName = recipe["background"] as? String, let fgName = recipe["over"] as? String else {
            throw ContractFailure(description: "Invalid composite recipe")
        }
        var opacity: Double?
        if let value = recipe["alpha"] {
            opacity = try alpha(number(value))
        }
        if let source = recipe["alphaSource"] as? String {
            try require(["status", "info"].contains(source), "Unknown container alpha")
            opacity =
                try alpha(Double(source == "status" ? FWTokens.Alpha.statusContainer : FWTokens.Alpha.infoContainer))
        }
        return try resolve(bgName, visiting: next).flatMap { background in
            try require(background.alpha == 1, "Nonopaque backdrop")
            return try resolve(fgName, visiting: next).map { front in
                var foreground = front; foreground.alpha = opacity ?? foreground.alpha
                return Paint(rgb: over(foreground, background))
            }
        }
    }

    func checkPairs() throws -> [Object] {
        try require(model.groups.count == 33, "Empty or incomplete pair inventory")
        var ids = Set<String>(), rows = [Object]()
        for group in model.groups {
            guard let id = group["id"] as? String, let kind = group["kind"] as? String,
                  let front = group["foregrounds"] as? [String], let back = group["backgrounds"] as? [String] else {
                throw ContractFailure(description: "Malformed pair")
            }
            try require(ids.insert(id).inserted && !front.isEmpty && !back.isEmpty, "Duplicate/empty pair")
            try require(["text", "nonText"].contains(kind), "Unknown threshold kind")
            let minimum = kind == "text" ? 4.5 : 3
            try require(number(group["minimum"]) == minimum, "Weakened threshold")
            for foreground in front {
                for background in back {
                    let foregrounds = try resolve(foreground), backgrounds = try resolve(background)
                    try require(!foregrounds.isEmpty && !backgrounds.isEmpty, "Empty variants")
                    var worst = Double.infinity, count = 0
                    for background in backgrounds {
                        try require(background.alpha == 1, "Nonopaque pair background")
                        for foreground in foregrounds {
                            let ratio = contrast(over(foreground, background), background.rgb)
                            try require(
                                ratio >= minimum,
                                "\(id): \(foreground)/\(background) ratio \(ratio) < \(minimum)"
                            )
                            worst = min(worst, ratio); count += 1
                        }
                    }
                    rows.append(["group": id, "foreground": foreground, "background": background, "highContrast": high,
                                 "byteAlpha": byteAlpha, "ratio": worst, "variants": count])
                }
            }
        }
        try require(rows.count == 172, "Missing/extra pair combination")
        return rows
    }
}

private func gradient(_ stops: [Paint]) throws -> [Paint] {
    try require(stops.count >= 2 && stops.allSatisfy { $0.alpha == 1 }, "Invalid opaque gradient")
    var output = Set<Paint>()
    for (first, second) in zip(stops, stops.dropFirst()) {
        var positions: Set<Double> = [0, 1]
        for channel in 0 ..< 3 {
            let low = Int(min(first.rgb[channel], second.rgb[channel])), high = Int(max(
                first.rgb[channel],
                second.rgb[channel]
            ))
            for value in low ..< high {
                let position = (Double(value) + 0.5 - first.rgb[channel]) / (second.rgb[channel] - first.rgb[channel])
                positions.formUnion([position, max(0, position - 1e-10), min(1, position + 1e-10)])
            }
        }
        for position in positions {
            output
                .insert(Paint(rgb: (0 ..< 3)
                        .map { (first.rgb[$0] + (second.rgb[$0] - first.rgb[$0]) * position).rounded() }))
        }
    }
    return Array(output)
}

private func over(_ foreground: Paint, _ background: Paint) -> [Double] {
    (0 ..< 3).map { (foreground.rgb[$0] * foreground.alpha + background.rgb[$0] * (1 - foreground.alpha)).rounded() }
}

private func linear(_ channel: Double) -> Double {
    channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
}

private func contrast(_ first: [Double], _ second: [Double]) -> Double {
    func luminance(_ rgb: [Double]) -> Double {
        zip(rgb, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + linear($1.0 / 255) * $1.1 }
    }
    let firstValue = luminance(first), secondValue = luminance(second)
    return (max(firstValue, secondValue) + 0.05) / (min(firstValue, secondValue) + 0.05)
}

private func deltaE(_ first: [Double], _ second: [Double], _ simulation: String) throws -> Double {
    let matrices = [
        "protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
        "deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
    ]
    guard let matrix = matrices[simulation] else { throw ContractFailure(description: "Unknown CVD simulation") }
    func lab(_ rgb: [Double]) -> [Double] {
        let channels = rgb.map { linear($0 / 255) }
        let transformed = matrix.map { row in min(1, max(0, zip(row, channels).reduce(0) { $0 + $1.0 * $1.1 })) }
        let red = transformed[0], green = transformed[1], blue = transformed[2]
        func f(_ value: Double) -> Double {
            value > 0.008856 ? pow(value, 1 / 3) : 7.787 * value + 16 / 116
        }
        let firstValue = f((0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047)
        let secondValue = f(0.2126 * red + 0.7152 * green + 0.0722 * blue)
        let thirdValue = f((0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883)
        return [116 * secondValue - 16, 500 * (firstValue - secondValue), 200 * (secondValue - thirdValue)]
    }
    return sqrt(zip(lab(first), lab(second)).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
