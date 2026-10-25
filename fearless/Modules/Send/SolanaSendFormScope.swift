import Foundation

protocol SolanaSendFormScopeManaging: AnyObject {
    func resumeSendForm()
    func suspendSendForm()
    func ownsSendFormPresentation(_ identifier: UUID) -> Bool
}

/// Owned by one Send form on the UI thread. A receipt belongs to one Continue tap or amount validation;
/// changing its inputs or leaving the form revokes every retained continuation.
/// The original settings lease is passed into confirmation, never recaptured there.
final class SolanaSendFormScope {
    let selection: SelectedWalletAuthority.Lease
    private var active = true
    private var suspensionRevision = UUID()

    var inputLifetime: UUID? { active ? suspensionRevision : nil }
    private var receipt: UUID?
    private var awaitingAddress = false
    private var presentation: UUID?

    init(selection: SelectedWalletAuthority.Lease) {
        self.selection = selection
    }

    func begin(awaitingAddress: Bool = true) -> UUID? {
        invalidate()
        guard active, selection.isCurrent else { return nil }
        let next = UUID()
        receipt = next
        self.awaitingAddress = awaitingAddress
        return next
    }

    func isCurrent(_ candidate: UUID) -> Bool {
        active && receipt == candidate && selection.isCurrent
    }

    func acceptAddress(_ candidate: UUID) -> Bool {
        guard isCurrent(candidate), awaitingAddress else { return false }
        awaitingAddress = false
        return true
    }

    func consume(_ candidate: UUID) -> Bool {
        guard isCurrent(candidate), !awaitingAddress else { return false }
        invalidate()
        return true
    }

    func bindPresentation(_ identifier: UUID, to candidate: UUID) {
        guard isCurrent(candidate) else { return }
        presentation = identifier
    }

    func ownsPresentation(_ identifier: UUID) -> Bool {
        guard let receipt else { return false }
        return isCurrent(receipt) && presentation == identifier
    }

    func endPresentation(_ identifier: UUID) {
        guard presentation == identifier else { return }
        invalidate()
    }

    func resume() {
        active = true
    }

    func invalidate() {
        presentation = nil
        receipt = nil
        awaitingAddress = false
    }

    func suspend() {
        suspensionRevision = UUID()
        active = false
        invalidate()
    }
}
