import DesignSystem
import Foundation
import Observation
import WalletCore

/// The send flow: form, review, approval and progress. The user's input is
/// never cleared by an error; a failed network call only adds a message.
@MainActor
@Observable
final class SendModel: Identifiable {
    enum Stage: Equatable {
        case form
        case review
        case progress
    }

    enum AmountUnit: Equatable {
        case asset
        case fiat
    }

    let id = UUID()
    let wallet: Wallet
    let fiat: FiatCurrency
    @ObservationIgnored private let services: WalletServices
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let onCompleted: () -> Void

    /// Assets the wallet can send from, with their balances.
    private(set) var rows: [AssetRow]
    private(set) var assetID: AssetID?

    var recipientText = "" {
        didSet { if recipientText != oldValue { recipientEdited() } }
    }
    var amountText = "" {
        didSet { if amountText != oldValue { amountEdited() } }
    }
    private(set) var amountUnit: AmountUnit = .asset
    var keepAlive = true {
        didSet { if keepAlive != oldValue { schedulePreparation() } }
    }

    private(set) var recipientValidation: RecipientValidation = .empty
    private(set) var isValidatingRecipient = false
    private(set) var preparation: TransferPreparation?
    private(set) var isPreparing = false
    private(set) var recipientTouched = false
    private(set) var amountTouched = false

    private(set) var stage: Stage = .form
    var approvalPassword = ""
    private(set) var approvalError: String?
    private(set) var isSubmitting = false
    private(set) var biometrics: BiometricsAvailability = .unavailable(reason: "")

    private(set) var sealStage: SealStage = .idle
    /// Set when the network definitively rejected or failed the transfer.
    private(set) var failureReason: String?
    /// Set when the transfer was sent but its outcome could not be confirmed.
    /// It may still succeed, so this is neither success nor failure.
    private(set) var unknownOutcomeReason: String?
    private(set) var transactionHash: String?
    private(set) var explorerURL: URL?
    /// The exact request that was approved, shown on the progress screen.
    private(set) var submittedRequest: TransferRequest?
    private(set) var submittedFee: FeeEstimate?

    @ObservationIgnored private var recipientTask: Task<Void, Never>?
    @ObservationIgnored private var prepareTask: Task<Void, Never>?
    @ObservationIgnored private var submitTask: Task<Void, Never>?
    @ObservationIgnored private var prepareGeneration = 0
    @ObservationIgnored private var recipientGeneration = 0

    init(
        wallet: Wallet,
        rows: [AssetRow],
        initialAssetID: AssetID?,
        fiat: FiatCurrency,
        services: WalletServices,
        locale: Locale = .current,
        debounce: Duration = .milliseconds(300),
        onCompleted: @escaping () -> Void = {}
    ) {
        self.wallet = wallet
        self.rows = rows
        self.fiat = fiat
        self.services = services
        self.locale = locale
        self.debounce = debounce
        self.onCompleted = onCompleted
        if let initialAssetID, rows.contains(where: { $0.id == initialAssetID }) {
            assetID = initialAssetID
        } else {
            assetID = rows.first(where: \.hasBalance)?.id ?? rows.first?.id
        }
    }

    // MARK: Selection

    var selectedRow: AssetRow? {
        guard let assetID else { return nil }
        return rows.first { $0.id == assetID }
    }

    var asset: Asset? { selectedRow?.asset }
    var chain: Chain? { selectedRow?.chain }

    /// Rows grouped by network for the asset picker.
    var rowsByChain: [(chain: Chain, rows: [AssetRow])] {
        var order: [ChainID] = []
        var groups: [ChainID: (chain: Chain, rows: [AssetRow])] = [:]
        for row in rows {
            if groups[row.chain.id] == nil { order.append(row.chain.id) }
            groups[row.chain.id, default: (row.chain, [])].rows.append(row)
        }
        return order.compactMap { groups[$0] }
    }

    func selectAsset(_ id: AssetID) {
        guard id != assetID, rows.contains(where: { $0.id == id }) else { return }
        assetID = id
        preparation = nil
        // Fiat entry needs a price; fall back to the asset's own unit.
        if amountUnit == .fiat, selectedRow?.price == nil { amountUnit = .asset }
        if !recipientText.isEmpty { scheduleRecipientValidation(immediately: true) }
        schedulePreparation(immediately: true)
    }

    /// Replaces the balances (after a refresh) without touching the input.
    func updateRows(_ newRows: [AssetRow]) {
        rows = newRows
    }

    var isSubstrate: Bool { chain?.ecosystem == .substrate }

