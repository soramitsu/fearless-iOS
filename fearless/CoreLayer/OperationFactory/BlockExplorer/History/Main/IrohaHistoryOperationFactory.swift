import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils

final class IrohaHistoryOperationFactory {
    static let paginationPageKey = "page"
    static let paginationTotalPagesKey = "total_pages"
    static let paginationTotalItemsKey = "total_items"
    static let maxPageSize = 100

    private let client: IrohaToriiClientProtocol

    init(client: IrohaToriiClientProtocol = IrohaToriiClient()) {
        self.client = client
    }

    static func supports(chain: ChainModel) -> Bool {
        network(for: chain) != nil
    }

    private static func network(for chain: ChainModel) -> UniversalWalletRegistry.IrohaNetwork? {
        switch chain.chainId {
        case UniversalWalletRegistry.taira.chainId:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId:
            return UniversalWalletRegistry.nexus
        default:
            return nil
        }
    }

    private func shouldFetch(filters: [WalletTransactionHistoryFilter]) -> Bool {
        filters.isEmpty || filters.contains { $0.type == .transfer && $0.selected }
    }

    private func historyBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
    }

    private func normalizedAddress(
        _ address: String,
        network: UniversalWalletRegistry.IrohaNetwork
    ) -> String? {
        try? IrohaAddressCodec.parse(address, expectedDiscriminant: network.chainDiscriminant).i105
    }

    private func createHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        address: String,
        pagination: Pagination
    ) -> BaseOperation<AssetTransactionPageData?> {
        AwaitOperation { [client] in
            try await self.fetchIrohaHistoryPage(
                client: client,
                asset: asset,
                chain: chain,
                network: network,
                address: address,
                pagination: pagination
            )
        }
    }

    private func fetchIrohaHistoryPage(
        client: IrohaToriiClientProtocol,
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        address: String,
        pagination: Pagination
    ) async throws -> AssetTransactionPageData {
        let page: Int
        let expectedTotalPages: Int64?
        let expectedTotalItems: Int64?
        if let context = pagination.context {
            guard Set(context.keys) == [
                Self.paginationPageKey,
                Self.paginationTotalPagesKey,
                Self.paginationTotalItemsKey
            ],
                let rawPage = context[Self.paginationPageKey],
                let parsedPage = Int(rawPage),
                parsedPage >= 1,
                let rawTotalPages = context[Self.paginationTotalPagesKey],
                let totalPages = Int64(rawTotalPages),
                totalPages <= Int64(Int.max),
                totalPages >= Int64(parsedPage),
                let rawTotalItems = context[Self.paginationTotalItemsKey],
                let totalItems = Int64(rawTotalItems),
                totalItems >= 1 else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_history_cursor")
            }
            page = parsedPage
            expectedTotalPages = totalPages
            expectedTotalItems = totalItems
        } else {
            page = 1
            expectedTotalPages = nil
            expectedTotalItems = nil
        }
        let limit = min(pagination.count, Self.maxPageSize)
        let canonicalAssetId: String
        do {
            canonicalAssetId = try IrohaToriiRoutes.normalizeAssetDefinitionId(asset.id)
        } catch {
            throw IrohaHistoryReadError.nonCanonicalAssetDefinition(asset.id)
        }
        let baseURL = historyBaseURL(for: chain)
        let definitions = try await client.assetDefinitions(
            baseURL: baseURL,
            limit: IrohaToriiRoutes.maxLimit,
            offset: 0,
            countMode: .bounded
        )
        guard !definitions.hasMore,
              definitions.countMode == IrohaToriiCountMode.bounded.rawValue else {
            throw IrohaHistoryReadError.truncatedDefinitions
        }
        var definitionsById: [String: IrohaAssetDefinitionListItem] = [:]
        for candidate in definitions.items {
            let id: String
            do {
                id = try IrohaToriiRoutes.normalizeAssetDefinitionId(candidate.id)
            } catch {
                throw IrohaHistoryReadError.nonCanonicalDefinition(candidate.id)
            }
            guard definitionsById[id] == nil else {
                throw IrohaHistoryReadError.duplicateDefinition(id)
            }
            definitionsById[id] = candidate
        }
        guard let definition = definitionsById[canonicalAssetId] else {
            throw IrohaHistoryReadError.missingDefinition(canonicalAssetId)
        }
        let profilePrecision = try historyProfilePrecision(
            asset: asset,
            canonicalAssetId: canonicalAssetId,
            network: network
        )
        let precision = try historyPrecision(expectedPrecision: profilePrecision, definition: definition)
        let request = try IrohaToriiRoutes.mcpJSONRPCRequest(
            method: "tools/call",
            id: "history-\(page)",
            params: [
                "name": .string("iroha.instructions.list"),
                "arguments": .object([
                    "account": .string(address),
                    "asset_id": .string(canonicalAssetId),
                    "kind": .string("Transfer"),
                    "page": .int(Int64(page)),
                    "per_page": .int(Int64(limit)),
                    "transaction_status": .string("committed"),
                    "accept": .string("application/json")
                ])
            ]
        )
        let response = try await client.mcpJSONRPC(
            request,
            network: network,
            baseURL: baseURL
        )

        let instructionPage = try response.instructionPage(
            expectedID: "history-\(page)",
            requestedPage: page,
            requestedPerPage: limit,
            expectedTotalPages: expectedTotalPages,
            expectedTotalItems: expectedTotalItems
        )
        let transactions = try instructionPage.items.flatMap { item in
            try item.transactionData(
                accountAddress: address,
                asset: asset,
                precision: precision,
                chainDiscriminant: network.chainDiscriminant
            )
        }
        guard Set(transactions.map(\.transactionId)).count == transactions.count else {
            throw IrohaHistoryReadError.invalidMcpResponse("duplicate_history_identity")
        }
        let nextContext = Int64(page) < instructionPage.totalPages
            ? [
                Self.paginationPageKey: String(page + 1),
                Self.paginationTotalPagesKey: String(instructionPage.totalPages),
                Self.paginationTotalItemsKey: String(instructionPage.totalItems)
            ]
            : nil

        return AssetTransactionPageData(transactions: transactions, context: nextContext)
    }

    private func historyProfilePrecision(
        asset: AssetModel,
        canonicalAssetId: String,
        network: UniversalWalletRegistry.IrohaNetwork
    ) throws -> Int {
        guard let nativeAsset = network.nativeAsset, nativeAsset.id == canonicalAssetId else {
            return Int(asset.precision)
        }
        guard asset.symbol == nativeAsset.symbol, Int(asset.precision) == nativeAsset.decimals else {
            throw IrohaHistoryReadError.nativeProfileMismatch(
                assetId: canonicalAssetId,
                symbol: asset.symbol,
                precision: Int(asset.precision)
            )
        }

        return nativeAsset.decimals
    }

    private func historyPrecision(
        expectedPrecision: Int,
        definition: IrohaAssetDefinitionListItem
    ) throws -> Int {
        guard let scale = definition.spec?.scale else {
            throw IrohaHistoryReadError.missingScale(definition.id)
        }
        guard scale >= 0, scale == expectedPrecision else {
            throw IrohaHistoryReadError.precisionMismatch(
                assetId: definition.id,
                wallet: expectedPrecision,
                torii: scale
            )
        }
        return scale
    }

    private func emptyPage() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        CompoundOperationWrapper.createWithResult(AssetTransactionPageData(transactions: []))
    }
}

