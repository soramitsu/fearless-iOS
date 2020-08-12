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
import LocalAuthentication


public class MockBiometryAuthProtocol: BiometryAuthProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = BiometryAuthProtocol
    
    public typealias Stubbing = __StubbingProxy_BiometryAuthProtocol
    public typealias Verification = __VerificationProxy_BiometryAuthProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: BiometryAuthProtocol?

    public func enableDefaultImplementation(_ stub: BiometryAuthProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    

    

    
    
    
    public func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	public struct __StubbingProxy_BiometryAuthProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
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

	public struct __VerificationProxy_BiometryAuthProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
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

public class BiometryAuthProtocolStub: BiometryAuthProtocol {
    
    
    public var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    public func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockBiometryAuth: BiometryAuth, Cuckoo.ClassMock {
    
    public typealias MocksType = BiometryAuth
    
    public typealias Stubbing = __StubbingProxy_BiometryAuth
    public typealias Verification = __VerificationProxy_BiometryAuth

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: BiometryAuth?

    public func enableDefaultImplementation(_ stub: BiometryAuth) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public override var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    super.availableBiometryType
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    

    

    
    
    
    public override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                super.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock)
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	public struct __StubbingProxy_BiometryAuth: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
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

	public struct __VerificationProxy_BiometryAuth: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
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

public class BiometryAuthStub: BiometryAuth {
    
    
    public override var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    public override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless
@testable import SoraKeystore

import Foundation
import Starscream
