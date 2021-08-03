import Foundation

struct AccountIdentity: Equatable {
    let name: String
    let parentAddress: AccountAddress?
    let parentName: String?
    let legal: String?
    let web: String?
    let riot: String?
    let email: String?
    let image: Data?
    let twitter: String?

    init(
        name: String,
        parentAddress: AccountAddress? = nil,
        parentName: String? = nil,
        identity: IdentityInfo? = nil
    ) {
        self.name = name
        self.parentAddress = parentAddress
        self.parentName = parentName
        legal = identity?.legal.stringValue
        web = identity?.web.stringValue
        riot = identity?.riot.stringValue
        email = identity?.email.stringValue
        image = identity?.image.dataValue
        twitter = identity?.twitter.stringValue
    }

    var displayName: String {
        if let parentName = parentName {
            return parentName + " / " + name
        } else {
            return name
        }
    }
}
