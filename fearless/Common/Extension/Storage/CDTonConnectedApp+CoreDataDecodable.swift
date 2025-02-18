import Foundation
import RobinHood
import CoreData

extension CDTonConnectedApp: CoreDataCodable {
    public func populate(from decoder: any Decoder, using _: NSManagedObjectContext) throws {
        let app = try TonConnectApp(from: decoder)
        identifier = app.identifier

        walletId = app.walletId
        clientId = app.clientId
        appUrl = app.appUrl
        name = app.name
        iconUrl = app.iconUrl
        publicKey = app.publicKey
        privateKey = app.privateKey
        connectionType = app.connectionType.rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: TonConnectApp.CodingKeys.self)

        try container.encode(walletId, forKey: .walletId)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(appUrl, forKey: .appUrl)
        try container.encode(name, forKey: .name)
        try container.encode(iconUrl, forKey: .iconUrl)
        try container.encode(publicKey, forKey: .publicKey)
        try container.encode(privateKey, forKey: .privateKey)
        try container.encode(connectionType, forKey: .connectionType)
    }
}