enum IrohaHistoryReadError: Error, Equatable {
    case invalidNetworkIdentity(String)
    case nonCanonicalAssetDefinition(String)
    case truncatedDefinitions
    case nonCanonicalDefinition(String)
    case duplicateDefinition(String)
    case missingDefinition(String)
    case missingScale(String)
    case nativeProfileMismatch(assetId: String, symbol: String, precision: Int)
    case precisionMismatch(assetId: String, wallet: Int, torii: Int)
    case inexactAmount(assetId: String, baseUnits: String, precision: Int)
    case nonCommittedStatus(String?)
    case mcp(code: Int, message: String)
    case invalidMcpResponse(String)
}

extension IrohaHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard let network = Self.network(for: chain) else {
            return CompoundOperationWrapper.createWithError(
                IrohaHistoryReadError.invalidNetworkIdentity(chain.chainId)
            )
        }
        guard pagination.count >= 1,
              shouldFetch(filters: filters),
              let normalizedAddress = normalizedAddress(address, network: network)
        else {
            return emptyPage()
        }

        let historyOperation = createHistoryOperation(
            asset: asset,
            chain: chain,
            network: network,
            address: normalizedAddress,
            pagination: pagination
        )

        return CompoundOperationWrapper(targetOperation: historyOperation)
    }
}

