import Foundation
import SSFModels

enum NetworkIssuesActionButtonType {
    case switchNode(title: String)
    case networkUnavailible(title: String)
    case missingAccount(title: String)
}

struct NetworkIssuesNotificationCellViewModel {
    let imageViewViewModel: RemoteImageViewModel?
    let chainNameTitle: String
    let issueDescription: String
    let buttonType: NetworkIssuesActionButtonType

    let chain: ChainModel
}
