import BigInt
import Foundation
import SSFModels
import SSFUtils

/// What the confirmation shows for a Substrate call it has no specific view for: the call, a summary of every call it
/// carries, then every argument as the runtime decoded it. Nested calls (`Utility.batch*`, `Proxy.*`, `Multisig.*`,
/// `Sudo.*` and any other call that carries calls) are numbered and shown with their own arguments, multi-address
/// accounts in the chain's address format, and `Balances` amounts in the chain's native asset.
///
/// Nothing is cut. A call too large or too deeply nested to show in full is declined before the confirmation opens
/// (`fits(_:)`, checked by the request preparer with the same formatting).
struct WalletConnectSubstrateCallText {
    typealias Row = WalletConnectConfirmationViewModel.Row

    /// The most the confirmation shows: longer text, deeper nesting or more calls are declined.
    static let maxLength = 60000
    static let maxDepth = 24
    static let maxCalls = 100
    /// The longest single value shown in full, such as a remark or a runtime blob; a longer one shows its start and
    /// how long it is.
    static let maxValueLength = 512

    /// The account's address on the chain, or nil to show the raw id.
    let address: (AccountId) -> String?
    /// A native-asset amount with its symbol, or nil to show the raw number.
    let nativeAmount: (BigUInt) -> String?

    /// The text as the confirmation shows it on `chain`: addresses in its format, amounts in its native asset.
    static func make(
        chain: ChainModel,
        locale: Locale,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) -> WalletConnectSubstrateCallText {
        let asset = chain.utilityAssets().first
        return WalletConnectSubstrateCallText(
            address: { accountId in try? AddressFactory.address(for: accountId, chain: chain) },
            nativeAmount: { amount in
                guard
                    let asset = asset,
                    let decimal = Decimal.fromSubstrateAmount(amount, precision: Int16(bitPattern: asset.precision))
                else {
                    return nil
                }
                let formatter = formatterFactory.createTokenFormatter(
                    for: asset.displayInfo,
                    usageCase: .exactCrypto(fractionDigits: Int(asset.precision))
                )
                return formatter.value(for: locale).stringFromDecimal(decimal)
            }
        )
    }

