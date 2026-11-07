import BigInt
import Foundation
import SSFUtils

/// What the confirmation shows for a Substrate call it has no specific view for: the call, then every argument
/// as the runtime decoded it. Nested calls (`Utility.batch*`, `Proxy.*`, `Multisig.*`, `Sudo.*` and any other
/// call that carries calls) are numbered and shown with their own arguments, multi-address accounts in the
/// chain's address format, and `Balances` amounts in the chain's native asset.
struct WalletConnectSubstrateCallText {
    typealias Row = WalletConnectConfirmationViewModel.Row

    /// The longest text shown; a longer call ends in "…". Long enough for a batch of 100 transfers.
    static let maxLength = 20000
    /// The deepest nesting shown; deeper calls end in "…".
    static let maxDepth = 16
    /// The longest single value shown, such as a remark or a runtime blob; the rest is counted.
    static let maxValueLength = 512

    /// The account's address on the chain, or nil to show the raw id.
    let address: (AccountId) -> String?
    /// A native-asset amount with its symbol, or nil to show the raw number.
    let nativeAmount: (BigUInt) -> String?

    func rows(for call: RuntimeCall<JSON>, locale: Locale) -> [Row] {
        let languages = locale.rLanguages
        var rows = [
            Row(
                kind: .call,
                title: R.string.localizable.walletConnectConfirmationCall(preferredLanguages: languages),
                value: "\(call.moduleName).\(call.callName)"
            )
        ]

        let arguments = text(forArgumentsOf: call)
        if !arguments.isEmpty {
            rows.append(Row(
                kind: .arguments,
                title: R.string.localizable.walletConnectConfirmationArguments(preferredLanguages: languages),
                value: arguments
            ))
        }
        return rows
    }

    /// The call's arguments, one per line, nested values indented.
    func text(forArgumentsOf call: RuntimeCall<JSON>) -> String {
        var lines = Lines()
        renderArguments(call.args, module: call.moduleName, indent: 0, depth: 0, into: &lines)
        return lines.text
    }

    // MARK: - Rendering

    private struct DecodedCall {
        let module: String
        let name: String
        let args: JSON
    }

    private struct Lines {
        private(set) var lines: [String] = []
        private var length = 0
        private(set) var isTruncated = false

        mutating func append(_ line: String, indent: Int) {
            guard !isTruncated else {
                return
            }
            let text = String(repeating: " ", count: indent) + line
            guard length + text.count <= WalletConnectSubstrateCallText.maxLength else {
                isTruncated = true
                return
            }
            lines.append(text)
            length += text.count + 1
        }

        mutating func truncate() {
            isTruncated = true
        }

        var text: String {
            (lines + (isTruncated ? ["…"] : [])).joined(separator: "\n")
        }
    }

    private func renderArguments(_ args: JSON, module: String, indent: Int, depth: Int, into lines: inout Lines) {
        guard case let .dictionaryValue(fields) = args else {
            renderValue(args, module: module, indent: indent, depth: depth, into: &lines)
            return
        }
        for name in fields.keys.sorted() {
            if let value = fields[name] {
                renderField(name, value: value, module: module, indent: indent, depth: depth, into: &lines)
            }
        }
    }

    private func renderField(
        _ name: String,
        value: JSON,
        module: String,
        indent: Int,
        depth: Int,
        into lines: inout Lines
    ) {
        guard depth <= Self.maxDepth else {
            lines.truncate()
            return
        }

        if let calls = Self.calls(in: value) {
            lines.append("\(name):", indent: indent)
            for (index, call) in calls.enumerated() {
                renderCall(call, number: index + 1, indent: indent + 2, depth: depth + 1, into: &lines)
            }
        } else if let call = Self.call(in: value) {
            lines.append("\(name): \(call.module).\(call.name)", indent: indent)
            renderArguments(call.args, module: call.module, indent: indent + 2, depth: depth + 1, into: &lines)
        } else if let inline = inlineText(value, field: name, module: module) {
            lines.append("\(name): \(inline)", indent: indent)
        } else {
            lines.append("\(name):", indent: indent)
            renderValue(value, module: module, indent: indent + 2, depth: depth + 1, into: &lines)
        }
    }

    private func renderCall(_ call: DecodedCall, number: Int, indent: Int, depth: Int, into lines: inout Lines) {
        let prefix = "\(number). "
        lines.append(prefix + "\(call.module).\(call.name)", indent: indent)
        renderArguments(call.args, module: call.module, indent: indent + prefix.count, depth: depth + 1, into: &lines)
    }