private extension IrohaMcpJsonRPCResponse {
    func instructionPage(
        expectedID: String,
        requestedPage: Int,
        requestedPerPage: Int,
        expectedTotalPages: Int64?,
        expectedTotalItems: Int64?
    ) throws -> IrohaInstructionPage {
        guard jsonrpc == "2.0", id == .string(expectedID) else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_json_rpc_envelope")
        }
        if let error {
            throw IrohaHistoryReadError.mcp(code: error.code, message: error.message)
        }
        guard case let .object(toolResult)? = result,
              toolResult["isError"] == .bool(false),
              case let .object(route)? = toolResult["structuredContent"] else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_tool_result")
        }
        guard case let .int(status)? = route["status"], (200 ... 299).contains(status) else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_route_status")
        }
        guard case let .object(rawHeaders)? = route["headers"] else {
            throw IrohaHistoryReadError.invalidMcpResponse("missing_route_headers")
        }
        var headers: [String: String] = [:]
        for (name, rawValue) in rawHeaders {
            guard case let .string(value) = rawValue else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_route_header")
            }
            let normalizedName = name.lowercased()
            guard headers[normalizedName] == nil else {
                throw IrohaHistoryReadError.invalidMcpResponse("duplicate_route_header")
            }
            headers[normalizedName] = value
        }
        try validateCompleteFanout(headers)
        guard case let .string(rawContentType)? = route["content_type"],
              let mediaType = rawContentType.split(separator: ";", maxSplits: 1).first,
              mediaType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "application/json" else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_route_content_type")
        }
        guard case let .object(body)? = route["body"],
              body.hasExactKeys(historyPageKeys),
              case let .array(rawItems)? = body["items"],
              case let .object(pagination)? = body["pagination"],
              pagination.hasExactKeys(paginationKeys),
              case let .int(page)? = pagination["page"],
              case let .int(perPage)? = pagination["per_page"],
              case let .int(totalPages)? = pagination["total_pages"],
              case let .int(totalItems)? = pagination["total_items"],
              page == Int64(requestedPage),
              perPage == Int64(requestedPerPage),
              totalPages >= 0,
              totalPages <= Int64(Int.max),
              totalItems >= 0 else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_route_body")
        }
        let calculatedTotalPages = totalItems == 0 ? 0 : ((totalItems - 1) / Int64(requestedPerPage)) + 1
        guard totalPages == calculatedTotalPages else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_pagination")
        }
        guard expectedTotalPages == nil || totalPages == expectedTotalPages,
              expectedTotalItems == nil || totalItems == expectedTotalItems else {
            throw IrohaHistoryReadError.invalidMcpResponse("pagination_snapshot_changed")
        }
        let (start, overflow) = Int64(requestedPage - 1).multipliedReportingOverflow(by: Int64(requestedPerPage))
        guard !overflow else {
            throw IrohaHistoryReadError.invalidMcpResponse("pagination_overflow")
        }
        let expectedItemCount = start >= totalItems
            ? 0
            : Int(min(Int64(requestedPerPage), totalItems - start))
        guard rawItems.count == expectedItemCount else {
            throw IrohaHistoryReadError.invalidMcpResponse("truncated_history_page")
        }

        let items = try rawItems.map { item in
            guard case let .object(value) = item else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_history_item")
            }
            return value
        }
        return IrohaInstructionPage(items: items, totalPages: totalPages, totalItems: totalItems)
    }

    private func validateCompleteFanout(_ headers: [String: String]) throws {
        let names = [
            "x-iroha-fanout-routes-attempted",
            "x-iroha-fanout-routes-succeeded",
            "x-iroha-fanout-routes-failed",
            "x-iroha-fanout-routes-denied",
            "x-iroha-fanout-routes-unavailable",
            "x-iroha-fanout-routes-not-found"
        ]
        let values = try names.map { name -> Int64 in
            guard let rawValue = headers[name],
                  rawValue.range(of: "^(0|[1-9][0-9]*)$", options: .regularExpression) != nil,
                  let value = Int64(rawValue) else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_fanout_headers")
            }
            return value
        }
        guard values[0] > 0,
              values[1] == values[0],
              values[2] == 0,
              values[3] == 0,
              values[4] == 0,
              values[5] == 0 else {
            throw IrohaHistoryReadError.invalidMcpResponse("incomplete_fanout")
        }
    }
}

