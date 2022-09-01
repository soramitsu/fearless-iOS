import Foundation

enum NetworkIssuesActionButtonType {
    case switchNode(title: String)
    case networkUnavailible
    case missingAccount(title: String)
}

struct NetworkIssuesNotificationCellViewModel {
    let imageViewViewModel: RemoteImageViewModel?
    let chainNameTitle: String
    let issueDescription: String
    let buttonType: NetworkIssuesActionButtonType

    let chain: ChainModel
}
