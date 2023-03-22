#!/usr/bin/env xcrun --sdk macosx swift

import Foundation
import CoreGraphics


// Models
struct Config: Decodable {
    let foundationColors: FoundationColors
    let typographyMobile: TypographyMobile
    let lightTheme: FoundationColors
    let darkTheme: FoundationColors
    let cornerRadius: BorderRadius

    enum CodingKeys: String, CodingKey {
        case foundationColors = "Foundation Colors"
        case typographyMobile = "Typography Mobile"
        case darkTheme = "Night Theme"
        case lightTheme = "Day Theme"
        case cornerRadius = "Border Radius"
    }
}

struct FoundationColors: Decodable {
    let colors: [String: [String: ValueContainer<String>]]

    enum CodingKeys: String, CodingKey {
        case colors = "Color"
    }
}

struct TypographyMobile: Decodable {
    let font: [String: AnyDecodable]

    enum CodingKeys: String, CodingKey {
        case font = "Font"
    }
}

struct BorderRadius: Decodable {
    let borderRadiuses: [String: ValueContainer<String>]

    enum CodingKeys: String, CodingKey {
        case borderRadiuses = "BorderRadius"
    }
}

struct AnyDecodable: Decodable {
    
    let value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    public init(from decoder :Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let dict = try? container.decode([String: String].self) {
            self.init(dict)
        } else if let anyDict = try? container.decode([String: AnyDecodable].self) {
            self.init(anyDict)
        } else {
            self.init(())
        }
    }
}

struct ValueContainer<T: Codable>: Codable {
    let value: T
}

// Colors
func hexStringToUInt32(_ hex: String) -> UInt32 {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }
    
    if ((cString.count) != 6) {
        return 0
    }
    
    var rgbValue:UInt32 = 0
    Scanner(string: cString).scanHexInt32(&rgbValue)
    return rgbValue
}

func redFromHex(_ hexColor: String) -> CGFloat {
    return CGFloat((hexStringToUInt32(hexColor) & 0xFF0000) >> 16) / 255.0
}

func greenFromHex(_ hexColor: String) -> CGFloat {
    return CGFloat((hexStringToUInt32(hexColor) & 0x00FF00) >> 8) / 255.0
}

func blueFromHex(_ hexColor: String) -> CGFloat {
    return CGFloat(hexStringToUInt32(hexColor) & 0x0000FF) / 255.0
}

func createPaletteEnum(paletteColors: [String: String]) -> String {
    let colorLines = paletteColors.map { arg -> (String) in
        let (name, hex) = arg
        return "\tpublic static let \(name): UIColor = UIColor(red: \(redFromHex(hex)), green: \(greenFromHex(hex)), blue: \(blueFromHex(hex)), alpha: 1.0)"
    }.joined(separator: "\n")

    return """
    public enum Colors {
    \(colorLines)
    }
    """
}

func createThemeEnum(fileName: String, theme: [String: String]) -> String {
    let colorLines = theme.map { arg -> (String) in
        let color = arg.value.split(separator: ".").suffix(2).joined(separator:"").lowercased()
        return "\t\tcase .\(arg.key): return Colors.\(color)"
    }.joined(separator: "\n")

    return """
    final class \(fileName): Palette {\n\tfunc color(_ color: SoramitsuColor) -> UIColor {\n\t\tswitch color {\n\t\tcase let .custom(uiColor): return uiColor\n\t\t
    \(colorLines)
    \t\tdefault: return .black
    \t\t}
    \t}
    }
    """
}

func createColorSetText(fileName: String, colorNames: [String]) -> String {
    let colorLines = colorNames.map { arg -> (String) in
        return "\tcase \(arg)"
    }.joined(separator: "\n")

    return """
    public enum \(fileName) {\n\n\tcase custom(uiColor: UIColor)\n
    \(colorLines)
    }
    """
}

func createCornerRadiusesEnum(radiuses: [String: ValueContainer<String>]) -> String {
    let colorLines = radiuses.map { arg -> (String) in
        return "\tpublic static let \(arg.key): CGFloat = \(arg.value.value)"
    }.joined(separator: "\n")

    return """
    public enum CornerRadius {
    \(colorLines)
    }
    """
}

