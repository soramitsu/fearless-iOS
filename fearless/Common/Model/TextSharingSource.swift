import UIKit

class TextSharingSource: NSObject {
    let message: String
    let subject: String?

    init(message: String, subject: String? = nil) {
        self.message = message
        self.subject = subject

        super.init()
    }
}

extension TextSharingSource: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        message
    }

    func activityViewController(
        _: UIActivityViewController,
        itemForActivityType _: UIActivity.ActivityType?
    ) -> Any? {
        message
    }

    func activityViewController(
        _: UIActivityViewController,
        subjectForActivityType _: UIActivity.ActivityType?
    ) -> String {
        subject ?? "(No subject)"
    }
}
