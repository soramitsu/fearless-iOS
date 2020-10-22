import Foundation
import RobinHood
import CoreData

extension CDTransactionHistoryItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: TransactionHistoryItem.CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .txHash)
        sender = try container.decode(String.self, forKey: .sender)
        receiver = try container.decode(String.self, forKey: .receiver)
        status = try container.decode(Int16.self, forKey: .status)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        amount = try container.decode(String.self, forKey: .amount)
        fee = try container.decode(String.self, forKey: .fee)

        if let number = try container.decodeIfPresent(Int64.self, forKey: .blockNumber) {
            blockNumber = NSNumber(value: number)
        } else {
            blockNumber = nil
        }

        if let index = try container.decodeIfPresent(Int16.self, forKey: .txIndex) {
            txIndex = NSNumber(value: index)
        } else {
            txIndex = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TransactionHistoryItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .txHash)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(receiver, forKey: .receiver)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(fee, forKey: .fee)
        try container.encodeIfPresent(blockNumber?.int64Value, forKey: .blockNumber)
        try container.encodeIfPresent(txIndex?.int16Value, forKey: .txIndex)
    }
}