    func rows(for call: RuntimeCall<JSON>, locale: Locale) -> [Row] {
        let languages = locale.rLanguages
        var rows = [
            Row(
                kind: .call,
                title: R.string.localizable.walletConnectConfirmationCall(preferredLanguages: languages),
                value: "\(call.moduleName).\(call.callName)"
            )
        ]

        let summary = summaryLines(for: call)
        if !summary.isEmpty {
            rows.append(Row(
                kind: .calls,
                title: R.string.localizable.walletConnectConfirmationCalls(preferredLanguages: languages),
                value: summary.joined(separator: "\n")
            ))
        }

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

    /// Whether the confirmation can show the call in full.
    func fits(_ call: RuntimeCall<JSON>) -> Bool {
        var lines = Lines()
        renderArguments(call.args, module: call.moduleName, indent: 0, depth: 0, into: &lines)
        let summary = summaryLines(for: call).joined(separator: "\n")
        return lines.length + summary.count <= Self.maxLength
            && lines.deepest <= Self.maxDepth
            && Self.innerCalls(of: call).count <= Self.maxCalls
    }

    // MARK: - Summary

    /// One line per kind of call the call carries, at any depth, and per account it names: how many there are and
    /// what they move. Calls that move funds or act for another account come first, the rarer ones first, then the
    /// larger amounts, so a single unusual call cannot hide behind many ordinary ones.
    func summaryLines(for call: RuntimeCall<JSON>) -> [String] {
        let calls = Self.innerCalls(of: call)
        guard !calls.isEmpty else {
            return []
        }

        var groups: [CallGroup] = []
        for (order, inner) in calls.enumerated() {
            let accounts = accountTexts(in: inner.args)
            let asset = Self.assetText(in: inner.args)
            let key = [inner.name, accounts.joined(separator: ", "), asset ?? ""]
            if let index = groups.firstIndex(where: { $0.key == key }) {
                groups[index].add(amount: Self.amount(in: inner.args))
            } else {
                var group = CallGroup(
                    key: key,
                    name: inner.name,
                    accounts: accounts,
                    asset: asset,
                    module: inner.module,
                    movesFunds: Self.movesFunds(inner) || !accounts.isEmpty,
                    firstSeen: order
                )
                group.add(amount: Self.amount(in: inner.args))
                groups.append(group)
            }
        }

        let callsPerName = Dictionary(calls.map { ($0.name, 1) }, uniquingKeysWith: +)
        groups.sort { lhs, rhs in
            if lhs.movesFunds != rhs.movesFunds {
                return lhs.movesFunds
            }
            let lhsUses = callsPerName[lhs.name] ?? 0
            let rhsUses = callsPerName[rhs.name] ?? 0
            if lhsUses != rhsUses {
                return lhsUses < rhsUses
            }
            if lhs.name == rhs.name, let lhsTotal = lhs.total, let rhsTotal = rhs.total, lhsTotal != rhsTotal {
                return lhsTotal > rhsTotal
            }
            return lhs.firstSeen < rhs.firstSeen
        }

        return groups.map { group in
            var line = "\(group.count) × \(group.name)"
            if let asset = group.asset {
                line += " (\(asset))"
            }
            if !group.accounts.isEmpty {
                line += " → " + group.accounts.joined(separator: ", ")
            }
            if let total = group.total {
                line += ": " + amountText(total, module: group.module)
            }
            return line
        }
    }

    private struct CallGroup {
        let key: [String]
        let name: String
        let accounts: [String]
        let asset: String?
        let module: String
        let movesFunds: Bool
        let firstSeen: Int
        private(set) var count = 0
        /// The amounts added up, while every call of the group names one.
        private(set) var total: BigUInt? = 0

        init(
            key: [String],
            name: String,
            accounts: [String],
            asset: String?,
            module: String,
            movesFunds: Bool,
            firstSeen: Int
        ) {
            self.key = key
            self.name = name
            self.accounts = accounts
            self.asset = asset
            self.module = module
            self.movesFunds = movesFunds
            self.firstSeen = firstSeen
        }

        mutating func add(amount: BigUInt?) {
            count += 1
            if let amount = amount, let sum = total {
                total = sum + amount
            } else {
                total = nil
            }
        }
    }

    private func amountText(_ amount: BigUInt, module: String) -> String {
        guard module == "Balances", let shown = nativeAmount(amount) else {
            return String(amount)
        }
        return shown
    }

    /// The accounts a call's own arguments name (not those of calls inside it), in argument order.
    private func accountTexts(in args: JSON) -> [String] {
        guard case let .dictionaryValue(fields) = args else {
            return []
        }
        var accounts: [String] = []
        for name in fields.keys.sorted() {
            guard let value = fields[name], Self.call(in: value) == nil, Self.calls(in: value) == nil else {
                continue
            }
            collectAccounts(in: value, into: &accounts)
        }
        return accounts
    }

    private func collectAccounts(in value: JSON, into accounts: inout [String]) {
        switch value {
        case let .arrayValue(items):
            if let account = multiAddressAccount(items) {
                if !accounts.contains(account) {
                    accounts.append(account)
                }
                return
            }
            items.forEach { collectAccounts(in: $0, into: &accounts) }
        case let .dictionaryValue(fields):
            fields.keys.sorted().compactMap { fields[$0] }.forEach { collectAccounts(in: $0, into: &accounts) }
        default:
            break
        }
    }

    private static let amountArguments = ["value", "amount"]
    private static let assetArguments = ["id", "asset_id", "currency_id", "asset"]

    private static func amount(in args: JSON) -> BigUInt? {
        guard case let .dictionaryValue(fields) = args else {
            return nil
        }
        for name in amountArguments {
            switch fields[name] {
            case let .stringValue(text)?:
                return BigUInt(text)
            case let .unsignedIntValue(number)?:
                return BigUInt(number)
            default:
                continue
            }
        }
        return nil
    }

    private static func assetText(in args: JSON) -> String? {
        guard case let .dictionaryValue(fields) = args else {
            return nil
        }
        for name in assetArguments {
            if let value = fields[name] {
                return "\(name): \(compactText(value))"
            }
        }
        return nil
    }

    private static func compactText(_ value: JSON) -> String {
        switch value {
        case let .stringValue(text):
            return capped(text)
        case let .unsignedIntValue(number):
            return String(number)
        case let .signedIntValue(number):
            return String(number)
        default:
            let encoded = (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
            return capped(encoded ?? String(describing: value))
        }
    }

    private static let fundKeywords = [
        "transfer", "teleport", "reserve", "withdraw", "approve", "proxy", "dispatch", "sudo", "derivative", "multi",
        "recover", "bond", "payee", "vest", "swap", "send", "execute", "force", "kill", "claim", "exchange", "deposit"
    ]

    private static let fundModules: Set<String> = ["Balances", "Proxy", "Multisig", "Sudo", "Recovery"]

    /// Calls that move funds or let someone act for the account.
    private static func movesFunds(_ call: DecodedCall) -> Bool {
        if fundModules.contains(call.module) {
            return true
        }
        let name = call.callName.lowercased()
        return fundKeywords.contains { name.contains($0) }
    }

    /// Every call the call carries, at any depth, in order.
    static func innerCalls(of call: RuntimeCall<JSON>) -> [DecodedCall] {
        var found: [DecodedCall] = []
        collectCalls(in: call.args, into: &found)
        return found
    }

    private static func collectCalls(in value: JSON, into found: inout [DecodedCall]) {
        if let call = call(in: value) {
            found.append(call)
            collectCalls(in: call.args, into: &found)
            return
        }
        switch value {
        case let .arrayValue(items):
            items.forEach { collectCalls(in: $0, into: &found) }
        case let .dictionaryValue(fields):
            fields.keys.sorted().compactMap { fields[$0] }.forEach { collectCalls(in: $0, into: &found) }
        default:
            break
        }
    }

    // MARK: - Rendering

    struct DecodedCall {
        let module: String
        let callName: String
        let args: JSON

        var name: String {
            "\(module).\(callName)"
        }
    }

    private struct Lines {
        private(set) var lines: [String] = []
        private(set) var length = 0
        private(set) var deepest = 0

        mutating func append(_ line: String, indent: Int, depth: Int) {
            let text = String(repeating: " ", count: indent) + line
            lines.append(text)
            length += text.count + 1
            deepest = max(deepest, depth)
        }

        var text: String {
            lines.joined(separator: "\n")
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
        if let calls = Self.calls(in: value) {
            lines.append("\(name):", indent: indent, depth: depth)
            for (index, call) in calls.enumerated() {
                renderCall(call, number: index + 1, indent: indent + 2, depth: depth + 1, into: &lines)
            }
        } else if let call = Self.call(in: value) {
            lines.append("\(name): \(call.name)", indent: indent, depth: depth)
            renderArguments(call.args, module: call.module, indent: indent + 2, depth: depth + 1, into: &lines)
        } else if let inline = inlineText(value, field: name, module: module) {
            lines.append("\(name): \(inline)", indent: indent, depth: depth)
        } else {
            lines.append("\(name):", indent: indent, depth: depth)
            renderValue(value, module: module, indent: indent + 2, depth: depth + 1, into: &lines)
        }
    }

    private func renderCall(_ call: DecodedCall, number: Int, indent: Int, depth: Int, into lines: inout Lines) {
        let prefix = "\(number). "
        lines.append(prefix + call.name, indent: indent, depth: depth)
        renderArguments(call.args, module: call.module, indent: indent + prefix.count, depth: depth + 1, into: &lines)
    }

    private func renderValue(_ value: JSON, module: String, indent: Int, depth: Int, into lines: inout Lines) {
        if let inline = inlineText(value, field: nil, module: module) {
            lines.append(inline, indent: indent, depth: depth)
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
                lines.append(call.name, indent: indent, depth: depth)
                renderArguments(call.args, module: call.module, indent: indent + 2, depth: depth + 1, into: &lines)
            } else if items.count == 2, case let .stringValue(caseName) = items[0], Self.isCaseName(caseName) {
                // An enum value whose case carries parts.
                lines.append("\(caseName):", indent: indent, depth: depth)
                renderValue(items[1], module: module, indent: indent + 2, depth: depth + 1, into: &lines)
            } else {
                for (index, item) in items.enumerated() {
                    let prefix = "\(index + 1). "
                    if let inline = inlineText(item, field: nil, module: module) {
                        lines.append(prefix + inline, indent: indent, depth: depth)
                    } else {
                        lines.append(prefix.trimmingCharacters(in: .whitespaces), indent: indent, depth: depth)
                        renderValue(item, module: module, indent: indent + prefix.count, depth: depth + 1, into: &lines)
                    }
                }
            }
        default:
            lines.append(String(describing: value), indent: indent, depth: depth)
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
            if let numbers = Self.numberList(items) {
                // Bytes (`Vec<u8>`, such as a remark) and other lists of numbers, on one line.
                return numbers
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

    /// A call as the runtime decodes it: `[Module, [call_name, {arguments}]]`. Module names are capitalised and call
    /// names are not, which tells a call from an enum value of the same shape.
    static func call(in value: JSON) -> DecodedCall? {
        guard
            case let .arrayValue(outer) = value,
            outer.count == 2,
            case let .stringValue(module) = outer[0],
            isCaseName(module),
            case let .arrayValue(inner) = outer[1],
            inner.count == 2,
            case let .stringValue(name) = inner[0],
            let first = name.unicodeScalars.first,
            CharacterSet.lowercaseLetters.contains(first),
            case .dictionaryValue = inner[1]
        else {
            return nil
        }
        return DecodedCall(module: module, callName: name, args: inner[1])
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

    /// "[1, 2, 3]" for a list of plain numbers; a longer one shows its start and how many numbers it has.
    private static func numberList(_ items: [JSON]) -> String? {
        var numbers: [String] = []
        for item in items {
            switch item {
            case let .stringValue(text) where isDigits(text):
                numbers.append(text)
            case let .unsignedIntValue(number):
                numbers.append(String(number))
            default:
                return nil
            }
        }
        let text = "[" + numbers.joined(separator: ", ") + "]"
        guard text.count > maxValueLength else {
            return text
        }
        return "\(text.prefix(maxValueLength))… (\(numbers.count) numbers)"
    }

    private static func isDigits(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { ("0" ... "9").contains($0) }
    }

    private static func capped(_ text: String) -> String {
        guard text.count > maxValueLength else {
            return text
        }
        return "\(text.prefix(maxValueLength))… (\(text.count) characters)"
    }
}
