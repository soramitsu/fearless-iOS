import Foundation

/// What a dApp or wallet says about itself. Field names follow the protocol, because peers read them.
public struct AppMetadata: Hashable, Sendable, Codable {
    public struct Redirect: Hashable, Sendable, Codable {
        public let native: String?
        public let universal: String?
        public let linkMode: Bool?

        public init(native: String?, universal: String?, linkMode: Bool? = nil) {
            self.native = native
            self.universal = universal
            self.linkMode = linkMode
        }
    }

    public let name: String
    public let description: String
    public let url: String
    public let icons: [String]
    public let verifyUrl: String?
    public let redirect: Redirect?

    public init(
        name: String,
        description: String,
        url: String,
        icons: [String],
        verifyUrl: String? = nil,
        redirect: Redirect? = nil
    ) {
        self.name = name
        self.description = description
        self.url = url
        self.icons = icons
        self.verifyUrl = verifyUrl
        self.redirect = redirect
    }

    var json: JSONValue {
        var object: [String: JSONValue] = [
            "name": .string(name),
            "description": .string(description),
            "url": .string(url),
            "icons": .array(icons.map(JSONValue.string))
        ]
        if let verifyUrl {
            object["verifyUrl"] = .string(verifyUrl)
        }
        if let redirect {
            var redirectObject: [String: JSONValue] = [:]
            if let native = redirect.native {
                redirectObject["native"] = .string(native)
            }
            if let universal = redirect.universal {
                redirectObject["universal"] = .string(universal)
            }
            if let linkMode = redirect.linkMode {
                redirectObject["linkMode"] = .bool(linkMode)
            }
            object["redirect"] = .object(redirectObject)
        }
        return .object(object)
    }
}
