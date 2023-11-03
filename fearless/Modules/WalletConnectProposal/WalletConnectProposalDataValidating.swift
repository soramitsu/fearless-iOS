import Foundation
import WalletConnectSign

final class WalletConnectProposalDataValidating {
    private let basePresentable: SheetAlertPresentable
    init(presentable: SheetAlertPresentable) {
        basePresentable = presentable
    }

    func validate(
        requiredMethods: [String],
        view: ControllerBackedProtocol?,
        locale: Locale,
        onReject: (() -> Void)?
    ) -> DataValidating {
        WarningConditionViolation { [weak self] delegate in
            let approveTitle = R.string.localizable
                .commonApprove(preferredLanguages: locale.rLanguages)
            let approveAction = SheetAlertPresentableAction(title: approveTitle, style: .pinkBackgroundWhiteText) {
                delegate.didCompleteWarningHandling()
            }

            let rejectTitle = R.string.localizable
                .commonReject(preferredLanguages: locale.rLanguages)
            let rejectAction = SheetAlertPresentableAction(title: rejectTitle, style: .grayBackgroundWhiteText) {
                onReject?()
            }

            self?.basePresentable.present(
                message: AutoNamespacesError.requiredMethodsNotSatisfied.localizedDescription,
                title: "",
                closeAction: nil,
                from: view,
                actions: [approveAction, rejectAction]
            )
        } preservesCondition: {
            let fearlessWalletMethods = WalletConnectMethod.allCases.map { $0.rawValue }
            guard Set(requiredMethods).isSubset(of: Set(fearlessWalletMethods)) else {
                return false
            }
            return true
        }
    }
}