private extension [String: IrohaJSONValue] {
    func transactionData(
        accountAddress: String,
        asset: AssetModel,
        precision: Int,
        chainDiscriminant: Int
    ) throws -> [AssetTransactionData] {
        guard hasExactKeys(historyItemKeys),
              let authority = canonicalPayloadString("authority"),
              (try? IrohaAddressCodec.parse(authority, expectedDiscriminant: chainDiscriminant))?.i105 == authority,
              let hash = try canonicalHistoryString(
                  "transaction_hash",
                  rejectingAliases: ["transactionHash", "hash"]
              ),
              canonicalTransactionHashRegex.matches(hash),
              let timestamp = timestampSeconds(
                  try canonicalHistoryString("created_at", rejectingAliases: ["createdAt", "timestamp"])
              ),
              case let .int(block)? = self["block"],
              block > 0,
              case let .int(instructionIndex)? = self["index"],
              instructionIndex >= 0,
              instructionIndex <= Int64(UInt32.max),
              self["kind"] == .string("Transfer"),
              let box = self["box"]?.objectValue,
              box.hasExactKeys(instructionBoxKeys),
              case let .string(boxEncoded)? = box["encoded"],
              case let .string(framedSha)? = box["framed_sha256"],
              framedSha256Regex.matches(framedSha),
              let json = box["json"]?.objectValue,
              json.hasExactKeys(instructionJSONKeys),
              json["kind"] == .string("Transfer"),
              case let .string(encoded)? = json["encoded"],
              lowerHexBytesRegex.matches(encoded),
              boxEncoded == "0x\(encoded)",
              let payload = json["payload"]?.objectValue,
              payload.hasExactKeys(transferPayloadKeys),
              let variant = payload.canonicalPayloadString("variant")
        else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_history_item")
        }
        let expectedWireId: String
        switch variant {
        case "Asset": expectedWireId = "iroha.transfer"
        case "AssetBatch": expectedWireId = "iroha.transfer_batch"
        default: throw IrohaHistoryReadError.invalidMcpResponse("invalid_transfer_variant")
        }
        guard json["wire_id"] == .string(expectedWireId) else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_transfer_wire_id")
        }

        let transactionStatus = try canonicalHistoryString(
            "transaction_status",
            rejectingAliases: ["transactionStatus", "status"]
        )
        guard transactionStatus == "Committed" else {
            throw IrohaHistoryReadError.nonCommittedStatus(transactionStatus)
        }
        let status = AssetTransactionStatus.commited
        let transfers = try payload.transferPayloads(
            accountAddress: accountAddress,
            assetId: asset.id,
            precision: precision,
            chainDiscriminant: chainDiscriminant
        )

        return try transfers.map { transfer in
            guard
                precision <= Int(Int16.max),
                let amount = Decimal.fromSubstrateAmount(transfer.amount, precision: Int16(precision)),
                amount.toSubstrateAmount(precision: Int16(precision)) == transfer.amount
            else {
                throw IrohaHistoryReadError.inexactAmount(
                    assetId: asset.id,
                    baseUnits: String(transfer.amount),
                    precision: precision
                )
            }

            let isOutgoing = transfer.from == accountAddress
            let peerAddress = isOutgoing ? transfer.to : transfer.from

            return AssetTransactionData(
                transactionId: transfer.legId.map { "\(hash):\(instructionIndex):\($0)" }
                    ?? "\(hash):\(instructionIndex)",
                status: status,
                assetId: asset.id,
                peerId: peerAddress,
                peerFirstName: nil,
                peerLastName: nil,
                peerName: peerAddress.isEmpty ? nil : peerAddress,
                details: "",
                amount: AmountDecimal(value: amount),
                fees: [],
                timestamp: timestamp,
                type: (isOutgoing ? TransactionType.outgoing : .incoming).rawValue,
                reason: "",
                context: nil
            )
        }
    }

    func transferPayloads(
        accountAddress: String,
        assetId: String,
        precision: Int,
        chainDiscriminant: Int
    ) throws -> [IrohaTransferPayload] {
        guard let variant = canonicalPayloadString("variant") else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_transfer_variant")
        }

        switch variant {
        case "Asset":
            guard let result = self["value"]?.objectValue?.parseAssetTransfer(
                accountAddress: accountAddress,
                assetId: assetId,
                precision: precision,
                chainDiscriminant: chainDiscriminant
            ), result.canonical else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_asset_transfer")
            }
            return result.transfer.map { [$0] } ?? []
        case "AssetBatch":
            guard let value = self["value"]?.objectValue else {
                throw IrohaHistoryReadError.invalidMcpResponse("invalid_asset_batch")
            }
            return try value.parseAssetBatch(
                accountAddress: accountAddress,
                assetId: assetId,
                precision: precision,
                chainDiscriminant: chainDiscriminant
            )
        default:
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_transfer_variant")
        }
    }

    func parseAssetTransfer(
        accountAddress: String,
        assetId: String,
        precision: Int,
        chainDiscriminant: Int
    ) -> IrohaTransferParseResult {
        guard hasExactKeys(singleTransferKeys),
              let source = canonicalPayloadString("source") else {
            return .invalid
        }
        let sourceParts = source.split(separator: "#", omittingEmptySubsequences: false)
        guard sourceParts.count == 2,
              !sourceParts[1].isEmpty,
              let destination = canonicalPayloadString("destination") else {
            return .invalid
        }
        let sourceDefinition = String(sourceParts[0])
        let sourceAccount = String(sourceParts[1])
        guard
            (try? IrohaToriiRoutes.normalizeAssetDefinitionId(sourceDefinition)) == sourceDefinition,
            (try? IrohaAddressCodec.parse(sourceAccount, expectedDiscriminant: chainDiscriminant))?.i105 == sourceAccount,
            (try? IrohaAddressCodec.parse(destination, expectedDiscriminant: chainDiscriminant))?.i105 == destination,
            let amountValue = self["object"],
            let amount = normalizeIrohaAmount(amountValue, precision: precision) else {
            return .invalid
        }
        guard sourceDefinition == assetId else {
            return .excluded()
        }

        let incoming = destination == accountAddress
        let outgoing = sourceAccount == accountAddress

        guard incoming || outgoing else {
            return .excluded()
        }

        return .included(
            IrohaTransferPayload(
                amount: amount,
                from: outgoing ? accountAddress : sourceAccount,
                legId: nil,
                to: incoming ? accountAddress : destination
            )
        )
    }

    func parseAssetBatch(
        accountAddress: String,
        assetId: String,
        precision: Int,
        chainDiscriminant: Int
    ) throws -> [IrohaTransferPayload] {
        guard hasExactKeys(batchContainerKeys),
              let mode = self["mode"]?.objectValue,
              mode.hasExactKeys(batchModeKeys),
              mode["mode"] == .string("Atomic"),
              mode["value"] == .null,
              let entries = self["entries"]?.arrayValue,
              entries.count <= maxIrohaBatchEntries else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_asset_batch")
        }

        let results = entries.map { entry in
            entry.objectValue?.parseAssetBatchEntry(
                accountAddress: accountAddress,
                assetId: assetId,
                precision: precision,
                chainDiscriminant: chainDiscriminant
            ) ?? .invalid
        }

        guard results.allSatisfy(\.canonical) else {
            throw IrohaHistoryReadError.invalidMcpResponse("invalid_asset_batch_entry")
        }
        let legIds = results.compactMap(\.legId)
        guard legIds.count == entries.count, Set(legIds).count == legIds.count else {
            throw IrohaHistoryReadError.invalidMcpResponse("duplicate_asset_batch_leg_id")
        }

        return results.compactMap(\.transfer)
    }

    func parseAssetBatchEntry(
        accountAddress: String,
        assetId: String,
        precision: Int,
        chainDiscriminant: Int
    ) -> IrohaTransferParseResult {
        guard hasExactKeys(batchEntryKeys),
              let legId = canonicalPayloadString("leg_id"),
              legId.utf8.count <= maxIrohaBatchLegIdLength,
              let from = canonicalPayloadString("from"),
              let to = canonicalPayloadString("to"),
              (try? IrohaAddressCodec.parse(from, expectedDiscriminant: chainDiscriminant))?.i105 == from,
              (try? IrohaAddressCodec.parse(to, expectedDiscriminant: chainDiscriminant))?.i105 == to,
              let definition = canonicalPayloadString("asset_definition"),
              (try? IrohaToriiRoutes.normalizeAssetDefinitionId(definition)) == definition,
              let amountValue = self["amount"],
              let amount = normalizeIrohaAmount(amountValue, precision: precision) else {
            return .invalid
        }

        guard definition == assetId else {
            return .excluded(legId: legId)
        }

        let incoming = to == accountAddress
        let outgoing = from == accountAddress

        guard incoming || outgoing else {
            return .excluded(legId: legId)
        }

        return .included(
            IrohaTransferPayload(
                amount: amount,
                from: outgoing ? accountAddress : from,
                legId: legId,
                to: incoming ? accountAddress : to
            )
        )
    }

    func canonicalHistoryString(_ canonicalKey: String, rejectingAliases aliases: [String]) throws -> String? {
        guard !aliases.contains(where: { self[$0] != nil }) else {
            throw IrohaHistoryReadError.invalidMcpResponse("noncanonical_history_field")
        }
        guard case let .string(value)? = self[canonicalKey],
              !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        return value
    }

    func canonicalPayloadString(_ key: String) -> String? {
        guard case let .string(value)? = self[key],
              !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        return value
    }

    func hasExactKeys(_ expected: Set<String>) -> Bool {
        Set(keys) == expected
    }
}

