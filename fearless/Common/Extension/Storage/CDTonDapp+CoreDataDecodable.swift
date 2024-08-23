import Foundation
import RobinHood
import CoreData

extension CDTonDapp: CoreDataCodable {
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: TonDapp.CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        chains = try container.decode([String].self, forKey: .chains) as? NSArray
        name = try container.decode(String.self, forKey: .name)
        appDescription = try container.decode(String?.self, forKey: .description)
        icon = try container.decode(URL?.self, forKey: .icon)
        poster = try container.decode(URL?.self, forKey: .poster)
        url = try container.decode(URL.self, forKey: .url)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TonDapp.CodingKeys.self)

        let chains = chains as? [String]
        try container.encode(chains, forKey: .chains)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(appDescription, forKey: .description)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(poster, forKey: .poster)
        try container.encode(url, forKey: .url)
        try container.encode(identifier, forKey: .identifier)
    }
}