func createPaletteColors(config: Config) -> [String: String] {
    var paletteColors: [String: String] = [:]

    for (globalKey, colorPallet) in config.foundationColors.colors {
        for (defeniteColorKey, colorHex) in colorPallet {
            paletteColors[globalKey.lowercased() + defeniteColorKey] = colorHex.value
        }
    }
    
    return paletteColors
}

func createThemeColors(theme: FoundationColors) -> [String: String] {
    var paletteColors: [String: String] = [:]

    for (globalKey, colorPallet) in theme.colors {
        for (defeniteColorKey, colorHex) in colorPallet {
            paletteColors[globalKey.lowercased() + defeniteColorKey] = colorHex.value
        }
    }

    return paletteColors
}


func pathForFileWith(name: String, parentDirectory: String) -> String? {
    guard let relativePath = FileManager.default.subpaths(atPath: parentDirectory)?.first(where: { $0.hasSuffix(name) })
        else { return nil }
    return [parentDirectory, relativePath].joined(separator: "/")
}

fileprivate extension String {
    func writeFile(to path: String, name: String) throws {
        try write(toFile: [path, name.appending(".swift")].joined(separator: "/"), atomically: true, encoding: .utf8)
    }
}

func generateEnumFile(name: String, path: String, paletteColors: [String: String]) throws {
    var fileString = """
    import UIKit

    // #codegen\n
    """
    fileString.append(createPaletteEnum(paletteColors: paletteColors))

    try fileString.writeFile(to: path, name: name)
}

func generateThemeEnumFile(name: String, path: String, theme: [String: String]) throws {
    var fileString = """
    import UIKit

    // #codegen\n
    """
    fileString.append(createThemeEnum(fileName: name, theme: theme))

    try fileString.writeFile(to: path, name: name)
}

func generateColorSetFile(name: String, path: String, colorNames: [String]) throws {
    var fileString = """
    import UIKit

    // #codegen\n
    """
    fileString.append(createColorSetText(fileName: name, colorNames: colorNames))

    try fileString.writeFile(to: path, name: name)
}

// Fonts
func generateFontsFile(path: String, code: [String]) throws {
    var fileString = """
    import Foundation

    // #codegen\n
    """
    code.forEach {
        fileString.append($0)
    }

    try fileString.writeFile(to: path, name: "Fonts")
}

// Corner radiuses
func generateCornerRadiusesFile(path: String, radiuses: [String: ValueContainer<String>]) throws {
    var fileString = """
    import UIKit

    // #codegen\n
    """
    fileString.append(createCornerRadiusesEnum(radiuses: radiuses))

    try fileString.writeFile(to: path, name: "CornerRadius")
}

func generateFontProperties(propertyName: String, cases: [String: AnyDecodable]?) -> String {
    guard let caseLines = cases?.map { (name, value) -> (String) in
        
        guard let dictValue = (value.value as? [String: String])?["value"] else { return "FAIL!!" }
        
        return "\tcase \(name.lowercased()) = \"\(dictValue)\""
    }.joined(separator: "\n") else { return "FAIL!!" }

    return """
    enum \(propertyName): String, CaseIterable {
    \(caseLines)
    }\n\n
    """
}

func generateFontParametrs(fonts: [String: String]?) -> String? {
    return (fonts?.filter { !["textCase", "textDecoration"].contains($0.key) })?.sorted(by: { $0.0 < $1.0 }).map { (fontKey, font) -> (String) in
        
        var fontValue = font
        
        if fontKey == "fontFamily" || fontKey == "fontWeight" {
            fontValue = "." + (font.components(separatedBy: ".").last ?? "").lowercased()
        }
        
        if fontKey == "letterSpacing" {
            if let i = fontValue.firstIndex(of: "%") {
                fontValue.remove(at: i)
                fontValue = "\((Double(fontValue) ?? 0) / 100)"
            }
        }
        
        return "\(fontKey): \(fontValue)"
    }.joined(separator: ",\n\t\t\t\t\t\t\t\t\t\t\t\t")
}