private extension IrohaJSONValue {
    var objectValue: [String: IrohaJSONValue]? {
        if case let .object(value) = self {
            return value
        }

        return nil
    }

    var arrayValue: [IrohaJSONValue]? {
        if case let .array(value) = self {
            return value
        }

        return nil
    }
}

private func normalizeIrohaAmount(_ value: IrohaJSONValue?, precision: Int) -> BigUInt? {
    guard (0 ... maxSupportedIrohaPrecision).contains(precision),
          case let .string(raw)? = value else {
        return nil
    }

    return decimalQuantityToBaseUnits(raw, precision: precision)
}

private func decimalQuantityToBaseUnits(_ raw: String, precision: Int) -> BigUInt? {
    guard raw.count <= maxIrohaQuantityWireLength,
          canonicalQuantityRegex.matches(raw) else {
        return nil
    }
    let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
    let fraction = parts.count == 2 ? String(parts[1]) : ""
    let mantissaText = String(parts[0]) + fraction
    guard fraction.count <= maxSupportedIrohaPrecision,
          mantissaText.count <= maxIrohaQuantityDigits,
          let mantissa = BigUInt(mantissaText),
          mantissa <= maxIrohaQuantity else {
        return nil
    }
    return scaledIntegerToBaseUnits(
        String(mantissa),
        scale: fraction.count,
        precision: precision
    )
}

