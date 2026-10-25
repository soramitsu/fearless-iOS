import Foundation

final class JSONRPCListWorker<T: Decodable>: JSONRPCWorker<[String], T> {}