    var keepAliveExplanation: String {
        guard let asset, let chain else { return "" }
        if let deposit = asset.existentialDeposit, !deposit.isZero {
            return "\(chain.name) removes accounts that hold less than \(Money.token(deposit, symbol: asset.symbol, maximumFractionDigits: 6, locale: locale)) and burns what is left. With this on, a transfer that would do that is refused."
        }
        return "\(chain.name) removes accounts whose balance falls below a minimum and burns what is left. With this on, a transfer that would do that is refused."
    }

    // MARK: Amount

    var canUseFiat: Bool { selectedRow?.price != nil }

    /// The amount in the asset's smallest unit, or nil when the text is not
    /// a valid amount. Parsing never rounds: too many decimals is an error.
    var parsedAmount: TokenAmount? {
        guard let asset else { return nil }
        let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        switch amountUnit {
        case .asset:
            return TokenAmount(decimalString: text, decimals: asset.decimals, locale: locale)
        case .fiat:
            guard let price = selectedRow?.price?.value, price > 0,
                  let fiatValue = Self.decimal(from: text, locale: locale), fiatValue >= 0
            else { return nil }
            return Self.tokenAmount(fiat: fiatValue, price: price, decimals: asset.decimals)
        }
    }

    /// Why the amount text cannot be used, if it cannot.
    var amountFormatError: String? {
        guard let asset else { return nil }
        let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, parsedAmount == nil else { return nil }
        switch amountUnit {
        case .asset:
            return "Enter a number with at most \(asset.decimals) decimal places."
        case .fiat:
            return "Enter an amount in \(fiat.code.uppercased())."
        }
    }

    /// The other unit's reading of the amount, for the line under the field.
    var convertedAmountText: String? {
        guard let asset, let amount = parsedAmount else { return nil }
        switch amountUnit {
        case .asset:
            guard let price = selectedRow?.price?.value else { return nil }
            return "≈ " + Money.fiat(amount.fiatValue(unitPrice: price), currency: fiat, locale: locale)
        case .fiat:
            return "≈ " + Money.token(amount, symbol: asset.symbol, maximumFractionDigits: 6, locale: locale)
        }
    }

    func toggleAmountUnit() {
        guard canUseFiat || amountUnit == .fiat, let asset else { return }
        let amount = parsedAmount
        let price = selectedRow?.price?.value
        switch amountUnit {
        case .asset:
            amountUnit = .fiat
            if let amount, let price {
                amountText = Self.plainFiat(amount.fiatValue(unitPrice: price), locale: locale)
            }
        case .fiat:
            amountUnit = .asset
            if let amount {
                amountText = Self.localized(amount, decimals: asset.decimals, locale: locale)
            }
        }
    }

    /// Largest amount that can be sent after the fee (and the minimum
    /// balance on Substrate chains), as the engine reports it.
    var maxSendable: TokenAmount? { preparation?.maxSendable }

    /// Fills the amount with the largest sendable value. Asks the engine
    /// first when it has not said yet.
    func setMax() async {
        guard let asset else { return }
        if maxSendable == nil { await prepareNow() }
        guard let maximum = maxSendable else { return }
        amountUnit = .asset
        amountTouched = true
        amountText = Self.localized(maximum, decimals: asset.decimals, locale: locale)
        await prepareNow()
    }

    // MARK: Editing

    private func recipientEdited() {
        recipientTouched = true
        scheduleRecipientValidation()
        schedulePreparation()
    }

    private func amountEdited() {
        amountTouched = true
        schedulePreparation()
    }

    /// Puts an address from the pasteboard or a drop into the recipient field.
    func setRecipient(_ address: String) {
        recipientText = address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleRecipientValidation(immediately: Bool = false) {
        recipientTask?.cancel()
        recipientGeneration += 1
        let generation = recipientGeneration
        let text = recipientText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chain, !text.isEmpty else {
            recipientValidation = .empty
            isValidatingRecipient = false
            return
        }
        isValidatingRecipient = true
        let delay = immediately ? Duration.zero : debounce
        let transfers = services.transfers
        recipientTask = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            let result = await transfers.validateRecipient(text, on: chain.id)
            guard let self, generation == self.recipientGeneration else { return }
            self.recipientValidation = result
            self.isValidatingRecipient = false
            // The engine normalises a valid address; prepare again with it.
            self.schedulePreparation(immediately: true)
        }
    }

