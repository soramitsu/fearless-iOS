import UIKit

class TextSharingSource: NSObject {
    var message: String
    var subject: String?

    init(message: String, subject: String? = nil) {
        self.message = message
        self.subject = subject

        super.init()
    }
}

extension TextSharingSource: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return message
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return message
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return subject ?? "(No subject)"
    }
}
