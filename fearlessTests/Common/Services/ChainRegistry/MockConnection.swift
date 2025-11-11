import Foundation
@testable import fearless

// Use generated Cuckoo mock directly to conform to current JSONRPCEngine
final class MockConnection: MockJSONRPCEngine {}