    private func schedulePreparation(immediately: Bool = false) {
        prepareTask?.cancel()
        prepareGeneration += 1
        let delay = immediately ? Duration.zero : debounce
        prepareTask = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            await self?.runPreparation()
        }
    }

    /// The draft as it stands; a missing or invalid amount is sent as zero
    /// so the engine can still report the fee and the maximum.
    private var draftRequest: TransferRequest? {
        guard let asset, let assetID else { return nil }
        let recipient: String
        if case .valid(let normalized) = recipientValidation {
            recipient = normalized
        } else {
            recipient = recipientText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return TransferRequest(
            walletID: wallet.id,
            assetID: assetID,
            recipient: recipient,
            amount: parsedAmount ?? .zero(decimals: asset.decimals),
            keepAlive: isSubstrate ? keepAlive : true
        )
    }

    private func runPreparation() async {
        guard let request = draftRequest else { return }
        prepareGeneration += 1
        let generation = prepareGeneration
        isPreparing = true
        let result = await services.transfers.prepare(request)
        guard generation == prepareGeneration else { return }
        preparation = result
        isPreparing = false
    }

    /// Validates the recipient and prepares the draft now, and waits for both.
    func prepareNow() async {
        recipientTask?.cancel()
        prepareTask?.cancel()
        let text = recipientText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let chain, !text.isEmpty {
            recipientGeneration += 1
            let generation = recipientGeneration
            isValidatingRecipient = true
            let result = await services.transfers.validateRecipient(text, on: chain.id)
            if generation == recipientGeneration {
                recipientValidation = result
                isValidatingRecipient = false
            }
        } else {
            recipientValidation = .empty
            isValidatingRecipient = false
        }
        await runPreparation()
    }

    /// Retry after a network problem. Input stays as it is.
    func retry() async {
        await prepareNow()
    }

    // MARK: Messages

    /// The recipient field's message: the live validation first, then the engine's.
    var recipientMessage: IssueMessage? {
        guard recipientTouched else { return nil }
        switch recipientValidation {
        case .wrongNetwork(let reason):
            return IssueMessage(field: .recipient, text: reason)
        case .invalid(let reason):
            return IssueMessage(field: .recipient, text: reason)
        case .empty, .valid:
            break
        }
        guard !recipientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return issueMessages.first { $0.field == .recipient }
    }

    var isRecipientWrongNetwork: Bool {
        if case .wrongNetwork = recipientValidation { return true }
        return false
    }

    var isRecipientValid: Bool {
        if case .valid = recipientValidation { return true }
        return false
    }

    var amountMessage: IssueMessage? {
        guard amountTouched else { return nil }
        if let formatError = amountFormatError {
            return IssueMessage(field: .amount, text: formatError)
        }
        guard !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return issueMessages.first { $0.field == .amount }
    }

    var generalMessages: [IssueMessage] {
        issueMessages.filter { $0.field == .general }
    }

    /// Every issue of the latest preparation as text.
    var issueMessages: [IssueMessage] {
        guard let preparation, let asset, let chain else { return [] }
        let feeSymbol = feeAsset?.symbol ?? asset.symbol
        return preparation.issues.map {
            TransferIssueText.message(for: $0, asset: asset, feeSymbol: feeSymbol, chain: chain, locale: locale)
        }
    }

    var feeAsset: Asset? {
        guard let fee = preparation?.fee ?? submittedFee else { return nil }
        return rows.first { $0.id == fee.assetID }?.asset
    }

    var feeText: String? {
        guard let fee = preparation?.fee, let feeAsset else { return nil }
        return Money.token(fee.amount, symbol: feeAsset.symbol, maximumFractionDigits: 8, locale: locale)
    }

    var feeFiatText: String? {
        guard let fee = preparation?.fee, let price = rows.first(where: { $0.id == fee.assetID })?.price?.value else { return nil }
        return Money.fiatApproximate(fee.amount.fiatValue(unitPrice: price), currency: fiat, locale: locale)
    }

    /// True when the draft is complete, the engine has no objection and the
    /// preparation matches what is in the fields now.
    var canReview: Bool {
        guard let preparation, let request = draftRequest, !isPreparing, !isValidatingRecipient else { return false }
        guard isRecipientValid, let amount = parsedAmount, !amount.isZero else { return false }
        return preparation.request == request && preparation.canSubmit
    }

    // MARK: Review and approval

    func review() async {
        await prepareNow()
        guard canReview else {
            recipientTouched = true
            amountTouched = true
            return
        }
        approvalError = nil
        approvalPassword = ""
        biometrics = await services.vault.biometricsAvailability()
        stage = .review
    }

    func backToForm() {
        guard !isSubmitting else { return }
        approvalPassword = ""
        approvalError = nil
        stage = .form
    }

    var canApproveWithPassword: Bool { !approvalPassword.isEmpty && !isSubmitting }
    var canApproveWithBiometrics: Bool { biometrics == .enabled && !isSubmitting }

    func approveWithPassword() async {
        guard canApproveWithPassword else { return }
        await submit(.password(approvalPassword))
    }

    func approveWithBiometrics() async {
        guard canApproveWithBiometrics else { return }
        await submit(.biometrics(reason: "approve this transfer"))
    }

    /// Signs and submits once. A second call while one is running is ignored.
    private func submit(_ approval: UserApproval) async {
        guard !isSubmitting, stage == .review, let request = preparation?.request, preparation?.canSubmit == true else { return }
        isSubmitting = true
        approvalError = nil
        do {
            let stream = try await services.transfers.submit(request, approval: approval)
            approvalPassword = ""
            submittedRequest = request
            submittedFee = preparation?.fee
            failureReason = nil
            unknownOutcomeReason = nil
            transactionHash = nil
            explorerURL = nil
            sealStage = .ready
            stage = .progress
            await consume(stream)
        } catch WalletError.biometricsCancelled {
            // Touch ID was dismissed; stay on the review.
        } catch {
            if case .password = approval { approvalPassword = "" }
            approvalError = ErrorText.message(for: error)
        }
        isSubmitting = false
    }

    private func consume(_ stream: AsyncThrowingStream<TransferProgress, Error>) async {
        do {
            for try await progress in stream {
                apply(progress)
            }
            if !isFinished {
                // The stream ended without a verdict.
                unknownOutcomeReason = "The connection closed before the transfer was confirmed."
            }
        } catch {
            if sealStage >= .signed, !isFinished {
                // It was signed and may have reached the network: nobody knows how it ended.
                unknownOutcomeReason = ErrorText.message(for: error)
            } else if !isFinished {
                failureReason = ErrorText.message(for: error)
            }
        }
        onCompleted()
    }

    /// Lights a stage only when the engine reports it.
    func apply(_ progress: TransferProgress) {
        switch progress {
        case .signed:
            sealStage = max(sealStage, .signed)
        case .broadcast(let hash, let url):
            transactionHash = hash
            explorerURL = AddressFormat.webURL(url)
            sealStage = max(sealStage, .sent)
        case .included:
            sealStage = max(sealStage, .accepted)
        case .finalized:
            sealStage = .finalized
        case .failed(let reason):
            failureReason = reason.isEmpty ? "The transfer failed." : reason
        case .outcomeUnknown(let reason):
            unknownOutcomeReason = reason.isEmpty ? "The transfer was sent, but its confirmation did not arrive." : reason
        }
    }

    var isFinished: Bool { sealStage == .finalized || failureReason != nil || unknownOutcomeReason != nil }
    /// The network definitively rejected or failed the transfer.
    var didFail: Bool { failureReason != nil }
    /// Sent, but nobody knows yet whether it went through.
    var isOutcomeUnknown: Bool { failureReason == nil && unknownOutcomeReason != nil && sealStage != .finalized }

    /// Stops listening (the sheet was closed). A submitted transfer keeps
    /// going on the network; Activity shows how it ends.
    func cancelObservation() {
        recipientTask?.cancel()
        prepareTask?.cancel()
        approvalPassword = ""
    }

    // MARK: Number helpers

    static func decimal(from text: String, locale: Locale) -> Decimal? {
        let separator = locale.decimalSeparator ?? "."
        var cleaned = text.filter { !$0.isWhitespace && $0 != "'" && $0 != "\u{2019}" }
        if separator == "," {
            if cleaned.contains(",") {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isNumber || $0 == "." }), cleaned.filter({ $0 == "." }).count <= 1 else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Token amount worth `fiat` at `price`, rounded down to at most eight
    /// decimal places (a fiat entry is an estimate; the review shows the
    /// exact token amount that will be sent).
    static func tokenAmount(fiat: Decimal, price: Decimal, decimals: Int) -> TokenAmount? {
        guard price > 0 else { return nil }
        var quotient = fiat / price
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, min(decimals, 8), .down)
        let text = NSDecimalNumber(decimal: rounded).description(withLocale: Locale(identifier: "en_US_POSIX"))
        return TokenAmount(decimalString: text, decimals: decimals, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Fiat value as editable text in the user's locale, without grouping.
    static func plainFiat(_ value: Decimal, locale: Locale) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        let text = NSDecimalNumber(decimal: rounded).description(withLocale: Locale(identifier: "en_US_POSIX"))
        return text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    /// Exact amount as editable text in the user's locale, without grouping.
    static func localized(_ amount: TokenAmount, decimals: Int, locale: Locale) -> String {
        amount.plainString.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}