    private func renderValue(_ value: JSON, module: String, indent: Int, depth: Int, into lines: inout Lines) {
        guard depth <= Self.maxDepth else {
            lines.truncate()
            return
        }

        if let inline = inlineText(value, field: nil, module: module) {
            lines.append(inline, indent: indent)
            return
        }

        switch value {
        case .dictionaryValue:
            renderArguments(value, module: module, indent: indent, depth: depth, into: &lines)
        case let .arrayValue(items):
            if let calls = Self.calls(in: value) {
                for (index, call) in calls.enumerated() {
                    renderCall(call, number: index + 1, indent: indent, depth: depth + 1, into: &lines)
                }
            } else if let call = Self.call(in: value) {
                lines.append("\(call.module).\(call.name)", indent: indent)
                renderArguments(call.args, module: call.module, indent: indent + 2, depth: depth + 1, into: &lines)
            } else if items.count == 2, case let .stringValue(caseName) = items[0], Self.isCaseName(caseName) {
                // An enum value: its case, then what the case carries.
                if let payload = scalarText(items[1], field: nil, module: module) {
                    lines.append("\(caseName) \(payload)", indent: indent)
                } else {
                    lines.append("\(caseName):", indent: indent)
                    renderValue(items[1], module: module, indent: indent + 2, depth: depth + 1, into: &lines)
                }
            } else {
                for (index, item) in items.enumerated() {
                    let prefix = "\(index + 1). "
                    if let inline = inlineText(item, field: nil, module: module) {
                        lines.append(prefix + inline, indent: indent)
                    } else {
                        lines.append(prefix.trimmingCharacters(in: .whitespaces), indent: indent)
                        renderValue(item, module: module, indent: indent + prefix.count, depth: depth + 1, into: &lines)
                    }
                }
            }
        default:
            lines.append(String(describing: value), indent: indent)
        }
    }

    /// A value shown on one line: a scalar, or an enum case with a scalar payload ("Index 5"). Nil for one with parts.
    private func inlineText(_ value: JSON, field: String?, module: String) -> String? {
        if let scalar = scalarText(value, field: field, module: module) {
            return scalar
        }
        guard
            case let .arrayValue(items) = value,
            items.count == 2,
            case let .stringValue(caseName) = items[0],
            Self.isCaseName(caseName),
            let payload = scalarText(items[1], field: field, module: module)
        else {
            return nil
        }
        return "\(caseName) \(payload)"
    }

    /// A value shown on one line, or nil for one with parts.
    private func scalarText(_ value: JSON, field: String?, module: String) -> String? {
        switch value {
        case let .stringValue(text):
            if module == "Balances", field == "value", let amount = BigUInt(text), let shown = nativeAmount(amount) {
                return shown
            }
            return Self.capped(text)
        case let .unsignedIntValue(number):
            if module == "Balances", field == "value", let shown = nativeAmount(BigUInt(number)) {
                return shown
            }
            return String(number)
        case let .signedIntValue(number):
            return String(number)
        case let .doubleValue(number):
            return String(number)
        case let .boolValue(flag):
            return flag ? "true" : "false"
        case .null:
            return "None"
        case let .arrayValue(items):
            if items.isEmpty {
                return "[]"
            }
            if let account = multiAddressAccount(items) {
                return account
            }
            if items.count == 2, case let .stringValue(caseName) = items[0], Self.isCaseName(caseName),
               case .null = items[1] {
                return caseName
            }
            return nil
        case let .dictionaryValue(fields):
            return fields.isEmpty ? "{}" : nil
        }
    }

    /// A `MultiAddress::Id` or `Address32` account in the chain's format; the other cases are shown as decoded.
    private func multiAddressAccount(_ items: [JSON]) -> String? {
        guard
            items.count == 2,
            case let .stringValue(caseName) = items[0],
            caseName == "Id" || caseName == "Address32",
            case let .stringValue(hex) = items[1],
            let accountId = try? Data(hexStringSSF: hex),
            accountId.count == 32
        else {
            return nil
        }
        return address(accountId) ?? hex
    }

    private static func call(in value: JSON) -> DecodedCall? {
        guard
            case let .arrayValue(outer) = value,
            outer.count == 2,
            case let .stringValue(module) = outer[0],
            case let .arrayValue(inner) = outer[1],
            inner.count == 2,
            case let .stringValue(name) = inner[0],
            case .dictionaryValue = inner[1]
        else {
            return nil
        }
        return DecodedCall(module: module, name: name, args: inner[1])
    }

    private static func calls(in value: JSON) -> [DecodedCall]? {
        guard case let .arrayValue(items) = value, !items.isEmpty else {
            return nil
        }
        let calls = items.compactMap { call(in: $0) }
        return calls.count == items.count ? calls : nil
    }

    private static func isCaseName(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first else {
            return false
        }
        return CharacterSet.uppercaseLetters.contains(first)
            && text.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "_" }
    }

    private static func capped(_ text: String) -> String {
        guard text.count > maxValueLength else {
            return text
        }
        return "\(text.prefix(maxValueLength))… (\(text.count) characters)"
    }
}
