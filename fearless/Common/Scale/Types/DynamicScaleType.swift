import Foundation

protocol DynamicScaleCodable: Codable {
    static var typeName: String { get }
}