private func scaledIntegerToBaseUnits(_ mantissa: String, scale: Int, precision: Int) -> BigUInt? {
    let normalized: String
    if scale <= precision {
        normalized = mantissa + String(repeating: "0", count: precision - scale)
    } else {
        let discardedCount = scale - precision
        guard mantissa.count > discardedCount else { return nil }
        let split = mantissa.index(mantissa.endIndex, offsetBy: -discardedCount)
        guard mantissa[split...].allSatisfy({ $0 == "0" }) else {
            return nil
        }
        normalized = String(mantissa[..<split])
    }

    return BigUInt(normalized).flatMap { $0 > 0 ? $0 : nil }
}

private func timestampSeconds(_ value: String?) -> Int64? {
    guard let value, canonicalRFC3339Regex.matches(value) else {
        return nil
    }
    let wholeSeconds = String(value.prefix(19)) + "Z"
    guard let date = canonicalTimestampFormatter.date(from: wholeSeconds),
          canonicalTimestampFormatter.string(from: date) == wholeSeconds else {
        return nil
    }
    let seconds = date.timeIntervalSince1970.rounded(.down)

    return seconds.isFinite && seconds >= 0 && seconds <= Double(Int64.max) ? Int64(seconds) : nil
}

private struct IrohaTransferPayload {
    let amount: BigUInt
    let from: String
    let legId: String?
    let to: String
}