func generateFonts(fonts: [String: AnyDecodable]) -> String {
    let caseLines = fonts.map { (name, value) -> (String) in
        
        let dictFontValue = value.value as? [String: AnyDecodable]
        
        let fontsCode = dictFontValue?.map { (fontName, fontValue) -> (String) in
            
            let propertiesDict = fontValue.value as? [String: AnyDecodable]
            let valuePropertiesDict = propertiesDict?["value"]?.value as? [String: String]
            
            if let properties = generateFontParametrs(fonts: valuePropertiesDict) {
                return "\tpublic static let \(name.lowercased() + fontName): FontData = FontData(" + properties + ")"
            }
            
            let finalString = propertiesDict?.map { (finalFontName, finalFontValue) -> (String) in

                let finalPropertiesDict = ((finalFontValue.value as? [String: AnyDecodable])?["value"])?.value as? [String: String]

                let properties = generateFontParametrs(fonts: finalPropertiesDict) ?? ""
                
                return "\tpublic static let \(name.lowercased() + fontName + finalFontName): FontData = FontData(" + properties + ")"
                
            }.joined(separator: "\n\n") ?? ""
            
            return finalString
            
        }.joined(separator: "\n\n") ?? ""
        
        return fontsCode
    }.joined(separator: "\n\n")

    return """
    public enum FontType {
    \(caseLines)
    }
    """
}

// Check arguments
guard CommandLine.arguments.count == 3 else { fatalError(("Not enough arguments")) }

// Path to JSON file
let paletteFilePath = CommandLine.arguments[1]

// Check JSON file
guard let data = FileManager.default.contents(atPath: paletteFilePath) else { fatalError("File at path '\(paletteFilePath)' not found") }

// Decode config
guard let config = try? JSONDecoder().decode(Config.self, from: data) else { fatalError("Palette Input has wrong format") }

// Create dictinary of colors
var paletteColors = createPaletteColors(config: config)

// Path to Codegen file
let generateFilePath = CommandLine.arguments[2]

// Check Codegen dictinary
guard let codegenDirectory = pathForFileWith(name: "Codegen", parentDirectory: generateFilePath) else { fatalError("No codegen dir") }

// Generating Colors.swift
try generateEnumFile(name: "Colors", path: codegenDirectory, paletteColors: paletteColors)

// Filtring font properties from config
let fontProperties = config.typographyMobile.font.filter { ["FontFamily", "FontWeight", "LineHeights"].contains($0.key) }

var fontsStrings: [String] = []

// Creating properties enum of fonts
for property in fontProperties {
    fontsStrings.append(generateFontProperties(propertyName: property.key, cases: property.value.value as? [String: AnyDecodable]))
}

// Creating fonts code
let fonts = config.typographyMobile.font.filter { !(["FontFamily", "FontWeight", "LineHeights"].contains($0.key)) }
fontsStrings.append(generateFonts(fonts: fonts))

// Creating fonts file
try generateFontsFile(path: codegenDirectory, code: fontsStrings)

// Creating light theme code
let lightTheme = createThemeColors(theme: config.lightTheme)

// Generating LightTheme.swift
try generateThemeEnumFile(name: "LightPalette", path: codegenDirectory, theme: lightTheme)

// Creating dark theme code
let darkTheme = createThemeColors(theme: config.darkTheme)

// Generating DarkTheme.swift
try generateThemeEnumFile(name: "DarkPalette", path: codegenDirectory, theme: darkTheme)

// Generate Color.swift
try generateColorSetFile(name: "SoramitsuColor", path: codegenDirectory, colorNames: Array(lightTheme.keys))

// Creating corner radiuses code
let cornerRadiuses = config.cornerRadius.borderRadiuses

// Creating corner radiuses file
try generateCornerRadiusesFile(path: codegenDirectory, radiuses: cornerRadiuses)

exit(0)
