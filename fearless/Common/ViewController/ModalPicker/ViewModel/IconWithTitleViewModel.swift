import UIKit

struct IconWithTitleViewModel {
    let icon: UIImage?
    let remoteImageViewModel: RemoteImageViewModel?
    let title: String

    init(
        icon: UIImage?,
        remoteImageViewModel: RemoteImageViewModel? = nil,
        title: String
    ) {
        self.icon = icon
        self.remoteImageViewModel = remoteImageViewModel
        self.title = title
    }
}

extension IconWithTitleViewModel: Equatable {}