private struct IrohaTransferParseResult {
    let canonical: Bool
    let legId: String?
    let transfer: IrohaTransferPayload?

    static let invalid = IrohaTransferParseResult(canonical: false, legId: nil, transfer: nil)

    static func excluded(legId: String? = nil) -> IrohaTransferParseResult {
        IrohaTransferParseResult(canonical: true, legId: legId, transfer: nil)
    }

    static func included(_ transfer: IrohaTransferPayload) -> IrohaTransferParseResult {
        IrohaTransferParseResult(canonical: true, legId: transfer.legId, transfer: transfer)
    }
}

private struct IrohaInstructionPage {
    let items: [[String: IrohaJSONValue]]
    let totalPages: Int64
    let totalItems: Int64
}

private extension NSRegularExpression {
    func matches(_ value: String) -> Bool {
        firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}

private let maxSupportedIrohaPrecision = 28
private let maxIrohaQuantityDigits = 154
private let maxIrohaQuantityWireLength = maxIrohaQuantityDigits + 1
private let maxIrohaBatchEntries = 1000
private let maxIrohaBatchLegIdLength = 256
private let maxIrohaQuantity = (BigUInt(1) << 511) - 1
private let canonicalTransactionHashRegex = try! NSRegularExpression(pattern: "^[0-9a-f]{63}[13579bdf]$")
private let canonicalRFC3339Regex = try! NSRegularExpression(
    pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{0,8}[1-9])?Z$"
)
private let canonicalQuantityRegex = try! NSRegularExpression(pattern: "^(0|[1-9][0-9]*)(\\.[0-9]*[1-9])?$")
private let lowerHexBytesRegex = try! NSRegularExpression(pattern: "^([0-9a-f]{2})+$")
private let framedSha256Regex = try! NSRegularExpression(pattern: "^0x[0-9a-f]{64}$")
private let historyItemKeys: Set<String> = [
    "authority",
    "created_at",
    "kind",
    "box",
    "transaction_hash",
    "transaction_status",
    "block",
    "index"
]
private let instructionBoxKeys: Set<String> = ["encoded", "framed_sha256", "json"]
private let instructionJSONKeys: Set<String> = ["kind", "payload", "wire_id", "encoded"]
private let transferPayloadKeys: Set<String> = ["variant", "value"]
private let singleTransferKeys: Set<String> = ["source", "object", "destination"]
private let batchContainerKeys: Set<String> = ["mode", "entries"]
private let batchModeKeys: Set<String> = ["mode", "value"]
private let batchEntryKeys: Set<String> = ["leg_id", "from", "to", "asset_definition", "amount"]
private let historyPageKeys: Set<String> = ["pagination", "items"]
private let paginationKeys: Set<String> = ["page", "per_page", "total_pages", "total_items"]
private let canonicalTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.isLenient = false
    return formatter
}()
