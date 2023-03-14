import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






public class MockJSONRPCResponseHandling: JSONRPCResponseHandling, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCResponseHandling
    
    public typealias Stubbing = __StubbingProxy_JSONRPCResponseHandling
    public typealias Verification = __VerificationProxy_JSONRPCResponseHandling

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCResponseHandling?

    public func enableDefaultImplementation(_ stub: JSONRPCResponseHandling) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
    public func handle(data: Data)  {
        
    return cuckoo_manager.call(
    """
    handle(data: Data)
    """,
            parameters: (data),
            escapingParameters: (data),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data))
        
    }
    
    
    
    
    
    public func handle(error: Error)  {
        
    return cuckoo_manager.call(
    """
    handle(error: Error)
    """,
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error))
        
    }
    
    

    public struct __StubbingProxy_JSONRPCResponseHandling: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Data)> where M1.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method:
    """
    handle(data: Data)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func handle<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
            let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method:
    """
    handle(error: Error)
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_JSONRPCResponseHandling: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.__DoNotUse<(Data), Void> where M1.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
            return cuckoo_manager.verify(
    """
    handle(data: Data)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func handle<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
            let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
            return cuckoo_manager.verify(
    """
    handle(error: Error)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class JSONRPCResponseHandlingStub: JSONRPCResponseHandling {
    

    

    
    
    
    
    public func handle(data: Data)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func handle(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










public class MockJSONRPCSubscribing: JSONRPCSubscribing, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCSubscribing
    
    public typealias Stubbing = __StubbingProxy_JSONRPCSubscribing
    public typealias Verification = __VerificationProxy_JSONRPCSubscribing

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCSubscribing?

    public func enableDefaultImplementation(_ stub: JSONRPCSubscribing) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
    public var requestId: UInt16 {
        get {
            return cuckoo_manager.getter("requestId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestId)
        }
        
    }
    
    
    
    
    
    public var requestData: Data {
        get {
            return cuckoo_manager.getter("requestData",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestData)
        }
        
    }
    
    
    
    
    
    public var requestOptions: JSONRPCOptions {
        get {
            return cuckoo_manager.getter("requestOptions",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestOptions)
        }
        
    }
    
    
    
    
    
    public var remoteId: String? {
        get {
            return cuckoo_manager.getter("remoteId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.remoteId)
        }
        
        set {
            cuckoo_manager.setter("remoteId",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.remoteId = newValue)
        }
        
    }
    
    

    

    
    
    
    
    public func handle(data: Data) throws {
        
    return try cuckoo_manager.callThrows(
    """
    handle(data: Data) throws
    """,
            parameters: (data),
            escapingParameters: (data),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data))
        
    }
    
    
    
    
    
    public func handle(error: Error, unsubscribed: Bool)  {
        
    return cuckoo_manager.call(
    """
    handle(error: Error, unsubscribed: Bool)
    """,
            parameters: (error, unsubscribed),
            escapingParameters: (error, unsubscribed),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error, unsubscribed: unsubscribed))
        
    }
    
    

    public struct __StubbingProxy_JSONRPCSubscribing: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var requestId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, UInt16> {
            return .init(manager: cuckoo_manager, name: "requestId")
        }
        
        
        
        
        var requestData: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, Data> {
            return .init(manager: cuckoo_manager, name: "requestData")
        }
        
        
        
        
        var requestOptions: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, JSONRPCOptions> {
            return .init(manager: cuckoo_manager, name: "requestOptions")
        }
        
        
        
        
        var remoteId: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockJSONRPCSubscribing, String> {
            return .init(manager: cuckoo_manager, name: "remoteId")
        }
        
        
        
        
        
        func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data)> where M1.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method:
    """
    handle(data: Data) throws
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, Bool)> where M1.MatchedType == Error, M2.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method:
    """
    handle(error: Error, unsubscribed: Bool)
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_JSONRPCSubscribing: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var requestId: Cuckoo.VerifyReadOnlyProperty<UInt16> {
            return .init(manager: cuckoo_manager, name: "requestId", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var requestData: Cuckoo.VerifyReadOnlyProperty<Data> {
            return .init(manager: cuckoo_manager, name: "requestData", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var requestOptions: Cuckoo.VerifyReadOnlyProperty<JSONRPCOptions> {
            return .init(manager: cuckoo_manager, name: "requestOptions", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var remoteId: Cuckoo.VerifyOptionalProperty<String> {
            return .init(manager: cuckoo_manager, name: "remoteId", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.__DoNotUse<(Data), Void> where M1.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
            return cuckoo_manager.verify(
    """
    handle(data: Data) throws
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.__DoNotUse<(Error, Bool), Void> where M1.MatchedType == Error, M2.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
            return cuckoo_manager.verify(
    """
    handle(error: Error, unsubscribed: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class JSONRPCSubscribingStub: JSONRPCSubscribing {
    
    
    
    
    public var requestId: UInt16 {
        get {
            return DefaultValueRegistry.defaultValue(for: (UInt16).self)
        }
        
    }
    
    
    
    
    
    public var requestData: Data {
        get {
            return DefaultValueRegistry.defaultValue(for: (Data).self)
        }
        
    }
    
    
    
    
    
    public var requestOptions: JSONRPCOptions {
        get {
            return DefaultValueRegistry.defaultValue(for: (JSONRPCOptions).self)
        }
        
    }
    
    
    
    
    
    public var remoteId: String? {
        get {
            return DefaultValueRegistry.defaultValue(for: (String?).self)
        }
        
        set { }
        
    }
    
    

    

    
    
    
    
    public func handle(data: Data) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func handle(error: Error, unsubscribed: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










public class MockJSONRPCEngine: JSONRPCEngine, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCEngine
    
    public typealias Stubbing = __StubbingProxy_JSONRPCEngine
    public typealias Verification = __VerificationProxy_JSONRPCEngine

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCEngine?

    public func enableDefaultImplementation(_ stub: JSONRPCEngine) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
    public var url: URL? {
        get {
            return cuckoo_manager.getter("url",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.url)
        }
        
        set {
            cuckoo_manager.setter("url",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.url = newValue)
        }
        
    }
    
    
    
    
    
    public var pendingEngineRequests: [JSONRPCRequest] {
        get {
            return cuckoo_manager.getter("pendingEngineRequests",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.pendingEngineRequests)
        }
        
    }
    
    

    

    
    
    
    
    public func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows(
    """
    callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16
    """,
            parameters: (method, params, options, closure),
            escapingParameters: (method, params, options, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.callMethod(method, params: params, options: options, completion: closure))
        
    }
    
    
    
    
    
    public func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows(
    """
    subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16
    """,
            parameters: (method, params, updateClosure, failureClosure),
            escapingParameters: (method, params, updateClosure, failureClosure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe(method, params: params, updateClosure: updateClosure, failureClosure: failureClosure))
        
    }
    
    
    
    
    
    public func cancelForIdentifier(_ identifier: UInt16)  {
        
    return cuckoo_manager.call(
    """
    cancelForIdentifier(_: UInt16)
    """,
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancelForIdentifier(identifier))
        
    }
    
    
    
    
    
    public func generateRequestId() -> UInt16 {
        
    return cuckoo_manager.call(
    """
    generateRequestId() -> UInt16
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.generateRequestId())
        
    }
    
    
    
    
    
    public func addSubscription(_ subscription: JSONRPCSubscribing)  {
        
    return cuckoo_manager.call(
    """
    addSubscription(_: JSONRPCSubscribing)
    """,
            parameters: (subscription),
            escapingParameters: (subscription),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addSubscription(subscription))
        
    }
    
    
    
    
    
    public func reconnect(url: URL)  {
        
    return cuckoo_manager.call(
    """
    reconnect(url: URL)
    """,
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reconnect(url: url))
        
    }
    
    
    
    
    
    public func connectIfNeeded()  {
        
    return cuckoo_manager.call(
    """
    connectIfNeeded()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.connectIfNeeded())
        
    }
    
    
    
    
    
    public func disconnectIfNeeded()  {
        
    return cuckoo_manager.call(
    """
    disconnectIfNeeded()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.disconnectIfNeeded())
        
    }
    
    

    public struct __StubbingProxy_JSONRPCEngine: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var url: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockJSONRPCEngine, URL> {
            return .init(manager: cuckoo_manager, name: "url")
        }
        
        
        
        
        var pendingEngineRequests: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCEngine, [JSONRPCRequest]> {
            return .init(manager: cuckoo_manager, name: "pendingEngineRequests")
        }
        
        
        
        
        
        func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, updateClosure: M3, failureClosure: M4) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == (T) -> Void, M4.MatchedType == (Error, Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }, wrap(matchable: failureClosure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UInt16)> where M1.MatchedType == UInt16 {
            let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    cancelForIdentifier(_: UInt16)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func generateRequestId() -> Cuckoo.ProtocolStubFunction<(), UInt16> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    generateRequestId() -> UInt16
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func addSubscription<M1: Cuckoo.Matchable>(_ subscription: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(JSONRPCSubscribing)> where M1.MatchedType == JSONRPCSubscribing {
            let matchers: [Cuckoo.ParameterMatcher<(JSONRPCSubscribing)>] = [wrap(matchable: subscription) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    addSubscription(_: JSONRPCSubscribing)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func reconnect<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    reconnect(url: URL)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func connectIfNeeded() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    connectIfNeeded()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func disconnectIfNeeded() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method:
    """
    disconnectIfNeeded()
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_JSONRPCEngine: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var url: Cuckoo.VerifyOptionalProperty<URL> {
            return .init(manager: cuckoo_manager, name: "url", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var pendingEngineRequests: Cuckoo.VerifyReadOnlyProperty<[JSONRPCRequest]> {
            return .init(manager: cuckoo_manager, name: "pendingEngineRequests", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, updateClosure: M3, failureClosure: M4) -> Cuckoo.__DoNotUse<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == (T) -> Void, M4.MatchedType == (Error, Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }, wrap(matchable: failureClosure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.__DoNotUse<(UInt16), Void> where M1.MatchedType == UInt16 {
            let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
    """
    cancelForIdentifier(_: UInt16)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func generateRequestId() -> Cuckoo.__DoNotUse<(), UInt16> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    generateRequestId() -> UInt16
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func addSubscription<M1: Cuckoo.Matchable>(_ subscription: M1) -> Cuckoo.__DoNotUse<(JSONRPCSubscribing), Void> where M1.MatchedType == JSONRPCSubscribing {
            let matchers: [Cuckoo.ParameterMatcher<(JSONRPCSubscribing)>] = [wrap(matchable: subscription) { $0 }]
            return cuckoo_manager.verify(
    """
    addSubscription(_: JSONRPCSubscribing)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func reconnect<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return cuckoo_manager.verify(
    """
    reconnect(url: URL)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func connectIfNeeded() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    connectIfNeeded()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func disconnectIfNeeded() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    disconnectIfNeeded()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class JSONRPCEngineStub: JSONRPCEngine {
    
    
    
    
    public var url: URL? {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL?).self)
        }
        
        set { }
        
    }
    
    
    
    
    
    public var pendingEngineRequests: [JSONRPCRequest] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([JSONRPCRequest]).self)
        }
        
    }
    
    

    

    
    
    
    
    public func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
    
    
    
    
    public func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
    
    
    
    
    public func cancelForIdentifier(_ identifier: UInt16)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func generateRequestId() -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
    
    
    
    
    public func addSubscription(_ subscription: JSONRPCSubscribing)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func reconnect(url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func connectIfNeeded()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func disconnectIfNeeded()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






public class MockKeystoreProtocol: KeystoreProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = KeystoreProtocol
    
    public typealias Stubbing = __StubbingProxy_KeystoreProtocol
    public typealias Verification = __VerificationProxy_KeystoreProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: KeystoreProtocol?

    public func enableDefaultImplementation(_ stub: KeystoreProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
    public func addKey(_ key: Data, with identifier: String) throws {
        
    return try cuckoo_manager.callThrows(
    """
    addKey(_: Data, with: String) throws
    """,
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addKey(key, with: identifier))
        
    }
    
    
    
    
    
    public func updateKey(_ key: Data, with identifier: String) throws {
        
    return try cuckoo_manager.callThrows(
    """
    updateKey(_: Data, with: String) throws
    """,
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateKey(key, with: identifier))
        
    }
    
    
    
    
    
    public func fetchKey(for identifier: String) throws -> Data {
        
    return try cuckoo_manager.callThrows(
    """
    fetchKey(for: String) throws -> Data
    """,
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchKey(for: identifier))
        
    }
    
    
    
    
    
    public func checkKey(for identifier: String) throws -> Bool {
        
    return try cuckoo_manager.callThrows(
    """
    checkKey(for: String) throws -> Bool
    """,
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkKey(for: identifier))
        
    }
    
    
    
    
    
    public func deleteKey(for identifier: String) throws {
        
    return try cuckoo_manager.callThrows(
    """
    deleteKey(for: String) throws
    """,
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.deleteKey(for: identifier))
        
    }
    
    

    public struct __StubbingProxy_KeystoreProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String)> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method:
    """
    addKey(_: Data, with: String) throws
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String)> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method:
    """
    updateKey(_: Data, with: String) throws
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Data> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method:
    """
    fetchKey(for: String) throws -> Data
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method:
    """
    checkKey(for: String) throws -> Bool
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(String)> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method:
    """
    deleteKey(for: String) throws
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_KeystoreProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
            return cuckoo_manager.verify(
    """
    addKey(_: Data, with: String) throws
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
            return cuckoo_manager.verify(
    """
    updateKey(_: Data, with: String) throws
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Data> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
    """
    fetchKey(for: String) throws -> Data
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
    """
    checkKey(for: String) throws -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
    """
    deleteKey(for: String) throws
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class KeystoreProtocolStub: KeystoreProtocol {
    

    

    
    
    
    
    public func addKey(_ key: Data, with identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func updateKey(_ key: Data, with identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func fetchKey(for identifier: String) throws -> Data  {
        return DefaultValueRegistry.defaultValue(for: (Data).self)
    }
    
    
    
    
    
    public func checkKey(for identifier: String) throws -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    
    
    public func deleteKey(for identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










public class MockSecretDataRepresentable: SecretDataRepresentable, Cuckoo.ProtocolMock {
    
    public typealias MocksType = SecretDataRepresentable
    
    public typealias Stubbing = __StubbingProxy_SecretDataRepresentable
    public typealias Verification = __VerificationProxy_SecretDataRepresentable

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecretDataRepresentable?

    public func enableDefaultImplementation(_ stub: SecretDataRepresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
    public func asSecretData() -> Data? {
        
    return cuckoo_manager.call(
    """
    asSecretData() -> Data?
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.asSecretData())
        
    }
    
    

    public struct __StubbingProxy_SecretDataRepresentable: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func asSecretData() -> Cuckoo.ProtocolStubFunction<(), Data?> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSecretDataRepresentable.self, method:
    """
    asSecretData() -> Data?
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_SecretDataRepresentable: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func asSecretData() -> Cuckoo.__DoNotUse<(), Data?> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    asSecretData() -> Data?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class SecretDataRepresentableStub: SecretDataRepresentable {
    

    

    
    
    
    
    public func asSecretData() -> Data?  {
        return DefaultValueRegistry.defaultValue(for: (Data?).self)
    }
    
    
}










public class MockSecretStoreManagerProtocol: SecretStoreManagerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = SecretStoreManagerProtocol
    
    public typealias Stubbing = __StubbingProxy_SecretStoreManagerProtocol
    public typealias Verification = __VerificationProxy_SecretStoreManagerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecretStoreManagerProtocol?

    public func enableDefaultImplementation(_ stub: SecretStoreManagerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
    public func loadSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)  {
        
    return cuckoo_manager.call(
    """
    loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)
    """,
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.loadSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    
    
    public func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call(
    """
    saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
            parameters: (secret, identifier, completionQueue, completionBlock),
            escapingParameters: (secret, identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveSecret(secret, for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    
    
    public func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call(
    """
    removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    
    
    public func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call(
    """
    checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    
    
    public func checkSecret(for identifier: String) -> Bool {
        
    return cuckoo_manager.call(
    """
    checkSecret(for: String) -> Bool
    """,
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSecret(for: identifier))
        
    }
    
    

    public struct __StubbingProxy_SecretStoreManagerProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (SecretDataRepresentable?) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method:
    """
    loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method:
    """
    saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method:
    """
    removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method:
    """
    checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubFunction<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method:
    """
    checkSecret(for: String) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
    }

    public struct __VerificationProxy_SecretStoreManagerProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (SecretDataRepresentable?) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (SecretDataRepresentable?) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return cuckoo_manager.verify(
    """
    loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.__DoNotUse<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
            return cuckoo_manager.verify(
    """
    saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return cuckoo_manager.verify(
    """
    removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return cuckoo_manager.verify(
    """
    checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
    """
    checkSecret(for: String) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


public class SecretStoreManagerProtocolStub: SecretStoreManagerProtocol {
    

    

    
    
    
    
    public func loadSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
    public func checkSecret(for identifier: String) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






 class MockEventProtocol: EventProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventProtocol
    
     typealias Stubbing = __StubbingProxy_EventProtocol
     typealias Verification = __VerificationProxy_EventProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventProtocol?

     func enableDefaultImplementation(_ stub: EventProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func accept(visitor: EventVisitorProtocol)  {
        
    return cuckoo_manager.call(
    """
    accept(visitor: EventVisitorProtocol)
    """,
            parameters: (visitor),
            escapingParameters: (visitor),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.accept(visitor: visitor))
        
    }
    
    

     struct __StubbingProxy_EventProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self, method:
    """
    accept(visitor: EventVisitorProtocol)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_EventProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
            return cuckoo_manager.verify(
    """
    accept(visitor: EventVisitorProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class EventProtocolStub: EventProtocol {
    

    

    
    
    
    
     func accept(visitor: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockEventCenterProtocol: EventCenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventCenterProtocol
    
     typealias Stubbing = __StubbingProxy_EventCenterProtocol
     typealias Verification = __VerificationProxy_EventCenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventCenterProtocol?

     func enableDefaultImplementation(_ stub: EventCenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func notify(with event: EventProtocol)  {
        
    return cuckoo_manager.call(
    """
    notify(with: EventProtocol)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notify(with: event))
        
    }
    
    
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)  {
        
    return cuckoo_manager.call(
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """,
            parameters: (observer, queue),
            escapingParameters: (observer, queue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer, dispatchIn: queue))
        
    }
    
    
    
    
    
     func remove(observer: EventVisitorProtocol)  {
        
    return cuckoo_manager.call(
    """
    remove(observer: EventVisitorProtocol)
    """,
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(observer: observer))
        
    }
    
    

     struct __StubbingProxy_EventCenterProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventProtocol)> where M1.MatchedType == EventProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    notify(with: EventProtocol)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    remove(observer: EventVisitorProtocol)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_EventCenterProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.__DoNotUse<(EventProtocol), Void> where M1.MatchedType == EventProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    notify(with: EventProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
            return cuckoo_manager.verify(
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
            return cuckoo_manager.verify(
    """
    remove(observer: EventVisitorProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class EventCenterProtocolStub: EventCenterProtocol {
    

    

    
    
    
    
     func notify(with event: EventProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func remove(observer: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import IrohaCrypto
import RobinHood






 class MockAccountRepositoryFactoryProtocol: AccountRepositoryFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountRepositoryFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_AccountRepositoryFactoryProtocol
     typealias Verification = __VerificationProxy_AccountRepositoryFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountRepositoryFactoryProtocol?

     func enableDefaultImplementation(_ stub: AccountRepositoryFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
    @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
    
     func createRepository() -> AnyDataProviderRepository<MetaAccountModel> {
        
    return cuckoo_manager.call(
    """
    createRepository() -> AnyDataProviderRepository<MetaAccountModel>
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createRepository())
        
    }
    
    
    
    
    
     func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel> {
        
    return cuckoo_manager.call(
    """
    createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>
    """,
            parameters: (networkType),
            escapingParameters: (networkType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createAccountRepository(for: networkType))
        
    }
    
    
    
    
    
     func createMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel> {
        
    return cuckoo_manager.call(
    """
    createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>
    """,
            parameters: (filter, sortDescriptors),
            escapingParameters: (filter, sortDescriptors),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createMetaAccountRepository(for: filter, sortDescriptors: sortDescriptors))
        
    }
    
    
    
    
    
     func createManagedMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        
    return cuckoo_manager.call(
    """
    createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>
    """,
            parameters: (filter, sortDescriptors),
            escapingParameters: (filter, sortDescriptors),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createManagedMetaAccountRepository(for: filter, sortDescriptors: sortDescriptors))
        
    }
    
    

     struct __StubbingProxy_AccountRepositoryFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
        
        func createRepository() -> Cuckoo.ProtocolStubFunction<(), AnyDataProviderRepository<MetaAccountModel>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method:
    """
    createRepository() -> AnyDataProviderRepository<MetaAccountModel>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func createAccountRepository<M1: Cuckoo.Matchable>(for networkType: M1) -> Cuckoo.ProtocolStubFunction<(SNAddressType), AnyDataProviderRepository<MetaAccountModel>> where M1.MatchedType == SNAddressType {
            let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: networkType) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method:
    """
    createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method:
    """
    createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method:
    """
    createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_AccountRepositoryFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
        
        @discardableResult
        func createRepository() -> Cuckoo.__DoNotUse<(), AnyDataProviderRepository<MetaAccountModel>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    createRepository() -> AnyDataProviderRepository<MetaAccountModel>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func createAccountRepository<M1: Cuckoo.Matchable>(for networkType: M1) -> Cuckoo.__DoNotUse<(SNAddressType), AnyDataProviderRepository<MetaAccountModel>> where M1.MatchedType == SNAddressType {
            let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: networkType) { $0 }]
            return cuckoo_manager.verify(
    """
    createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
            return cuckoo_manager.verify(
    """
    createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
            return cuckoo_manager.verify(
    """
    createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class AccountRepositoryFactoryProtocolStub: AccountRepositoryFactoryProtocol {
    

    

    
    
    
    
    @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
    
     func createRepository() -> AnyDataProviderRepository<MetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    
    
    
    
     func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    
    
    
    
     func createMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    
    
    
    
     func createManagedMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<ManagedMetaAccountModel>).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






 class MockSchedulerProtocol: SchedulerProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SchedulerProtocol
    
     typealias Stubbing = __StubbingProxy_SchedulerProtocol
     typealias Verification = __VerificationProxy_SchedulerProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SchedulerProtocol?

     func enableDefaultImplementation(_ stub: SchedulerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func notifyAfter(_ seconds: TimeInterval)  {
        
    return cuckoo_manager.call(
    """
    notifyAfter(_: TimeInterval)
    """,
            parameters: (seconds),
            escapingParameters: (seconds),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notifyAfter(seconds))
        
    }
    
    
    
    
    
     func cancel()  {
        
    return cuckoo_manager.call(
    """
    cancel()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancel())
        
    }
    
    

     struct __StubbingProxy_SchedulerProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func notifyAfter<M1: Cuckoo.Matchable>(_ seconds: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: seconds) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method:
    """
    notifyAfter(_: TimeInterval)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method:
    """
    cancel()
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_SchedulerProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func notifyAfter<M1: Cuckoo.Matchable>(_ seconds: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: seconds) { $0 }]
            return cuckoo_manager.verify(
    """
    notifyAfter(_: TimeInterval)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func cancel() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    cancel()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class SchedulerProtocolStub: SchedulerProtocol {
    

    

    
    
    
    
     func notifyAfter(_ seconds: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func cancel()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockSchedulerDelegate: SchedulerDelegate, Cuckoo.ProtocolMock {
    
     typealias MocksType = SchedulerDelegate
    
     typealias Stubbing = __StubbingProxy_SchedulerDelegate
     typealias Verification = __VerificationProxy_SchedulerDelegate

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SchedulerDelegate?

     func enableDefaultImplementation(_ stub: SchedulerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func didTrigger(scheduler: SchedulerProtocol)  {
        
    return cuckoo_manager.call(
    """
    didTrigger(scheduler: SchedulerProtocol)
    """,
            parameters: (scheduler),
            escapingParameters: (scheduler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didTrigger(scheduler: scheduler))
        
    }
    
    

     struct __StubbingProxy_SchedulerDelegate: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func didTrigger<M1: Cuckoo.Matchable>(scheduler: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SchedulerProtocol)> where M1.MatchedType == SchedulerProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: scheduler) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerDelegate.self, method:
    """
    didTrigger(scheduler: SchedulerProtocol)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_SchedulerDelegate: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func didTrigger<M1: Cuckoo.Matchable>(scheduler: M1) -> Cuckoo.__DoNotUse<(SchedulerProtocol), Void> where M1.MatchedType == SchedulerProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: scheduler) { $0 }]
            return cuckoo_manager.verify(
    """
    didTrigger(scheduler: SchedulerProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class SchedulerDelegateStub: SchedulerDelegate {
    

    

    
    
    
    
     func didTrigger(scheduler: SchedulerProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import LocalAuthentication
import UIKit.UIImage






 class MockBiometryAuthProtocol: BiometryAuthProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = BiometryAuthProtocol
    
     typealias Stubbing = __StubbingProxy_BiometryAuthProtocol
     typealias Verification = __VerificationProxy_BiometryAuthProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: BiometryAuthProtocol?

     func enableDefaultImplementation(_ stub: BiometryAuthProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
     var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    
    

    

    
    
    
    
     func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    

     struct __StubbingProxy_BiometryAuthProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var availableBiometryType: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockBiometryAuthProtocol, AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType")
        }
        
        
        
        
        
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self, method:
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_BiometryAuthProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return cuckoo_manager.verify(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class BiometryAuthProtocolStub: BiometryAuthProtocol {
    
    
    
    
     var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    
    

    

    
    
    
    
     func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockBiometryAuth: BiometryAuth, Cuckoo.ClassMock {
    
     typealias MocksType = BiometryAuth
    
     typealias Stubbing = __StubbingProxy_BiometryAuth
     typealias Verification = __VerificationProxy_BiometryAuth

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: BiometryAuth?

     func enableDefaultImplementation(_ stub: BiometryAuth) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
     override var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    super.availableBiometryType
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    
    

    

    
    
    
    
     override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                super.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock)
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    

     struct __StubbingProxy_BiometryAuth: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var availableBiometryType: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockBiometryAuth, AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType")
        }
        
        
        
        
        
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ClassStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self, method:
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_BiometryAuth: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
            return cuckoo_manager.verify(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class BiometryAuthStub: BiometryAuth {
    
    
    
    
     override var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    
    

    

    
    
    
    
     override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood






 class MockDataOperationFactoryProtocol: DataOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DataOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_DataOperationFactoryProtocol
     typealias Verification = __VerificationProxy_DataOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DataOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: DataOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func fetchData(from url: URL) -> BaseOperation<Data> {
        
    return cuckoo_manager.call(
    """
    fetchData(from: URL) -> BaseOperation<Data>
    """,
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchData(from: url))
        
    }
    
    

     struct __StubbingProxy_DataOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func fetchData<M1: Cuckoo.Matchable>(from url: M1) -> Cuckoo.ProtocolStubFunction<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockDataOperationFactoryProtocol.self, method:
    """
    fetchData(from: URL) -> BaseOperation<Data>
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_DataOperationFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func fetchData<M1: Cuckoo.Matchable>(from url: M1) -> Cuckoo.__DoNotUse<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return cuckoo_manager.verify(
    """
    fetchData(from: URL) -> BaseOperation<Data>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class DataOperationFactoryProtocolStub: DataOperationFactoryProtocol {
    

    

    
    
    
    
     func fetchData(from url: URL) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import RobinHood






 class MockSubstrateOperationFactoryProtocol: SubstrateOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SubstrateOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_SubstrateOperationFactoryProtocol
     typealias Verification = __VerificationProxy_SubstrateOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SubstrateOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: SubstrateOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        
    return cuckoo_manager.call(
    """
    fetchChainOperation(_: URL) -> BaseOperation<String>
    """,
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchChainOperation(url))
        
    }
    
    

     struct __StubbingProxy_SubstrateOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func fetchChainOperation<M1: Cuckoo.Matchable>(_ url: M1) -> Cuckoo.ProtocolStubFunction<(URL), BaseOperation<String>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSubstrateOperationFactoryProtocol.self, method:
    """
    fetchChainOperation(_: URL) -> BaseOperation<String>
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_SubstrateOperationFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func fetchChainOperation<M1: Cuckoo.Matchable>(_ url: M1) -> Cuckoo.__DoNotUse<(URL), BaseOperation<String>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return cuckoo_manager.verify(
    """
    fetchChainOperation(_: URL) -> BaseOperation<String>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class SubstrateOperationFactoryProtocolStub: SubstrateOperationFactoryProtocol {
    

    

    
    
    
    
     func fetchChainOperation(_ url: URL) -> BaseOperation<String>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<String>).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import RobinHood






 class MockChainRegistryProtocol: ChainRegistryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ChainRegistryProtocol
    
     typealias Stubbing = __StubbingProxy_ChainRegistryProtocol
     typealias Verification = __VerificationProxy_ChainRegistryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ChainRegistryProtocol?

     func enableDefaultImplementation(_ stub: ChainRegistryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
     var availableChainIds: Set<ChainModel.Id>? {
        get {
            return cuckoo_manager.getter("availableChainIds",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableChainIds)
        }
        
    }
    
    

    

    
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        
    return cuckoo_manager.call(
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getConnection(for: chainId))
        
    }
    
    
    
    
    
     func setupConnection(for chainModel: ChainModel) -> ChainConnection? {
        
    return cuckoo_manager.call(
    """
    setupConnection(for: ChainModel) -> ChainConnection?
    """,
            parameters: (chainModel),
            escapingParameters: (chainModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupConnection(for: chainModel))
        
    }
    
    
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        
    return cuckoo_manager.call(
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: chainId))
        
    }
    
    
    
    
    
     func chainsSubscribe(_ target: AnyObject, runningInQueue: DispatchQueue, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)  {
        
    return cuckoo_manager.call(
    """
    chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)
    """,
            parameters: (target, runningInQueue, updateClosure),
            escapingParameters: (target, runningInQueue, updateClosure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.chainsSubscribe(target, runningInQueue: runningInQueue, updateClosure: updateClosure))
        
    }
    
    
    
    
    
     func chainsUnsubscribe(_ target: AnyObject)  {
        
    return cuckoo_manager.call(
    """
    chainsUnsubscribe(_: AnyObject)
    """,
            parameters: (target),
            escapingParameters: (target),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.chainsUnsubscribe(target))
        
    }
    
    
    
    
    
     func syncUp()  {
        
    return cuckoo_manager.call(
    """
    syncUp()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.syncUp())
        
    }
    
    
    
    
    
     func performHotBoot()  {
        
    return cuckoo_manager.call(
    """
    performHotBoot()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.performHotBoot())
        
    }
    
    
    
    
    
     func performColdBoot()  {
        
    return cuckoo_manager.call(
    """
    performColdBoot()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.performColdBoot())
        
    }
    
    
    
    
    
     func subscribeToChians()  {
        
    return cuckoo_manager.call(
    """
    subscribeToChians()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribeToChians())
        
    }
    
    

     struct __StubbingProxy_ChainRegistryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var availableChainIds: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockChainRegistryProtocol, Set<ChainModel.Id>?> {
            return .init(manager: cuckoo_manager, name: "availableChainIds")
        }
        
        
        
        
        
        func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func setupConnection<M1: Cuckoo.Matchable>(for chainModel: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel), ChainConnection?> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chainModel) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    setupConnection(for: ChainModel) -> ChainConnection?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ target: M1, runningInQueue: M2, updateClosure: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject, DispatchQueue, ([DataProviderChange<ChainModel>]) -> Void)> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.MatchedType == ([DataProviderChange<ChainModel>]) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue, ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: target) { $0.0 }, wrap(matchable: runningInQueue) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ target: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject)> where M1.MatchedType == AnyObject {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: target) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    chainsUnsubscribe(_: AnyObject)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func syncUp() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    syncUp()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func performHotBoot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    performHotBoot()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func performColdBoot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    performColdBoot()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func subscribeToChians() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method:
    """
    subscribeToChians()
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_ChainRegistryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var availableChainIds: Cuckoo.VerifyReadOnlyProperty<Set<ChainModel.Id>?> {
            return .init(manager: cuckoo_manager, name: "availableChainIds", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func setupConnection<M1: Cuckoo.Matchable>(for chainModel: M1) -> Cuckoo.__DoNotUse<(ChainModel), ChainConnection?> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chainModel) { $0 }]
            return cuckoo_manager.verify(
    """
    setupConnection(for: ChainModel) -> ChainConnection?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ target: M1, runningInQueue: M2, updateClosure: M3) -> Cuckoo.__DoNotUse<(AnyObject, DispatchQueue, ([DataProviderChange<ChainModel>]) -> Void), Void> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.MatchedType == ([DataProviderChange<ChainModel>]) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue, ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: target) { $0.0 }, wrap(matchable: runningInQueue) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }]
            return cuckoo_manager.verify(
    """
    chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ target: M1) -> Cuckoo.__DoNotUse<(AnyObject), Void> where M1.MatchedType == AnyObject {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: target) { $0 }]
            return cuckoo_manager.verify(
    """
    chainsUnsubscribe(_: AnyObject)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func syncUp() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    syncUp()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func performHotBoot() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    performHotBoot()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func performColdBoot() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    performColdBoot()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func subscribeToChians() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    subscribeToChians()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ChainRegistryProtocolStub: ChainRegistryProtocol {
    
    
    
    
     var availableChainIds: Set<ChainModel.Id>? {
        get {
            return DefaultValueRegistry.defaultValue(for: (Set<ChainModel.Id>?).self)
        }
        
    }
    
    

    

    
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection?  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    
    
    
    
     func setupConnection(for chainModel: ChainModel) -> ChainConnection?  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
    
    
    
    
    
     func chainsSubscribe(_ target: AnyObject, runningInQueue: DispatchQueue, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func chainsUnsubscribe(_ target: AnyObject)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func syncUp()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func performHotBoot()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func performColdBoot()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func subscribeToChians()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation






 class MockConnectionFactoryProtocol: ConnectionFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ConnectionFactoryProtocol
     typealias Verification = __VerificationProxy_ConnectionFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionFactoryProtocol?

     func enableDefaultImplementation(_ stub: ConnectionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func createConnection(connectionName: String?, for url: URL, delegate: WebSocketEngineDelegate) -> ChainConnection {
        
    return cuckoo_manager.call(
    """
    createConnection(connectionName: String?, for: URL, delegate: WebSocketEngineDelegate) -> ChainConnection
    """,
            parameters: (connectionName, url, delegate),
            escapingParameters: (connectionName, url, delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createConnection(connectionName: connectionName, for: url, delegate: delegate))
        
    }
    
    

     struct __StubbingProxy_ConnectionFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func createConnection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(connectionName: M1, for url: M2, delegate: M3) -> Cuckoo.ProtocolStubFunction<(String?, URL, WebSocketEngineDelegate), ChainConnection> where M1.OptionalMatchedType == String, M2.MatchedType == URL, M3.MatchedType == WebSocketEngineDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(String?, URL, WebSocketEngineDelegate)>] = [wrap(matchable: connectionName) { $0.0 }, wrap(matchable: url) { $0.1 }, wrap(matchable: delegate) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method:
    """
    createConnection(connectionName: String?, for: URL, delegate: WebSocketEngineDelegate) -> ChainConnection
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_ConnectionFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func createConnection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(connectionName: M1, for url: M2, delegate: M3) -> Cuckoo.__DoNotUse<(String?, URL, WebSocketEngineDelegate), ChainConnection> where M1.OptionalMatchedType == String, M2.MatchedType == URL, M3.MatchedType == WebSocketEngineDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(String?, URL, WebSocketEngineDelegate)>] = [wrap(matchable: connectionName) { $0.0 }, wrap(matchable: url) { $0.1 }, wrap(matchable: delegate) { $0.2 }]
            return cuckoo_manager.verify(
    """
    createConnection(connectionName: String?, for: URL, delegate: WebSocketEngineDelegate) -> ChainConnection
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ConnectionFactoryProtocolStub: ConnectionFactoryProtocol {
    

    

    
    
    
    
     func createConnection(connectionName: String?, for url: URL, delegate: WebSocketEngineDelegate) -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import SoraFoundation






 class MockConnectionPoolProtocol: ConnectionPoolProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionPoolProtocol
    
     typealias Stubbing = __StubbingProxy_ConnectionPoolProtocol
     typealias Verification = __VerificationProxy_ConnectionPoolProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionPoolProtocol?

     func enableDefaultImplementation(_ stub: ConnectionPoolProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        
    return try cuckoo_manager.callThrows(
    """
    setupConnection(for: ChainModel) throws -> ChainConnection
    """,
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupConnection(for: chain))
        
    }
    
    
    
    
    
     func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection {
        
    return try cuckoo_manager.callThrows(
    """
    setupConnection(for: ChainModel, ignoredUrl: URL?) throws -> ChainConnection
    """,
            parameters: (chain, ignoredUrl),
            escapingParameters: (chain, ignoredUrl),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupConnection(for: chain, ignoredUrl: ignoredUrl))
        
    }
    
    
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        
    return cuckoo_manager.call(
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getConnection(for: chainId))
        
    }
    
    
    
    
    
     func setDelegate(_ delegate: ConnectionPoolDelegate)  {
        
    return cuckoo_manager.call(
    """
    setDelegate(_: ConnectionPoolDelegate)
    """,
            parameters: (delegate),
            escapingParameters: (delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setDelegate(delegate))
        
    }
    
    

     struct __StubbingProxy_ConnectionPoolProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func setupConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel), ChainConnection> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method:
    """
    setupConnection(for: ChainModel) throws -> ChainConnection
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func setupConnection<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, ignoredUrl: M2) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel, URL?), ChainConnection> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, URL?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: ignoredUrl) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method:
    """
    setupConnection(for: ChainModel, ignoredUrl: URL?) throws -> ChainConnection
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method:
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func setDelegate<M1: Cuckoo.Matchable>(_ delegate: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionPoolDelegate)> where M1.MatchedType == ConnectionPoolDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(ConnectionPoolDelegate)>] = [wrap(matchable: delegate) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method:
    """
    setDelegate(_: ConnectionPoolDelegate)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_ConnectionPoolProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func setupConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), ChainConnection> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
            return cuckoo_manager.verify(
    """
    setupConnection(for: ChainModel) throws -> ChainConnection
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func setupConnection<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, ignoredUrl: M2) -> Cuckoo.__DoNotUse<(ChainModel, URL?), ChainConnection> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, URL?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: ignoredUrl) { $0.1 }]
            return cuckoo_manager.verify(
    """
    setupConnection(for: ChainModel, ignoredUrl: URL?) throws -> ChainConnection
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    getConnection(for: ChainModel.Id) -> ChainConnection?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func setDelegate<M1: Cuckoo.Matchable>(_ delegate: M1) -> Cuckoo.__DoNotUse<(ConnectionPoolDelegate), Void> where M1.MatchedType == ConnectionPoolDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(ConnectionPoolDelegate)>] = [wrap(matchable: delegate) { $0 }]
            return cuckoo_manager.verify(
    """
    setDelegate(_: ConnectionPoolDelegate)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ConnectionPoolProtocolStub: ConnectionPoolProtocol {
    

    

    
    
    
    
     func setupConnection(for chain: ChainModel) throws -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
    
    
    
     func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection?  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    
    
    
    
     func setDelegate(_ delegate: ConnectionPoolDelegate)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockConnectionPoolDelegate: ConnectionPoolDelegate, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionPoolDelegate
    
     typealias Stubbing = __StubbingProxy_ConnectionPoolDelegate
     typealias Verification = __VerificationProxy_ConnectionPoolDelegate

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionPoolDelegate?

     func enableDefaultImplementation(_ stub: ConnectionPoolDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func webSocketDidChangeState(url: URL, state: WebSocketEngine.State)  {
        
    return cuckoo_manager.call(
    """
    webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
    """,
            parameters: (url, state),
            escapingParameters: (url, state),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.webSocketDidChangeState(url: url, state: state))
        
    }
    
    

     struct __StubbingProxy_ConnectionPoolDelegate: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func webSocketDidChangeState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(url: M1, state: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, WebSocketEngine.State)> where M1.MatchedType == URL, M2.MatchedType == WebSocketEngine.State {
            let matchers: [Cuckoo.ParameterMatcher<(URL, WebSocketEngine.State)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: state) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolDelegate.self, method:
    """
    webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_ConnectionPoolDelegate: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func webSocketDidChangeState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(url: M1, state: M2) -> Cuckoo.__DoNotUse<(URL, WebSocketEngine.State), Void> where M1.MatchedType == URL, M2.MatchedType == WebSocketEngine.State {
            let matchers: [Cuckoo.ParameterMatcher<(URL, WebSocketEngine.State)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: state) { $0.1 }]
            return cuckoo_manager.verify(
    """
    webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ConnectionPoolDelegateStub: ConnectionPoolDelegate {
    

    

    
    
    
    
     func webSocketDidChangeState(url: URL, state: WebSocketEngine.State)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood






 class MockRuntimeFilesOperationFactoryProtocol: RuntimeFilesOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeFilesOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeFilesOperationFactoryProtocol
     typealias Verification = __VerificationProxy_RuntimeFilesOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeFilesOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: RuntimeFilesOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        
    return cuckoo_manager.call(
    """
    fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCommonTypesOperation())
        
    }
    
    
    
    
    
     func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> {
        
    return cuckoo_manager.call(
    """
    fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchChainsTypesOperation())
        
    }
    
    
    
    
    
     func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        
    return cuckoo_manager.call(
    """
    fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchChainTypesOperation(for: chainId))
        
    }
    
    
    
    
    
     func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        
    return cuckoo_manager.call(
    """
    saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """,
            parameters: (closure),
            escapingParameters: (closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveCommonTypesOperation(data: closure))
        
    }
    
    
    
    
    
     func saveChainsTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        
    return cuckoo_manager.call(
    """
    saveChainsTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """,
            parameters: (closure),
            escapingParameters: (closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveChainsTypesOperation(data: closure))
        
    }
    
    
    
    
    
     func saveChainTypesOperation(for chainId: ChainModel.Id, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        
    return cuckoo_manager.call(
    """
    saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """,
            parameters: (chainId, closure),
            escapingParameters: (chainId, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveChainTypesOperation(for: chainId, data: closure))
        
    }
    
    

     struct __StubbingProxy_RuntimeFilesOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func fetchCommonTypesOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func fetchChainsTypesOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.ProtocolStubFunction<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func saveChainsTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.ProtocolStubFunction<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    saveChainsTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, data closure: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, () throws -> Data)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: closure) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method:
    """
    saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_RuntimeFilesOperationFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func fetchCommonTypesOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func fetchChainsTypesOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.__DoNotUse<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
            return cuckoo_manager.verify(
    """
    saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func saveChainsTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.__DoNotUse<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
            return cuckoo_manager.verify(
    """
    saveChainsTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, data closure: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType == () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, () throws -> Data)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: closure) { $0.1 }]
            return cuckoo_manager.verify(
    """
    saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class RuntimeFilesOperationFactoryProtocolStub: RuntimeFilesOperationFactoryProtocol {
    

    

    
    
    
    
     func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    
    
    
    
     func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    
    
    
    
     func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    
    
    
    
     func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    
    
    
    
     func saveChainsTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    
    
    
    
     func saveChainTypesOperation(for chainId: ChainModel.Id, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import RobinHood






 class MockCommonTypesSyncServiceProtocol: CommonTypesSyncServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = CommonTypesSyncServiceProtocol
    
     typealias Stubbing = __StubbingProxy_CommonTypesSyncServiceProtocol
     typealias Verification = __VerificationProxy_CommonTypesSyncServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CommonTypesSyncServiceProtocol?

     func enableDefaultImplementation(_ stub: CommonTypesSyncServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func syncUp()  {
        
    return cuckoo_manager.call(
    """
    syncUp()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.syncUp())
        
    }
    
    

     struct __StubbingProxy_CommonTypesSyncServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func syncUp() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockCommonTypesSyncServiceProtocol.self, method:
    """
    syncUp()
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_CommonTypesSyncServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func syncUp() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    syncUp()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class CommonTypesSyncServiceProtocolStub: CommonTypesSyncServiceProtocol {
    

    

    
    
    
    
     func syncUp()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockCommonTypesSyncService: CommonTypesSyncService, Cuckoo.ClassMock {
    
     typealias MocksType = CommonTypesSyncService
    
     typealias Stubbing = __StubbingProxy_CommonTypesSyncService
     typealias Verification = __VerificationProxy_CommonTypesSyncService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: CommonTypesSyncService?

     func enableDefaultImplementation(_ stub: CommonTypesSyncService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
     override var isSyncing: Bool {
        get {
            return cuckoo_manager.getter("isSyncing",
                superclassCall:
                    
                    super.isSyncing
                    ,
                defaultCall: __defaultImplStub!.isSyncing)
        }
        
    }
    
    
    
    
    
     override var retryAttempt: Int {
        get {
            return cuckoo_manager.getter("retryAttempt",
                superclassCall:
                    
                    super.retryAttempt
                    ,
                defaultCall: __defaultImplStub!.retryAttempt)
        }
        
    }
    
    

    

    

     struct __StubbingProxy_CommonTypesSyncService: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var isSyncing: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockCommonTypesSyncService, Bool> {
            return .init(manager: cuckoo_manager, name: "isSyncing")
        }
        
        
        
        
        var retryAttempt: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockCommonTypesSyncService, Int> {
            return .init(manager: cuckoo_manager, name: "retryAttempt")
        }
        
        
        
    }

     struct __VerificationProxy_CommonTypesSyncService: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var isSyncing: Cuckoo.VerifyReadOnlyProperty<Bool> {
            return .init(manager: cuckoo_manager, name: "isSyncing", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var retryAttempt: Cuckoo.VerifyReadOnlyProperty<Int> {
            return .init(manager: cuckoo_manager, name: "retryAttempt", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
    }
}


 class CommonTypesSyncServiceStub: CommonTypesSyncService {
    
    
    
    
     override var isSyncing: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
    
    
    
     override var retryAttempt: Int {
        get {
            return DefaultValueRegistry.defaultValue(for: (Int).self)
        }
        
    }
    
    

    

    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood

import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import RobinHood






 class MockRuntimeProviderProtocol: RuntimeProviderProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    
     var chainId: ChainModel.Id {
        get {
            return cuckoo_manager.getter("chainId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.chainId)
        }
        
    }
    
    
    
    
    
     var snapshot: RuntimeSnapshot? {
        get {
            return cuckoo_manager.getter("snapshot",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.snapshot)
        }
        
    }
    
    

    

    
    
    
    
     func setup()  {
        
    return cuckoo_manager.call(
    """
    setup()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
    
    
     func setupHot()  {
        
    return cuckoo_manager.call(
    """
    setupHot()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupHot())
        
    }
    
    
    
    
    
     func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)  {
        
    return cuckoo_manager.call(
    """
    replaceTypesUsage(_: ChainModel.TypesUsage)
    """,
            parameters: (newTypeUsage),
            escapingParameters: (newTypeUsage),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.replaceTypesUsage(newTypeUsage))
        
    }
    
    
    
    
    
     func cleanup()  {
        
    return cuckoo_manager.call(
    """
    cleanup()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cleanup())
        
    }
    
    
    
    
    
     func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        
    return cuckoo_manager.call(
    """
    fetchCoderFactoryOperation(with: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol>
    """,
            parameters: (timeout, closure),
            escapingParameters: (timeout, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCoderFactoryOperation(with: timeout, closure: closure))
        
    }
    
    

     struct __StubbingProxy_RuntimeProviderProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        var chainId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRuntimeProviderProtocol, ChainModel.Id> {
            return .init(manager: cuckoo_manager, name: "chainId")
        }
        
        
        
        
        var snapshot: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRuntimeProviderProtocol, RuntimeSnapshot?> {
            return .init(manager: cuckoo_manager, name: "snapshot")
        }
        
        
        
        
        
        func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method:
    """
    setup()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func setupHot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method:
    """
    setupHot()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func replaceTypesUsage<M1: Cuckoo.Matchable>(_ newTypeUsage: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.TypesUsage)> where M1.MatchedType == ChainModel.TypesUsage {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.TypesUsage)>] = [wrap(matchable: newTypeUsage) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method:
    """
    replaceTypesUsage(_: ChainModel.TypesUsage)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func cleanup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method:
    """
    cleanup()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func fetchCoderFactoryOperation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(with timeout: M1, closure: M2) -> Cuckoo.ProtocolStubFunction<(TimeInterval, RuntimeMetadataClosure?), BaseOperation<RuntimeCoderFactoryProtocol>> where M1.MatchedType == TimeInterval, M2.OptionalMatchedType == RuntimeMetadataClosure {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval, RuntimeMetadataClosure?)>] = [wrap(matchable: timeout) { $0.0 }, wrap(matchable: closure) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method:
    """
    fetchCoderFactoryOperation(with: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol>
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_RuntimeProviderProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
        
        
        var chainId: Cuckoo.VerifyReadOnlyProperty<ChainModel.Id> {
            return .init(manager: cuckoo_manager, name: "chainId", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        
        
        var snapshot: Cuckoo.VerifyReadOnlyProperty<RuntimeSnapshot?> {
            return .init(manager: cuckoo_manager, name: "snapshot", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
    
        
        
        
        @discardableResult
        func setup() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    setup()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func setupHot() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    setupHot()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func replaceTypesUsage<M1: Cuckoo.Matchable>(_ newTypeUsage: M1) -> Cuckoo.__DoNotUse<(ChainModel.TypesUsage), Void> where M1.MatchedType == ChainModel.TypesUsage {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.TypesUsage)>] = [wrap(matchable: newTypeUsage) { $0 }]
            return cuckoo_manager.verify(
    """
    replaceTypesUsage(_: ChainModel.TypesUsage)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func cleanup() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    cleanup()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func fetchCoderFactoryOperation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(with timeout: M1, closure: M2) -> Cuckoo.__DoNotUse<(TimeInterval, RuntimeMetadataClosure?), BaseOperation<RuntimeCoderFactoryProtocol>> where M1.MatchedType == TimeInterval, M2.OptionalMatchedType == RuntimeMetadataClosure {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval, RuntimeMetadataClosure?)>] = [wrap(matchable: timeout) { $0.0 }, wrap(matchable: closure) { $0.1 }]
            return cuckoo_manager.verify(
    """
    fetchCoderFactoryOperation(with: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol>
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class RuntimeProviderProtocolStub: RuntimeProviderProtocol {
    
    
    
    
     var chainId: ChainModel.Id {
        get {
            return DefaultValueRegistry.defaultValue(for: (ChainModel.Id).self)
        }
        
    }
    
    
    
    
    
     var snapshot: RuntimeSnapshot? {
        get {
            return DefaultValueRegistry.defaultValue(for: (RuntimeSnapshot?).self)
        }
        
    }
    
    

    

    
    
    
    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func setupHot()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func cleanup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<RuntimeCoderFactoryProtocol>).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood






 class MockRuntimeProviderFactoryProtocol: RuntimeProviderFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderFactoryProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderFactoryProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func createRuntimeProvider(for chain: ChainModel, chainTypes: Data?, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call(
    """
    createRuntimeProvider(for: ChainModel, chainTypes: Data?, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """,
            parameters: (chain, chainTypes, usedRuntimePaths),
            escapingParameters: (chain, chainTypes, usedRuntimePaths),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createRuntimeProvider(for: chain, chainTypes: chainTypes, usedRuntimePaths: usedRuntimePaths))
        
    }
    
    
    
    
    
     func createHotRuntimeProvider(for chain: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call(
    """
    createHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """,
            parameters: (chain, runtimeItem, commonTypes, chainTypes, usedRuntimePaths),
            escapingParameters: (chain, runtimeItem, commonTypes, chainTypes, usedRuntimePaths),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createHotRuntimeProvider(for: chain, runtimeItem: runtimeItem, commonTypes: commonTypes, chainTypes: chainTypes, usedRuntimePaths: usedRuntimePaths))
        
    }
    
    

     struct __StubbingProxy_RuntimeProviderFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func createRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for chain: M1, chainTypes: M2, usedRuntimePaths: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel, Data?, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data, M3.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?, [String: [String]])>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: chainTypes) { $0.1 }, wrap(matchable: usedRuntimePaths) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderFactoryProtocol.self, method:
    """
    createRuntimeProvider(for: ChainModel, chainTypes: Data?, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func createHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(for chain: M1, runtimeItem: M2, commonTypes: M3, chainTypes: M4, usedRuntimePaths: M5) -> Cuckoo.ProtocolStubFunction<(ChainModel, RuntimeMetadataItem, Data, Data, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == Data, M5.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, Data, [String: [String]])>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: runtimeItem) { $0.1 }, wrap(matchable: commonTypes) { $0.2 }, wrap(matchable: chainTypes) { $0.3 }, wrap(matchable: usedRuntimePaths) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderFactoryProtocol.self, method:
    """
    createHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_RuntimeProviderFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func createRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for chain: M1, chainTypes: M2, usedRuntimePaths: M3) -> Cuckoo.__DoNotUse<(ChainModel, Data?, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data, M3.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?, [String: [String]])>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: chainTypes) { $0.1 }, wrap(matchable: usedRuntimePaths) { $0.2 }]
            return cuckoo_manager.verify(
    """
    createRuntimeProvider(for: ChainModel, chainTypes: Data?, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func createHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(for chain: M1, runtimeItem: M2, commonTypes: M3, chainTypes: M4, usedRuntimePaths: M5) -> Cuckoo.__DoNotUse<(ChainModel, RuntimeMetadataItem, Data, Data, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == Data, M5.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, Data, [String: [String]])>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: runtimeItem) { $0.1 }, wrap(matchable: commonTypes) { $0.2 }, wrap(matchable: chainTypes) { $0.3 }, wrap(matchable: usedRuntimePaths) { $0.4 }]
            return cuckoo_manager.verify(
    """
    createHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class RuntimeProviderFactoryProtocolStub: RuntimeProviderFactoryProtocol {
    

    

    
    
    
    
     func createRuntimeProvider(for chain: ChainModel, chainTypes: Data?, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    
    
    
    
     func createHotRuntimeProvider(for chain: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data, usedRuntimePaths: [String: [String]]) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






 class MockRuntimeProviderPoolProtocol: RuntimeProviderPoolProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderPoolProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderPoolProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderPoolProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderPoolProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderPoolProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func setupRuntimeProvider(for chain: ChainModel, chainTypes: Data?) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call(
    """
    setupRuntimeProvider(for: ChainModel, chainTypes: Data?) -> RuntimeProviderProtocol
    """,
            parameters: (chain, chainTypes),
            escapingParameters: (chain, chainTypes),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupRuntimeProvider(for: chain, chainTypes: chainTypes))
        
    }
    
    
    
    
    
     func setupHotRuntimeProvider(for chain: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call(
    """
    setupHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data) -> RuntimeProviderProtocol
    """,
            parameters: (chain, runtimeItem, commonTypes, chainTypes),
            escapingParameters: (chain, runtimeItem, commonTypes, chainTypes),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupHotRuntimeProvider(for: chain, runtimeItem: runtimeItem, commonTypes: commonTypes, chainTypes: chainTypes))
        
    }
    
    
    
    
    
     func destroyRuntimeProvider(for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call(
    """
    destroyRuntimeProvider(for: ChainModel.Id)
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.destroyRuntimeProvider(for: chainId))
        
    }
    
    
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        
    return cuckoo_manager.call(
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: chainId))
        
    }
    
    

     struct __StubbingProxy_RuntimeProviderPoolProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func setupRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, chainTypes: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel, Data?), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: chainTypes) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method:
    """
    setupRuntimeProvider(for: ChainModel, chainTypes: Data?) -> RuntimeProviderProtocol
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func setupHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for chain: M1, runtimeItem: M2, commonTypes: M3, chainTypes: M4) -> Cuckoo.ProtocolStubFunction<(ChainModel, RuntimeMetadataItem, Data, Data), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, Data)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: runtimeItem) { $0.1 }, wrap(matchable: commonTypes) { $0.2 }, wrap(matchable: chainTypes) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method:
    """
    setupHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data) -> RuntimeProviderProtocol
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func destroyRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method:
    """
    destroyRuntimeProvider(for: ChainModel.Id)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method:
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_RuntimeProviderPoolProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func setupRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, chainTypes: M2) -> Cuckoo.__DoNotUse<(ChainModel, Data?), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: chainTypes) { $0.1 }]
            return cuckoo_manager.verify(
    """
    setupRuntimeProvider(for: ChainModel, chainTypes: Data?) -> RuntimeProviderProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func setupHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for chain: M1, runtimeItem: M2, commonTypes: M3, chainTypes: M4) -> Cuckoo.__DoNotUse<(ChainModel, RuntimeMetadataItem, Data, Data), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, Data)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: runtimeItem) { $0.1 }, wrap(matchable: commonTypes) { $0.2 }, wrap(matchable: chainTypes) { $0.3 }]
            return cuckoo_manager.verify(
    """
    setupHotRuntimeProvider(for: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data) -> RuntimeProviderProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func destroyRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    destroyRuntimeProvider(for: ChainModel.Id)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class RuntimeProviderPoolProtocolStub: RuntimeProviderPoolProtocol {
    

    

    
    
    
    
     func setupRuntimeProvider(for chain: ChainModel, chainTypes: Data?) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    
    
    
    
     func setupHotRuntimeProvider(for chain: ChainModel, runtimeItem: RuntimeMetadataItem, commonTypes: Data, chainTypes: Data) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    
    
    
    
     func destroyRuntimeProvider(for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation
import RobinHood






 class MockRuntimeSyncServiceProtocol: RuntimeSyncServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeSyncServiceProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeSyncServiceProtocol
     typealias Verification = __VerificationProxy_RuntimeSyncServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeSyncServiceProtocol?

     func enableDefaultImplementation(_ stub: RuntimeSyncServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func register(chain: ChainModel, with connection: ChainConnection)  {
        
    return cuckoo_manager.call(
    """
    register(chain: ChainModel, with: ChainConnection)
    """,
            parameters: (chain, connection),
            escapingParameters: (chain, connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.register(chain: chain, with: connection))
        
    }
    
    
    
    
    
     func unregister(chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call(
    """
    unregister(chainId: ChainModel.Id)
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unregister(chainId: chainId))
        
    }
    
    
    
    
    
     func apply(version: RuntimeVersion, for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call(
    """
    apply(version: RuntimeVersion, for: ChainModel.Id)
    """,
            parameters: (version, chainId),
            escapingParameters: (version, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.apply(version: version, for: chainId))
        
    }
    
    
    
    
    
     func hasChain(with chainId: ChainModel.Id) -> Bool {
        
    return cuckoo_manager.call(
    """
    hasChain(with: ChainModel.Id) -> Bool
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.hasChain(with: chainId))
        
    }
    
    
    
    
    
     func isChainSyncing(_ chainId: ChainModel.Id) -> Bool {
        
    return cuckoo_manager.call(
    """
    isChainSyncing(_: ChainModel.Id) -> Bool
    """,
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.isChainSyncing(chainId))
        
    }
    
    

     struct __StubbingProxy_RuntimeSyncServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain: M1, with connection: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel, ChainConnection)> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method:
    """
    register(chain: ChainModel, with: ChainConnection)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func unregister<M1: Cuckoo.Matchable>(chainId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method:
    """
    unregister(chainId: ChainModel.Id)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version: M1, for chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeVersion, ChainModel.Id)> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: version) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method:
    """
    apply(version: RuntimeVersion, for: ChainModel.Id)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func hasChain<M1: Cuckoo.Matchable>(with chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method:
    """
    hasChain(with: ChainModel.Id) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func isChainSyncing<M1: Cuckoo.Matchable>(_ chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method:
    """
    isChainSyncing(_: ChainModel.Id) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_RuntimeSyncServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain: M1, with connection: M2) -> Cuckoo.__DoNotUse<(ChainModel, ChainConnection), Void> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
            return cuckoo_manager.verify(
    """
    register(chain: ChainModel, with: ChainConnection)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func unregister<M1: Cuckoo.Matchable>(chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    unregister(chainId: ChainModel.Id)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version: M1, for chainId: M2) -> Cuckoo.__DoNotUse<(RuntimeVersion, ChainModel.Id), Void> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: version) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
            return cuckoo_manager.verify(
    """
    apply(version: RuntimeVersion, for: ChainModel.Id)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func hasChain<M1: Cuckoo.Matchable>(with chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    hasChain(with: ChainModel.Id) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func isChainSyncing<M1: Cuckoo.Matchable>(_ chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
            return cuckoo_manager.verify(
    """
    isChainSyncing(_: ChainModel.Id) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class RuntimeSyncServiceProtocolStub: RuntimeSyncServiceProtocol {
    

    

    
    
    
    
     func register(chain: ChainModel, with connection: ChainConnection)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func unregister(chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func apply(version: RuntimeVersion, for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func hasChain(with chainId: ChainModel.Id) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    
    
     func isChainSyncing(_ chainId: ChainModel.Id) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation






 class MockSpecVersionSubscriptionProtocol: SpecVersionSubscriptionProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SpecVersionSubscriptionProtocol
    
     typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionProtocol
     typealias Verification = __VerificationProxy_SpecVersionSubscriptionProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SpecVersionSubscriptionProtocol?

     func enableDefaultImplementation(_ stub: SpecVersionSubscriptionProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func subscribe()  {
        
    return cuckoo_manager.call(
    """
    subscribe()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe())
        
    }
    
    
    
    
    
     func unsubscribe()  {
        
    return cuckoo_manager.call(
    """
    unsubscribe()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unsubscribe())
        
    }
    
    

     struct __StubbingProxy_SpecVersionSubscriptionProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func subscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self, method:
    """
    subscribe()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func unsubscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self, method:
    """
    unsubscribe()
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_SpecVersionSubscriptionProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func subscribe() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    subscribe()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func unsubscribe() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    unsubscribe()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class SpecVersionSubscriptionProtocolStub: SpecVersionSubscriptionProtocol {
    

    

    
    
    
    
     func subscribe()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func unsubscribe()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation






 class MockSpecVersionSubscriptionFactoryProtocol: SpecVersionSubscriptionFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SpecVersionSubscriptionFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionFactoryProtocol
     typealias Verification = __VerificationProxy_SpecVersionSubscriptionFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SpecVersionSubscriptionFactoryProtocol?

     func enableDefaultImplementation(_ stub: SpecVersionSubscriptionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func createSubscription(for chainId: ChainModel.Id, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol {
        
    return cuckoo_manager.call(
    """
    createSubscription(for: ChainModel.Id, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol
    """,
            parameters: (chainId, connection),
            escapingParameters: (chainId, connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createSubscription(for: chainId, connection: connection))
        
    }
    
    

     struct __StubbingProxy_SpecVersionSubscriptionFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, connection: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == JSONRPCEngine {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, JSONRPCEngine)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: connection) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionFactoryProtocol.self, method:
    """
    createSubscription(for: ChainModel.Id, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_SpecVersionSubscriptionFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, connection: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == JSONRPCEngine {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, JSONRPCEngine)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: connection) { $0.1 }]
            return cuckoo_manager.verify(
    """
    createSubscription(for: ChainModel.Id, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class SpecVersionSubscriptionFactoryProtocolStub: SpecVersionSubscriptionFactoryProtocol {
    

    

    
    
    
    
     func createSubscription(for chainId: ChainModel.Id, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol  {
        return DefaultValueRegistry.defaultValue(for: (SpecVersionSubscriptionProtocol).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






 class MockCrowdloanRemoteSubscriptionServiceProtocol: CrowdloanRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = CrowdloanRemoteSubscriptionServiceProtocol
    
     typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol
     typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CrowdloanRemoteSubscriptionServiceProtocol?

     func enableDefaultImplementation(_ stub: CrowdloanRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call(
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """,
            parameters: (chainId, queue, closure),
            escapingParameters: (chainId, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.attach(for: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    
    
    
    
     func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call(
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """,
            parameters: (subscriptionId, chainId, queue, closure),
            escapingParameters: (subscriptionId, chainId, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    

     struct __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self, method:
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self, method:
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_CrowdloanRemoteSubscriptionServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
            return cuckoo_manager.verify(
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class CrowdloanRemoteSubscriptionServiceProtocolStub: CrowdloanRemoteSubscriptionServiceProtocol {
    

    

    
    
    
    
     func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
    
    
     func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockCrowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionService, Cuckoo.ClassMock {
    
     typealias MocksType = CrowdloanRemoteSubscriptionService
    
     typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionService
     typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: CrowdloanRemoteSubscriptionService?

     func enableDefaultImplementation(_ stub: CrowdloanRemoteSubscriptionService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     override func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call(
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """,
            parameters: (chainId, queue, closure),
            escapingParameters: (chainId, queue, closure),
            superclassCall:
                
                super.attach(for: chainId, runningCompletionIn: queue, completion: closure)
                ,
            defaultCall: __defaultImplStub!.attach(for: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    
    
    
    
     override func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call(
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """,
            parameters: (subscriptionId, chainId, queue, closure),
            escapingParameters: (subscriptionId, chainId, queue, closure),
            superclassCall:
                
                super.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure)
                ,
            defaultCall: __defaultImplStub!.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    

     struct __StubbingProxy_CrowdloanRemoteSubscriptionService: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.ClassStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self, method:
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.ClassStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self, method:
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_CrowdloanRemoteSubscriptionService: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
            return cuckoo_manager.verify(
    """
    attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class CrowdloanRemoteSubscriptionServiceStub: CrowdloanRemoteSubscriptionService {
    

    

    
    
    
    
     override func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
    
    
     override func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood






 class MockStakingAccountUpdatingServiceProtocol: StakingAccountUpdatingServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingAccountUpdatingServiceProtocol
    
     typealias Stubbing = __StubbingProxy_StakingAccountUpdatingServiceProtocol
     typealias Verification = __VerificationProxy_StakingAccountUpdatingServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingAccountUpdatingServiceProtocol?

     func enableDefaultImplementation(_ stub: StakingAccountUpdatingServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func setupSubscription(for accountId: AccountId, chainAsset: ChainAsset, chainFormat: ChainFormat, stakingType: StakingType) throws {
        
    return try cuckoo_manager.callThrows(
    """
    setupSubscription(for: AccountId, chainAsset: ChainAsset, chainFormat: ChainFormat, stakingType: StakingType) throws
    """,
            parameters: (accountId, chainAsset, chainFormat, stakingType),
            escapingParameters: (accountId, chainAsset, chainFormat, stakingType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupSubscription(for: accountId, chainAsset: chainAsset, chainFormat: chainFormat, stakingType: stakingType))
        
    }
    
    
    
    
    
     func clearSubscription()  {
        
    return cuckoo_manager.call(
    """
    clearSubscription()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.clearSubscription())
        
    }
    
    

     struct __StubbingProxy_StakingAccountUpdatingServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for accountId: M1, chainAsset: M2, chainFormat: M3, stakingType: M4) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(AccountId, ChainAsset, ChainFormat, StakingType)> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.MatchedType == ChainFormat, M4.MatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, ChainFormat, StakingType)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }, wrap(matchable: stakingType) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self, method:
    """
    setupSubscription(for: AccountId, chainAsset: ChainAsset, chainFormat: ChainFormat, stakingType: StakingType) throws
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func clearSubscription() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self, method:
    """
    clearSubscription()
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_StakingAccountUpdatingServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for accountId: M1, chainAsset: M2, chainFormat: M3, stakingType: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, ChainFormat, StakingType), Void> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.MatchedType == ChainFormat, M4.MatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, ChainFormat, StakingType)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }, wrap(matchable: stakingType) { $0.3 }]
            return cuckoo_manager.verify(
    """
    setupSubscription(for: AccountId, chainAsset: ChainAsset, chainFormat: ChainFormat, stakingType: StakingType) throws
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func clearSubscription() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    clearSubscription()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class StakingAccountUpdatingServiceProtocolStub: StakingAccountUpdatingServiceProtocol {
    

    

    
    
    
    
     func setupSubscription(for accountId: AccountId, chainAsset: ChainAsset, chainFormat: ChainFormat, stakingType: StakingType) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func clearSubscription()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import FearlessUtils
import Foundation






 class MockStakingRemoteSubscriptionServiceProtocol: StakingRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingRemoteSubscriptionServiceProtocol
    
     typealias Stubbing = __StubbingProxy_StakingRemoteSubscriptionServiceProtocol
     typealias Verification = __VerificationProxy_StakingRemoteSubscriptionServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingRemoteSubscriptionServiceProtocol?

     func enableDefaultImplementation(_ stub: StakingRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func attachToGlobalData(for chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?) -> UUID? {
        
    return cuckoo_manager.call(
    """
    attachToGlobalData(for: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?) -> UUID?
    """,
            parameters: (chainId, queue, closure, stakingType),
            escapingParameters: (chainId, queue, closure, stakingType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.attachToGlobalData(for: chainId, queue: queue, closure: closure, stakingType: stakingType))
        
    }
    
    
    
    
    
     func detachFromGlobalData(for subscriptionId: UUID, chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?)  {
        
    return cuckoo_manager.call(
    """
    detachFromGlobalData(for: UUID, chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?)
    """,
            parameters: (subscriptionId, chainId, queue, closure, stakingType),
            escapingParameters: (subscriptionId, chainId, queue, closure, stakingType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.detachFromGlobalData(for: subscriptionId, chainId: chainId, queue: queue, closure: closure, stakingType: stakingType))
        
    }
    
    

     struct __StubbingProxy_StakingRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func attachToGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for chainId: M1, queue: M2, closure: M3, stakingType: M4) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure, M4.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }, wrap(matchable: stakingType) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingRemoteSubscriptionServiceProtocol.self, method:
    """
    attachToGlobalData(for: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?) -> UUID?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func detachFromGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, queue: M3, closure: M4, stakingType: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure, M5.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }, wrap(matchable: stakingType) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingRemoteSubscriptionServiceProtocol.self, method:
    """
    detachFromGlobalData(for: UUID, chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_StakingRemoteSubscriptionServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func attachToGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for chainId: M1, queue: M2, closure: M3, stakingType: M4) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure, M4.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }, wrap(matchable: stakingType) { $0.3 }]
            return cuckoo_manager.verify(
    """
    attachToGlobalData(for: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?) -> UUID?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func detachFromGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, queue: M3, closure: M4, stakingType: M5) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure, M5.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }, wrap(matchable: stakingType) { $0.4 }]
            return cuckoo_manager.verify(
    """
    detachFromGlobalData(for: UUID, chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class StakingRemoteSubscriptionServiceProtocolStub: StakingRemoteSubscriptionServiceProtocol {
    

    

    
    
    
    
     func attachToGlobalData(for chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
    
    
     func detachFromGlobalData(for subscriptionId: UUID, chainId: ChainModel.Id, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?, stakingType: StakingType?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation






 class MockWalletRemoteSubscriptionServiceProtocol: WalletRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = WalletRemoteSubscriptionServiceProtocol
    
     typealias Stubbing = __StubbingProxy_WalletRemoteSubscriptionServiceProtocol
     typealias Verification = __VerificationProxy_WalletRemoteSubscriptionServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: WalletRemoteSubscriptionServiceProtocol?

     func enableDefaultImplementation(_ stub: WalletRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func attachToAccountInfo(of accountId: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call(
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """,
            parameters: (accountId, chainAsset, queue, closure),
            escapingParameters: (accountId, chainAsset, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.attachToAccountInfo(of: accountId, chainAsset: chainAsset, queue: queue, closure: closure))
        
    }
    
    
    
    
    
     func detachFromAccountInfo(for subscriptionId: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call(
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """,
            parameters: (subscriptionId, chainAssetKey, queue, closure),
            escapingParameters: (subscriptionId, chainAssetKey, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.detachFromAccountInfo(for: subscriptionId, chainAssetKey: chainAssetKey, queue: queue, closure: closure))
        
    }
    
    

     struct __StubbingProxy_WalletRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of accountId: M1, chainAsset: M2, queue: M3, closure: M4) -> Cuckoo.ProtocolStubFunction<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionServiceProtocol.self, method:
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainAssetKey: M2, queue: M3, closure: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainAssetKey) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionServiceProtocol.self, method:
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_WalletRemoteSubscriptionServiceProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of accountId: M1, chainAsset: M2, queue: M3, closure: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainAssetKey: M2, queue: M3, closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainAssetKey) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class WalletRemoteSubscriptionServiceProtocolStub: WalletRemoteSubscriptionServiceProtocol {
    

    

    
    
    
    
     func attachToAccountInfo(of accountId: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
    
    
     func detachFromAccountInfo(for subscriptionId: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}










 class MockWalletRemoteSubscriptionService: WalletRemoteSubscriptionService, Cuckoo.ClassMock {
    
     typealias MocksType = WalletRemoteSubscriptionService
    
     typealias Stubbing = __StubbingProxy_WalletRemoteSubscriptionService
     typealias Verification = __VerificationProxy_WalletRemoteSubscriptionService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: WalletRemoteSubscriptionService?

     func enableDefaultImplementation(_ stub: WalletRemoteSubscriptionService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     override func attachToAccountInfo(of accountId: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call(
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """,
            parameters: (accountId, chainAsset, queue, closure),
            escapingParameters: (accountId, chainAsset, queue, closure),
            superclassCall:
                
                super.attachToAccountInfo(of: accountId, chainAsset: chainAsset, queue: queue, closure: closure)
                ,
            defaultCall: __defaultImplStub!.attachToAccountInfo(of: accountId, chainAsset: chainAsset, queue: queue, closure: closure))
        
    }
    
    
    
    
    
     override func detachFromAccountInfo(for subscriptionId: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call(
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """,
            parameters: (subscriptionId, chainAssetKey, queue, closure),
            escapingParameters: (subscriptionId, chainAssetKey, queue, closure),
            superclassCall:
                
                super.detachFromAccountInfo(for: subscriptionId, chainAssetKey: chainAssetKey, queue: queue, closure: closure)
                ,
            defaultCall: __defaultImplStub!.detachFromAccountInfo(for: subscriptionId, chainAssetKey: chainAssetKey, queue: queue, closure: closure))
        
    }
    
    

     struct __StubbingProxy_WalletRemoteSubscriptionService: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of accountId: M1, chainAsset: M2, queue: M3, closure: M4) -> Cuckoo.ClassStubFunction<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionService.self, method:
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainAssetKey: M2, queue: M3, closure: M4) -> Cuckoo.ClassStubNoReturnFunction<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainAssetKey) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionService.self, method:
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_WalletRemoteSubscriptionService: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of accountId: M1, chainAsset: M2, queue: M3, closure: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainAsset) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    attachToAccountInfo(of: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainAssetKey: M2, queue: M3, closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainAssetKey) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
            return cuckoo_manager.verify(
    """
    detachFromAccountInfo(for: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class WalletRemoteSubscriptionServiceStub: WalletRemoteSubscriptionService {
    

    

    
    
    
    
     override func attachToAccountInfo(of accountId: AccountId, chainAsset: ChainAsset, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
    
    
     override func detachFromAccountInfo(for subscriptionId: UUID, chainAssetKey: ChainAssetKey, queue: DispatchQueue?, closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}





import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import RobinHood






 class MockStakingServiceFactoryProtocol: StakingServiceFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingServiceFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_StakingServiceFactoryProtocol
     typealias Verification = __VerificationProxy_StakingServiceFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingServiceFactoryProtocol?

     func enableDefaultImplementation(_ stub: StakingServiceFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    
     func createEraValidatorService(for chain: ChainModel) throws -> EraValidatorServiceProtocol {
        
    return try cuckoo_manager.callThrows(
    """
    createEraValidatorService(for: ChainModel) throws -> EraValidatorServiceProtocol
    """,
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createEraValidatorService(for: chain))
        
    }
    
    
    
    
    
     func createRewardCalculatorService(for chainAsset: ChainAsset, assetPrecision: Int16, validatorService: EraValidatorServiceProtocol, collatorOperationFactory: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol {
        
    return try cuckoo_manager.callThrows(
    """
    createRewardCalculatorService(for: ChainAsset, assetPrecision: Int16, validatorService: EraValidatorServiceProtocol, collatorOperationFactory: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol
    """,
            parameters: (chainAsset, assetPrecision, validatorService, collatorOperationFactory),
            escapingParameters: (chainAsset, assetPrecision, validatorService, collatorOperationFactory),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createRewardCalculatorService(for: chainAsset, assetPrecision: assetPrecision, validatorService: validatorService, collatorOperationFactory: collatorOperationFactory))
        
    }
    
    

     struct __StubbingProxy_StakingServiceFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func createEraValidatorService<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel), EraValidatorServiceProtocol> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self, method:
    """
    createEraValidatorService(for: ChainModel) throws -> EraValidatorServiceProtocol
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(for chainAsset: M1, assetPrecision: M2, validatorService: M3, collatorOperationFactory: M4) -> Cuckoo.ProtocolStubThrowingFunction<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?), RewardCalculatorServiceProtocol> where M1.MatchedType == ChainAsset, M2.MatchedType == Int16, M3.MatchedType == EraValidatorServiceProtocol, M4.OptionalMatchedType == ParachainCollatorOperationFactory {
            let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?)>] = [wrap(matchable: chainAsset) { $0.0 }, wrap(matchable: assetPrecision) { $0.1 }, wrap(matchable: validatorService) { $0.2 }, wrap(matchable: collatorOperationFactory) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self, method:
    """
    createRewardCalculatorService(for: ChainAsset, assetPrecision: Int16, validatorService: EraValidatorServiceProtocol, collatorOperationFactory: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol
    """, parameterMatchers: matchers))
        }
        
        
    }

     struct __VerificationProxy_StakingServiceFactoryProtocol: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation
    
         init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }
    
        
    
        
        
        
        @discardableResult
        func createEraValidatorService<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), EraValidatorServiceProtocol> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
            return cuckoo_manager.verify(
    """
    createEraValidatorService(for: ChainModel) throws -> EraValidatorServiceProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(for chainAsset: M1, assetPrecision: M2, validatorService: M3, collatorOperationFactory: M4) -> Cuckoo.__DoNotUse<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?), RewardCalculatorServiceProtocol> where M1.MatchedType == ChainAsset, M2.MatchedType == Int16, M3.MatchedType == EraValidatorServiceProtocol, M4.OptionalMatchedType == ParachainCollatorOperationFactory {
            let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?)>] = [wrap(matchable: chainAsset) { $0.0 }, wrap(matchable: assetPrecision) { $0.1 }, wrap(matchable: validatorService) { $0.2 }, wrap(matchable: collatorOperationFactory) { $0.3 }]
            return cuckoo_manager.verify(
    """
    createRewardCalculatorService(for: ChainAsset, assetPrecision: Int16, validatorService: EraValidatorServiceProtocol, collatorOperationFactory: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class StakingServiceFactoryProtocolStub: StakingServiceFactoryProtocol {
    

    

    
    
    
    
     func createEraValidatorService(for chain: ChainModel) throws -> EraValidatorServiceProtocol  {
        return DefaultValueRegistry.defaultValue(for: (EraValidatorServiceProtocol).self)
    }
    
    
    
    
    
     func createRewardCalculatorService(for chainAsset: ChainAsset, assetPrecision: Int16, validatorService: EraValidatorServiceProtocol, collatorOperationFactory: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RewardCalculatorServiceProtocol).self)
    }
    
    
}




