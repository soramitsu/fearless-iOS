import Cuckoo
import Foundation
import SSFUtils

/// Manual Cuckoo mock that covers the generic `JSONRPCEngine` protocol.
/// Cuckoo struggles to autogenerate this because of the generic method constraints,
/// so we keep the implementation in a dedicated hand-written file.
class MockJSONRPCEngine: JSONRPCEngine, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = JSONRPCEngine
    typealias Stubbing = __StubbingProxy_JSONRPCEngine
    typealias Verification = __VerificationProxy_JSONRPCEngine

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any JSONRPCEngine)?

    func enableDefaultImplementation(_ stub: any JSONRPCEngine) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }

    var url: URL? {
        get {
            return cuckoo_manager.getter(
                "url",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.url
            )
        }
        set {
            cuckoo_manager.setter(
                "url",
                value: newValue,
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.url = newValue
            )
        }
    }

    var pendingEngineRequests: [JSONRPCRequest] {
        get {
            return cuckoo_manager.getter(
                "pendingEngineRequests",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.pendingEngineRequests
            )
        }
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        return try cuckoo_manager.callThrows(
            "callMethod(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16",
            parameters: (method, params, options, closure),
            escapingParameters: (method, params, options, closure),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.callMethod(method,
                                                       params: params,
                                                       options: options,
                                                       completion: closure)
        )
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        return try cuckoo_manager.callThrows(
            "subscribe(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16",
            parameters: (method, params, updateClosure, failureClosure),
            escapingParameters: (method, params, updateClosure, failureClosure),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: try __defaultImplStub!.subscribe(method,
                                                          params: params,
                                                          updateClosure: updateClosure,
                                                          failureClosure: failureClosure)
        )
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        return cuckoo_manager.call(
            "cancelForIdentifier(_ identifier: UInt16)",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.cancelForIdentifier(identifier)
        )
    }

    func generateRequestId() -> UInt16 {
        return cuckoo_manager.call(
            "generateRequestId() -> UInt16",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.generateRequestId()
        )
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        return cuckoo_manager.call(
            "addSubscription(_ subscription: JSONRPCSubscribing)",
            parameters: (subscription),
            escapingParameters: (subscription),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.addSubscription(subscription)
        )
    }

    func reconnect(url: URL) {
        return cuckoo_manager.call(
            "reconnect(url: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.reconnect(url: url)
        )
    }

    func connectIfNeeded() {
        return cuckoo_manager.call(
            "connectIfNeeded()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.connectIfNeeded()
        )
    }

    func disconnectIfNeeded() {
        return cuckoo_manager.call(
            "disconnectIfNeeded()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.disconnectIfNeeded()
        )
    }

    struct __StubbingProxy_JSONRPCEngine: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        var url: Cuckoo.ProtocolToBeStubbedProperty<MockJSONRPCEngine, URL?> {
            return .init(manager: cuckoo_manager, name: "url")
        }

        var pendingEngineRequests: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCEngine, [JSONRPCRequest]> {
            return .init(manager: cuckoo_manager, name: "pendingEngineRequests")
        }

        func callMethod<P, T, M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(
            _ method: M1,
            params: M2,
            options: M3,
            completion closure: M4
        ) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16,Swift.Error>
        where
            M1.MatchedType == String,
            M2.OptionalMatchedType == P,
            M3.MatchedType == JSONRPCOptions,
            M4.OptionalMatchedType == (Result<T, Error>) -> Void
        {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [
                wrap(matchable: method) { $0.0 },
                wrap(matchable: params) { $0.1 },
                wrap(matchable: options) { $0.2 },
                wrap(matchable: closure) { $0.3 }
            ]
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "callMethod(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16",
                parameterMatchers: matchers
            ))
        }

        func subscribe<P, T, M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(
            _ method: M1,
            params: M2,
            updateClosure: M3,
            failureClosure: M4
        ) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16,Swift.Error>
        where
            M1.MatchedType == String,
            M2.OptionalMatchedType == P,
            M3.MatchedType == (T) -> Void,
            M4.MatchedType == (Error, Bool) -> Void
        {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [
                wrap(matchable: method) { $0.0 },
                wrap(matchable: params) { $0.1 },
                wrap(matchable: updateClosure) { $0.2 },
                wrap(matchable: failureClosure) { $0.3 }
            ]
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "subscribe(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16",
                parameterMatchers: matchers
            ))
        }

        func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UInt16)> where M1.MatchedType == UInt16 {
            let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "cancelForIdentifier(_ identifier: UInt16)",
                parameterMatchers: matchers
            ))
        }

        func generateRequestId() -> Cuckoo.ProtocolStubFunction<(), UInt16> {
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "generateRequestId() -> UInt16",
                parameterMatchers: []
            ))
        }

        func addSubscription<M1: Cuckoo.Matchable>(_ subscription: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(JSONRPCSubscribing)> where M1.MatchedType == JSONRPCSubscribing {
            let matchers: [Cuckoo.ParameterMatcher<(JSONRPCSubscribing)>] = [wrap(matchable: subscription) { $0 }]
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "addSubscription(_ subscription: JSONRPCSubscribing)",
                parameterMatchers: matchers
            ))
        }

        func reconnect<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "reconnect(url: URL)",
                parameterMatchers: matchers
            ))
        }

        func connectIfNeeded() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "connectIfNeeded()",
                parameterMatchers: []
            ))
        }

        func disconnectIfNeeded() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            return .init(stub: cuckoo_manager.createStub(
                for: MockJSONRPCEngine.self,
                method: "disconnectIfNeeded()",
                parameterMatchers: []
            ))
        }
    }

    struct __VerificationProxy_JSONRPCEngine: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        var url: Cuckoo.VerifyProperty<URL?> {
            return .init(manager: cuckoo_manager, name: "url", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }

        var pendingEngineRequests: Cuckoo.VerifyProperty<[JSONRPCRequest]> {
            return .init(manager: cuckoo_manager, name: "pendingEngineRequests", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }

        @discardableResult
        func callMethod<P, T, M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(
            _ method: M1,
            params: M2,
            options: M3,
            completion closure: M4
        ) -> Cuckoo.__DoNotUse<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16>
        where
            M1.MatchedType == String,
            M2.OptionalMatchedType == P,
            M3.MatchedType == JSONRPCOptions,
            M4.OptionalMatchedType == (Result<T, Error>) -> Void
        {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [
                wrap(matchable: method) { $0.0 },
                wrap(matchable: params) { $0.1 },
                wrap(matchable: options) { $0.2 },
                wrap(matchable: closure) { $0.3 }
            ]
            return cuckoo_manager.verify(
                "callMethod(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func subscribe<P, T, M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(
            _ method: M1,
            params: M2,
            updateClosure: M3,
            failureClosure: M4
        ) -> Cuckoo.__DoNotUse<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16>
        where
            M1.MatchedType == String,
            M2.OptionalMatchedType == P,
            M3.MatchedType == (T) -> Void,
            M4.MatchedType == (Error, Bool) -> Void
        {
            let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [
                wrap(matchable: method) { $0.0 },
                wrap(matchable: params) { $0.1 },
                wrap(matchable: updateClosure) { $0.2 },
                wrap(matchable: failureClosure) { $0.3 }
            ]
            return cuckoo_manager.verify(
                "subscribe(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.__DoNotUse<(UInt16), Void> where M1.MatchedType == UInt16 {
            let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
            return cuckoo_manager.verify(
                "cancelForIdentifier(_ identifier: UInt16)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func generateRequestId() -> Cuckoo.__DoNotUse<(), UInt16> {
            return cuckoo_manager.verify(
                "generateRequestId() -> UInt16",
                callMatcher: callMatcher,
                parameterMatchers: [],
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func addSubscription<M1: Cuckoo.Matchable>(_ subscription: M1) -> Cuckoo.__DoNotUse<(JSONRPCSubscribing), Void> where M1.MatchedType == JSONRPCSubscribing {
            let matchers: [Cuckoo.ParameterMatcher<(JSONRPCSubscribing)>] = [wrap(matchable: subscription) { $0 }]
            return cuckoo_manager.verify(
                "addSubscription(_ subscription: JSONRPCSubscribing)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func reconnect<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return cuckoo_manager.verify(
                "reconnect(url: URL)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func connectIfNeeded() -> Cuckoo.__DoNotUse<(), Void> {
            return cuckoo_manager.verify(
                "connectIfNeeded()",
                callMatcher: callMatcher,
                parameterMatchers: [],
                sourceLocation: sourceLocation
            )
        }

        @discardableResult
        func disconnectIfNeeded() -> Cuckoo.__DoNotUse<(), Void> {
            return cuckoo_manager.verify(
                "disconnectIfNeeded()",
                callMatcher: callMatcher,
                parameterMatchers: [],
                sourceLocation: sourceLocation
            )
        }
    }
}

class JSONRPCEngineStub: JSONRPCEngine, @unchecked Sendable {
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { return DefaultValueRegistry.defaultValue(for: ([JSONRPCRequest]).self) }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }

    func generateRequestId() -> UInt16 {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }

    func reconnect(url: URL) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }

    func connectIfNeeded() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }

    func disconnectIfNeeded() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}
