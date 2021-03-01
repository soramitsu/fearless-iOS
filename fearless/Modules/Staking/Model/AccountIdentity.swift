import Foundation

struct AccountIdentity: Equatable {
    let name: String
    let parentAddress: String?
    let parentName: String?
    let legal: String?
    let web: String?
    let riot: String?
    let email: String?
    let image: Data?
    let twitter: String?

    init(name: String, parentAddress: String? = nil, parentName: String? = nil, identity: IdentityInfo? = nil) {
        self.name = name
        self.parentAddress = parentAddress
        self.parentName = parentName
        self.legal = identity?.legal.stringValue
        self.web = identity?.web.stringValue
        self.riot = identity?.riot.stringValue
        self.email = identity?.email.stringValue
        self.image = identity?.image.dataValue
        self.twitter = identity?.twitter.stringValue
    }
}
