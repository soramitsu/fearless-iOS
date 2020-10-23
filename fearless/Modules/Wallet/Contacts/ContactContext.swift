import Foundation

enum ContactDestination: String {
    case local
    case remote
}

struct ContactContext {
    static let destinationKey = "contact.destination.key"

    let destination: ContactDestination
}

extension ContactContext {
    init(context: [String: String]) {
        if
            let value = context[ContactContext.destinationKey],
            let destination = ContactDestination(rawValue: value) {
            self.destination = destination
        } else {
            self.destination = .remote
        }
    }

    func toContext() -> [String: String] {
        [
            ContactContext.destinationKey: destination.rawValue
        ]
    }
}
