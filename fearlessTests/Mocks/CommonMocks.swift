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
        
    return try cuckoo_manager.callThrows("addKey(_: Data, with: String) throws",
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addKey(key, with: identifier))
        
    }
    
    
    
    public func updateKey(_ key: Data, with identifier: String) throws {
        
    return try cuckoo_manager.callThrows("updateKey(_: Data, with: String) throws",
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateKey(key, with: identifier))
        
    }
    
    
    
    public func fetchKey(for identifier: String) throws -> Data {
        
    return try cuckoo_manager.callThrows("fetchKey(for: String) throws -> Data",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchKey(for: identifier))
        
    }
    
    
    
    public func checkKey(for identifier: String) throws -> Bool {
        
    return try cuckoo_manager.callThrows("checkKey(for: String) throws -> Bool",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkKey(for: identifier))
        
    }
    
    
    
    public func deleteKey(for identifier: String) throws {
        
    return try cuckoo_manager.callThrows("deleteKey(for: String) throws",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "addKey(_: Data, with: String) throws", parameterMatchers: matchers))
	    }
	    
	    func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String)> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "updateKey(_: Data, with: String) throws", parameterMatchers: matchers))
	    }
	    
	    func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Data> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "fetchKey(for: String) throws -> Data", parameterMatchers: matchers))
	    }
	    
	    func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "checkKey(for: String) throws -> Bool", parameterMatchers: matchers))
	    }
	    
	    func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "deleteKey(for: String) throws", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("addKey(_: Data, with: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return cuckoo_manager.verify("updateKey(_: Data, with: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Data> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("fetchKey(for: String) throws -> Data", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("checkKey(for: String) throws -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("deleteKey(for: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("asSecretData() -> Data?",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretDataRepresentable.self, method: "asSecretData() -> Data?", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("asSecretData() -> Data?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.loadSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (secret, identifier, completionQueue, completionBlock),
            escapingParameters: (secret, identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveSecret(secret, for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func checkSecret(for identifier: String) -> Bool {
        
    return cuckoo_manager.call("checkSecret(for: String) -> Bool",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubFunction<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "checkSecret(for: String) -> Bool", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.__DoNotUse<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
	        return cuckoo_manager.verify("saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("checkSecret(for: String) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("accept(visitor: EventVisitorProtocol)",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self, method: "accept(visitor: EventVisitorProtocol)", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("accept(visitor: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("notify(with: EventProtocol)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notify(with: event))
        
    }
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)  {
        
    return cuckoo_manager.call("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)",
            parameters: (observer, queue),
            escapingParameters: (observer, queue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer, dispatchIn: queue))
        
    }
    
    
    
     func remove(observer: EventVisitorProtocol)  {
        
    return cuckoo_manager.call("remove(observer: EventVisitorProtocol)",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "notify(with: EventProtocol)", parameterMatchers: matchers))
	    }
	    
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "remove(observer: EventVisitorProtocol)", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("notify(with: EventProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return cuckoo_manager.verify("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return cuckoo_manager.verify("remove(observer: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
    

    
    
    
     var operationManager: OperationManagerProtocol {
        get {
            return cuckoo_manager.getter("operationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.operationManager)
        }
        
    }
    

    

    
    
    
     func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<AccountItem> {
        
    return cuckoo_manager.call("createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<AccountItem>",
            parameters: (networkType),
            escapingParameters: (networkType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createAccountRepository(for: networkType))
        
    }
    
    
    
     func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem> {
        
    return cuckoo_manager.call("createStreambleProvider(for: AccountAddress) -> StreamableProvider<AccountItem>",
            parameters: (accountAddress),
            escapingParameters: (accountAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createStreambleProvider(for: accountAddress))
        
    }
    

	 struct __StubbingProxy_AccountRepositoryFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var operationManager: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountRepositoryFactoryProtocol, OperationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "operationManager")
	    }
	    
	    
	    func createAccountRepository<M1: Cuckoo.Matchable>(for networkType: M1) -> Cuckoo.ProtocolStubFunction<(SNAddressType), AnyDataProviderRepository<AccountItem>> where M1.MatchedType == SNAddressType {
	        let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: networkType) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<AccountItem>", parameterMatchers: matchers))
	    }
	    
	    func createStreambleProvider<M1: Cuckoo.Matchable>(for accountAddress: M1) -> Cuckoo.ProtocolStubFunction<(AccountAddress), StreamableProvider<AccountItem>> where M1.MatchedType == AccountAddress {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountAddress)>] = [wrap(matchable: accountAddress) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createStreambleProvider(for: AccountAddress) -> StreamableProvider<AccountItem>", parameterMatchers: matchers))
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
	
	    
	    
	    var operationManager: Cuckoo.VerifyReadOnlyProperty<OperationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "operationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func createAccountRepository<M1: Cuckoo.Matchable>(for networkType: M1) -> Cuckoo.__DoNotUse<(SNAddressType), AnyDataProviderRepository<AccountItem>> where M1.MatchedType == SNAddressType {
	        let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: networkType) { $0 }]
	        return cuckoo_manager.verify("createAccountRepository(for: SNAddressType) -> AnyDataProviderRepository<AccountItem>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createStreambleProvider<M1: Cuckoo.Matchable>(for accountAddress: M1) -> Cuckoo.__DoNotUse<(AccountAddress), StreamableProvider<AccountItem>> where M1.MatchedType == AccountAddress {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountAddress)>] = [wrap(matchable: accountAddress) { $0 }]
	        return cuckoo_manager.verify("createStreambleProvider(for: AccountAddress) -> StreamableProvider<AccountItem>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountRepositoryFactoryProtocolStub: AccountRepositoryFactoryProtocol {
    
    
     var operationManager: OperationManagerProtocol {
        get {
            return DefaultValueRegistry.defaultValue(for: (OperationManagerProtocol).self)
        }
        
    }
    

    

    
     func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<AccountItem>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<AccountItem>).self)
    }
    
     func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem>  {
        return DefaultValueRegistry.defaultValue(for: (StreamableProvider<AccountItem>).self)
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
        
    return cuckoo_manager.call("notifyAfter(_: TimeInterval)",
            parameters: (seconds),
            escapingParameters: (seconds),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notifyAfter(seconds))
        
    }
    
    
    
     func cancel()  {
        
    return cuckoo_manager.call("cancel()",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method: "notifyAfter(_: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	    func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method: "cancel()", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("notifyAfter(_: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancel() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("cancel()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("didTrigger(scheduler: SchedulerProtocol)",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerDelegate.self, method: "didTrigger(scheduler: SchedulerProtocol)", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("didTrigger(scheduler: SchedulerProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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


 class MockJSONRPCResponseHandling: JSONRPCResponseHandling, Cuckoo.ProtocolMock {
    
     typealias MocksType = JSONRPCResponseHandling
    
     typealias Stubbing = __StubbingProxy_JSONRPCResponseHandling
     typealias Verification = __VerificationProxy_JSONRPCResponseHandling

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCResponseHandling?

     func enableDefaultImplementation(_ stub: JSONRPCResponseHandling) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func handle(data: Data)  {
        
    return cuckoo_manager.call("handle(data: Data)",
            parameters: (data),
            escapingParameters: (data),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data))
        
    }
    
    
    
     func handle(error: Error)  {
        
    return cuckoo_manager.call("handle(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error))
        
    }
    

	 struct __StubbingProxy_JSONRPCResponseHandling: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Data)> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method: "handle(data: Data)", parameterMatchers: matchers))
	    }
	    
	    func handle<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method: "handle(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_JSONRPCResponseHandling: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.__DoNotUse<(Data), Void> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
	        return cuckoo_manager.verify("handle(data: Data)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("handle(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class JSONRPCResponseHandlingStub: JSONRPCResponseHandling {
    

    

    
     func handle(data: Data)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func handle(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockJSONRPCSubscribing: JSONRPCSubscribing, Cuckoo.ProtocolMock {
    
     typealias MocksType = JSONRPCSubscribing
    
     typealias Stubbing = __StubbingProxy_JSONRPCSubscribing
     typealias Verification = __VerificationProxy_JSONRPCSubscribing

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCSubscribing?

     func enableDefaultImplementation(_ stub: JSONRPCSubscribing) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var requestId: UInt16 {
        get {
            return cuckoo_manager.getter("requestId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestId)
        }
        
    }
    
    
    
     var requestData: Data {
        get {
            return cuckoo_manager.getter("requestData",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestData)
        }
        
    }
    
    
    
     var requestOptions: JSONRPCOptions {
        get {
            return cuckoo_manager.getter("requestOptions",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestOptions)
        }
        
    }
    
    
    
     var remoteId: String? {
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
    

    

    
    
    
     func handle(data: Data) throws {
        
    return try cuckoo_manager.callThrows("handle(data: Data) throws",
            parameters: (data),
            escapingParameters: (data),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data))
        
    }
    
    
    
     func handle(error: Error, unsubscribed: Bool)  {
        
    return cuckoo_manager.call("handle(error: Error, unsubscribed: Bool)",
            parameters: (error, unsubscribed),
            escapingParameters: (error, unsubscribed),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error, unsubscribed: unsubscribed))
        
    }
    

	 struct __StubbingProxy_JSONRPCSubscribing: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
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
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method: "handle(data: Data) throws", parameterMatchers: matchers))
	    }
	    
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, Bool)> where M1.MatchedType == Error, M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method: "handle(error: Error, unsubscribed: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_JSONRPCSubscribing: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
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
	        return cuckoo_manager.verify("handle(data: Data) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.__DoNotUse<(Error, Bool), Void> where M1.MatchedType == Error, M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
	        return cuckoo_manager.verify("handle(error: Error, unsubscribed: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class JSONRPCSubscribingStub: JSONRPCSubscribing {
    
    
     var requestId: UInt16 {
        get {
            return DefaultValueRegistry.defaultValue(for: (UInt16).self)
        }
        
    }
    
    
     var requestData: Data {
        get {
            return DefaultValueRegistry.defaultValue(for: (Data).self)
        }
        
    }
    
    
     var requestOptions: JSONRPCOptions {
        get {
            return DefaultValueRegistry.defaultValue(for: (JSONRPCOptions).self)
        }
        
    }
    
    
     var remoteId: String? {
        get {
            return DefaultValueRegistry.defaultValue(for: (String?).self)
        }
        
        set { }
        
    }
    

    

    
     func handle(data: Data) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func handle(error: Error, unsubscribed: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockJSONRPCEngine: JSONRPCEngine, Cuckoo.ProtocolMock {
    
     typealias MocksType = JSONRPCEngine
    
     typealias Stubbing = __StubbingProxy_JSONRPCEngine
     typealias Verification = __VerificationProxy_JSONRPCEngine

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCEngine?

     func enableDefaultImplementation(_ stub: JSONRPCEngine) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows("callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16",
            parameters: (method, params, options, closure),
            escapingParameters: (method, params, options, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.callMethod(method, params: params, options: options, completion: closure))
        
    }
    
    
    
     func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows("subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16",
            parameters: (method, params, updateClosure, failureClosure),
            escapingParameters: (method, params, updateClosure, failureClosure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe(method, params: params, updateClosure: updateClosure, failureClosure: failureClosure))
        
    }
    
    
    
     func cancelForIdentifier(_ identifier: UInt16)  {
        
    return cuckoo_manager.call("cancelForIdentifier(_: UInt16)",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancelForIdentifier(identifier))
        
    }
    

	 struct __StubbingProxy_JSONRPCEngine: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16", parameterMatchers: matchers))
	    }
	    
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, updateClosure: M3, failureClosure: M4) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == (T) -> Void, M4.MatchedType == (Error, Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }, wrap(matchable: failureClosure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16", parameterMatchers: matchers))
	    }
	    
	    func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UInt16)> where M1.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "cancelForIdentifier(_: UInt16)", parameterMatchers: matchers))
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
	
	    
	
	    
	    @discardableResult
	    func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return cuckoo_manager.verify("callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, updateClosure: M3, failureClosure: M4) -> Cuckoo.__DoNotUse<(String, P?, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == (T) -> Void, M4.MatchedType == (Error, Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: updateClosure) { $0.2 }, wrap(matchable: failureClosure) { $0.3 }]
	        return cuckoo_manager.verify("subscribe(_: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancelForIdentifier<M1: Cuckoo.Matchable>(_ identifier: M1) -> Cuckoo.__DoNotUse<(UInt16), Void> where M1.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt16)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("cancelForIdentifier(_: UInt16)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class JSONRPCEngineStub: JSONRPCEngine {
    

    

    
     func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
     func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
     func cancelForIdentifier(_ identifier: UInt16)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless
@testable import SoraKeystore

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
        
    return cuckoo_manager.call("fetchChainOperation(_: URL) -> BaseOperation<String>",
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
	        return .init(stub: cuckoo_manager.createStub(for: MockSubstrateOperationFactoryProtocol.self, method: "fetchChainOperation(_: URL) -> BaseOperation<String>", parameterMatchers: matchers))
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
	        return cuckoo_manager.verify("fetchChainOperation(_: URL) -> BaseOperation<String>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SubstrateOperationFactoryProtocolStub: SubstrateOperationFactoryProtocol {
    

    

    
     func fetchChainOperation(_ url: URL) -> BaseOperation<String>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<String>).self)
    }
    
}

