// Cuckoo compatibility header (adjusted for CI)
@testable import fearless
// Ensure SSF model types (ChainModel, ChainAsset, StakingType, etc.) are visible in mocks
import SSFModels

// Local typealiases to disambiguate SSF models referenced by generated mocks
// These keep the generated signatures intact without depending on another helper file.
typealias ChainModel = SSFModels.ChainModel
typealias AssetModel = SSFModels.AssetModel
typealias ChainAsset = SSFModels.ChainAsset
typealias ChainFormat = fearless.ChainFormat
typealias AccountId = fearless.AccountId
typealias StakingType = SSFModels.StakingType
typealias ChainAssetKey = SSFModels.ChainAssetKey
// MARK: - Mocks generated from file: 'Pods/SoraKeystore/SoraKeystore/Classes/Keychain/KeystoreProtocols.swift'

import Cuckoo
import Foundation
@testable import SoraKeystore

public class MockKeystoreProtocol: KeystoreProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = KeystoreProtocol
    public typealias Stubbing = __StubbingProxy_KeystoreProtocol
    public typealias Verification = __VerificationProxy_KeystoreProtocol

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any KeystoreProtocol)?

    public func enableDefaultImplementation(_ stub: any KeystoreProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    public func addKey(_ p0: Data, with p1: String) throws {
        return try cuckoo_manager.callThrows(
            "addKey(_ p0: Data, with p1: String) throws",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.addKey(p0, with: p1)
        )
    }

    public func updateKey(_ p0: Data, with p1: String) throws {
        return try cuckoo_manager.callThrows(
            "updateKey(_ p0: Data, with p1: String) throws",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.updateKey(p0, with: p1)
        )
    }

    public func fetchKey(for p0: String) throws -> Data {
        return try cuckoo_manager.callThrows(
            "fetchKey(for p0: String) throws -> Data",
            parameters: (p0),
            escapingParameters: (p0),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchKey(for: p0)
        )
    }

    public func checkKey(for p0: String) throws -> Bool {
        return try cuckoo_manager.callThrows(
            "checkKey(for p0: String) throws -> Bool",
            parameters: (p0),
            escapingParameters: (p0),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.checkKey(for: p0)
        )
    }

    public func deleteKey(for p0: String) throws {
        return try cuckoo_manager.callThrows(
            "deleteKey(for p0: String) throws",
            parameters: (p0),
            escapingParameters: (p0),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.deleteKey(for: p0)
        )
    }

    public struct __StubbingProxy_KeystoreProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String),Swift.Error> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self,
                method: "addKey(_ p0: Data, with p1: String) throws",
                parameterMatchers: matchers
            ))
        }
        
        func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String),Swift.Error> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self,
                method: "updateKey(_ p0: Data, with p1: String) throws",
                parameterMatchers: matchers
            ))
        }
        
        func fetchKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Data,Swift.Error> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self,
                method: "fetchKey(for p0: String) throws -> Data",
                parameterMatchers: matchers
            ))
        }
        
        func checkKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Bool,Swift.Error> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self,
                method: "checkKey(for p0: String) throws -> Bool",
                parameterMatchers: matchers
            ))
        }
        
        func deleteKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(String),Swift.Error> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self,
                method: "deleteKey(for p0: String) throws",
                parameterMatchers: matchers
            ))
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
        func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "addKey(_ p0: Data, with p1: String) throws",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "updateKey(_ p0: Data, with p1: String) throws",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func fetchKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(String), Data> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "fetchKey(for p0: String) throws -> Data",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func checkKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "checkKey(for p0: String) throws -> Bool",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func deleteKey<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "deleteKey(for p0: String) throws",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

public class KeystoreProtocolStub:KeystoreProtocol, @unchecked Sendable {


    
    public func addKey(_ p0: Data, with p1: String) throws {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func updateKey(_ p0: Data, with p1: String) throws {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func fetchKey(for p0: String) throws -> Data {
        return DefaultValueRegistry.defaultValue(for: (Data).self)
    }
    
    public func checkKey(for p0: String) throws -> Bool {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    public func deleteKey(for p0: String) throws {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


public class MockSecretDataRepresentable: SecretDataRepresentable, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = SecretDataRepresentable
    public typealias Stubbing = __StubbingProxy_SecretDataRepresentable
    public typealias Verification = __VerificationProxy_SecretDataRepresentable

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SecretDataRepresentable)?

    public func enableDefaultImplementation(_ stub: any SecretDataRepresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    public func asSecretData() -> Data? {
        return cuckoo_manager.call(
            "asSecretData() -> Data?",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.asSecretData()
        )
    }

    public struct __StubbingProxy_SecretDataRepresentable: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func asSecretData() -> Cuckoo.ProtocolStubFunction<(), Data?> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSecretDataRepresentable.self,
                method: "asSecretData() -> Data?",
                parameterMatchers: matchers
            ))
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
                "asSecretData() -> Data?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

public class SecretDataRepresentableStub:SecretDataRepresentable, @unchecked Sendable {


    
    public func asSecretData() -> Data? {
        return DefaultValueRegistry.defaultValue(for: (Data?).self)
    }
}


public class MockSecretStoreManagerProtocol: SecretStoreManagerProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = SecretStoreManagerProtocol
    public typealias Stubbing = __StubbingProxy_SecretStoreManagerProtocol
    public typealias Verification = __VerificationProxy_SecretStoreManagerProtocol

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SecretStoreManagerProtocol)?

    public func enableDefaultImplementation(_ stub: any SecretStoreManagerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    public func loadSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (SecretDataRepresentable?) -> Void) {
        return cuckoo_manager.call(
            "loadSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (SecretDataRepresentable?) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.loadSecret(for: p0, completionQueue: p1, completionBlock: p2)
        )
    }

    public func saveSecret(_ p0: SecretDataRepresentable, for p1: String, completionQueue p2: DispatchQueue, completionBlock p3: @escaping (Bool) -> Void) {
        return cuckoo_manager.call(
            "saveSecret(_ p0: SecretDataRepresentable, for p1: String, completionQueue p2: DispatchQueue, completionBlock p3: @escaping (Bool) -> Void)",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.saveSecret(p0, for: p1, completionQueue: p2, completionBlock: p3)
        )
    }

    public func removeSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return cuckoo_manager.call(
            "removeSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.removeSecret(for: p0, completionQueue: p1, completionBlock: p2)
        )
    }

    public func checkSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return cuckoo_manager.call(
            "checkSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.checkSecret(for: p0, completionQueue: p1, completionBlock: p2)
        )
    }

    public func checkSecret(for p0: String) -> Bool {
        return cuckoo_manager.call(
            "checkSecret(for p0: String) -> Bool",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.checkSecret(for: p0)
        )
    }

    public struct __StubbingProxy_SecretStoreManagerProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue,  (SecretDataRepresentable?) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (SecretDataRepresentable?) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self,
                method: "loadSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (SecretDataRepresentable?) -> Void)",
                parameterMatchers: matchers
            ))
        }
        
        func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ p0: M1, for p1: M2, completionQueue p2: M3, completionBlock p3: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(SecretDataRepresentable, String, DispatchQueue,  (Bool) -> Void)> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self,
                method: "saveSecret(_ p0: SecretDataRepresentable, for p1: String, completionQueue p2: DispatchQueue, completionBlock p3: @escaping (Bool) -> Void)",
                parameterMatchers: matchers
            ))
        }
        
        func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue,  (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self,
                method: "removeSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                parameterMatchers: matchers
            ))
        }
        
        func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue,  (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self,
                method: "checkSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                parameterMatchers: matchers
            ))
        }
        
        func checkSecret<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self,
                method: "checkSecret(for p0: String) -> Bool",
                parameterMatchers: matchers
            ))
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
        func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue,  (SecretDataRepresentable?) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (SecretDataRepresentable?) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "loadSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (SecretDataRepresentable?) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ p0: M1, for p1: M2, completionQueue p2: M3, completionBlock p3: M4) -> Cuckoo.__DoNotUse<(SecretDataRepresentable, String, DispatchQueue,  (Bool) -> Void), Void> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "saveSecret(_ p0: SecretDataRepresentable, for p1: String, completionQueue p2: DispatchQueue, completionBlock p3: @escaping (Bool) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue,  (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "removeSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue,  (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "checkSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func checkSecret<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "checkSecret(for p0: String) -> Bool",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

public class SecretStoreManagerProtocolStub:SecretStoreManagerProtocol, @unchecked Sendable {


    
    public func loadSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (SecretDataRepresentable?) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func saveSecret(_ p0: SecretDataRepresentable, for p1: String, completionQueue p2: DispatchQueue, completionBlock p3: @escaping (Bool) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func removeSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func checkSecret(for p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func checkSecret(for p0: String) -> Bool {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/EventCenter/EventProtocols.swift'

import Cuckoo
import Foundation
@testable import fearless
@testable import SoraKeystore

class MockEventProtocol: EventProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = EventProtocol
    typealias Stubbing = __StubbingProxy_EventProtocol
    typealias Verification = __VerificationProxy_EventProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any EventProtocol)?

    func enableDefaultImplementation(_ stub: any EventProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func accept(visitor p0: EventVisitorProtocol) {
        return cuckoo_manager.call(
            "accept(visitor p0: EventVisitorProtocol)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.accept(visitor: p0)
        )
    }

    struct __StubbingProxy_EventProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func accept<M1: Cuckoo.Matchable>(visitor p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self,
                method: "accept(visitor p0: EventVisitorProtocol)",
                parameterMatchers: matchers
            ))
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
        func accept<M1: Cuckoo.Matchable>(visitor p0: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "accept(visitor p0: EventVisitorProtocol)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class EventProtocolStub:EventProtocol, @unchecked Sendable {


    
    func accept(visitor p0: EventVisitorProtocol) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockEventCenterProtocol: EventCenterProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = EventCenterProtocol
    typealias Stubbing = __StubbingProxy_EventCenterProtocol
    typealias Verification = __VerificationProxy_EventCenterProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any EventCenterProtocol)?

    func enableDefaultImplementation(_ stub: any EventCenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func notify(with p0: EventProtocol) {
        return cuckoo_manager.call(
            "notify(with p0: EventProtocol)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.notify(with: p0)
        )
    }

    func add(observer p0: EventVisitorProtocol, dispatchIn p1: DispatchQueue?) {
        return cuckoo_manager.call(
            "add(observer p0: EventVisitorProtocol, dispatchIn p1: DispatchQueue?)",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.add(observer: p0, dispatchIn: p1)
        )
    }

    func remove(observer p0: EventVisitorProtocol) {
        return cuckoo_manager.call(
            "remove(observer p0: EventVisitorProtocol)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.remove(observer: p0)
        )
    }

    struct __StubbingProxy_EventCenterProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func notify<M1: Cuckoo.Matchable>(with p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventProtocol)> where M1.MatchedType == EventProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self,
                method: "notify(with p0: EventProtocol)",
                parameterMatchers: matchers
            ))
        }
        
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer p0: M1, dispatchIn p1: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self,
                method: "add(observer p0: EventVisitorProtocol, dispatchIn p1: DispatchQueue?)",
                parameterMatchers: matchers
            ))
        }
        
        func remove<M1: Cuckoo.Matchable>(observer p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self,
                method: "remove(observer p0: EventVisitorProtocol)",
                parameterMatchers: matchers
            ))
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
        func notify<M1: Cuckoo.Matchable>(with p0: M1) -> Cuckoo.__DoNotUse<(EventProtocol), Void> where M1.MatchedType == EventProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "notify(with p0: EventProtocol)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer p0: M1, dispatchIn p1: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "add(observer p0: EventVisitorProtocol, dispatchIn p1: DispatchQueue?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func remove<M1: Cuckoo.Matchable>(observer p0: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "remove(observer p0: EventVisitorProtocol)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class EventCenterProtocolStub:EventCenterProtocol, @unchecked Sendable {


    
    func notify(with p0: EventProtocol) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func add(observer p0: EventVisitorProtocol, dispatchIn p1: DispatchQueue?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func remove(observer p0: EventVisitorProtocol) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Helpers/AccountRepositoryFactory.swift'

import Cuckoo
import Foundation
import IrohaCrypto
import RobinHood
@testable import fearless
@testable import SoraKeystore

class MockAccountRepositoryFactoryProtocol: AccountRepositoryFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = AccountRepositoryFactoryProtocol
    typealias Stubbing = __StubbingProxy_AccountRepositoryFactoryProtocol
    typealias Verification = __VerificationProxy_AccountRepositoryFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any AccountRepositoryFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any AccountRepositoryFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
    func createRepository() -> AnyDataProviderRepository<MetaAccountModel> {
        return cuckoo_manager.call(
            "createRepository() -> AnyDataProviderRepository<MetaAccountModel>",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createRepository()
        )
    }

    func createAccountRepository(for p0: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel> {
        return cuckoo_manager.call(
            "createAccountRepository(for p0: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createAccountRepository(for: p0)
        )
    }

    func createMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel> {
        return cuckoo_manager.call(
            "createMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createMetaAccountRepository(for: p0, sortDescriptors: p1)
        )
    }

    func createManagedMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        return cuckoo_manager.call(
            "createManagedMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createManagedMetaAccountRepository(for: p0, sortDescriptors: p1)
        )
    }

    func createAsyncMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AsyncAnyRepository<MetaAccountModel> {
        return cuckoo_manager.call(
            "createAsyncMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AsyncAnyRepository<MetaAccountModel>",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createAsyncMetaAccountRepository(for: p0, sortDescriptors: p1)
        )
    }

    struct __StubbingProxy_AccountRepositoryFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
        func createRepository() -> Cuckoo.ProtocolStubFunction<(), AnyDataProviderRepository<MetaAccountModel>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self,
                method: "createRepository() -> AnyDataProviderRepository<MetaAccountModel>",
                parameterMatchers: matchers
            ))
        }
        
        func createAccountRepository<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(SNAddressType), AnyDataProviderRepository<MetaAccountModel>> where M1.MatchedType == SNAddressType {
            let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self,
                method: "createAccountRepository(for p0: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>",
                parameterMatchers: matchers
            ))
        }
        
        func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self,
                method: "createMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>",
                parameterMatchers: matchers
            ))
        }
        
        func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self,
                method: "createManagedMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>",
                parameterMatchers: matchers
            ))
        }
        
        func createAsyncMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AsyncAnyRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self,
                method: "createAsyncMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AsyncAnyRepository<MetaAccountModel>",
                parameterMatchers: matchers
            ))
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
                "createRepository() -> AnyDataProviderRepository<MetaAccountModel>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createAccountRepository<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(SNAddressType), AnyDataProviderRepository<MetaAccountModel>> where M1.MatchedType == SNAddressType {
            let matchers: [Cuckoo.ParameterMatcher<(SNAddressType)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "createAccountRepository(for p0: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "createMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "createManagedMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createAsyncMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for p0: M1, sortDescriptors p1: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AsyncAnyRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
            let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "createAsyncMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AsyncAnyRepository<MetaAccountModel>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class AccountRepositoryFactoryProtocolStub:AccountRepositoryFactoryProtocol, @unchecked Sendable {


    
    @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
    func createRepository() -> AnyDataProviderRepository<MetaAccountModel> {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    func createAccountRepository(for p0: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel> {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    func createMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel> {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    func createManagedMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<ManagedMetaAccountModel>).self)
    }
    
    func createAsyncMetaAccountRepository(for p0: NSPredicate?, sortDescriptors p1: [NSSortDescriptor]) -> AsyncAnyRepository<MetaAccountModel> {
        return DefaultValueRegistry.defaultValue(for: (AsyncAnyRepository<MetaAccountModel>).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Helpers/Scheduler.swift'

import Cuckoo
import Foundation
@testable import fearless
@testable import SoraKeystore

class MockSchedulerProtocol: SchedulerProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = SchedulerProtocol
    typealias Stubbing = __StubbingProxy_SchedulerProtocol
    typealias Verification = __VerificationProxy_SchedulerProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SchedulerProtocol)?

    func enableDefaultImplementation(_ stub: any SchedulerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func notifyAfter(_ p0: TimeInterval) {
        return cuckoo_manager.call(
            "notifyAfter(_ p0: TimeInterval)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.notifyAfter(p0)
        )
    }

    func cancel() {
        return cuckoo_manager.call(
            "cancel()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.cancel()
        )
    }

    struct __StubbingProxy_SchedulerProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func notifyAfter<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self,
                method: "notifyAfter(_ p0: TimeInterval)",
                parameterMatchers: matchers
            ))
        }
        
        func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self,
                method: "cancel()",
                parameterMatchers: matchers
            ))
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
        func notifyAfter<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
            let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "notifyAfter(_ p0: TimeInterval)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func cancel() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "cancel()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class SchedulerProtocolStub:SchedulerProtocol, @unchecked Sendable {


    
    func notifyAfter(_ p0: TimeInterval) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func cancel() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockSchedulerDelegate: SchedulerDelegate, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = SchedulerDelegate
    typealias Stubbing = __StubbingProxy_SchedulerDelegate
    typealias Verification = __VerificationProxy_SchedulerDelegate

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SchedulerDelegate)?

    func enableDefaultImplementation(_ stub: any SchedulerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func didTrigger(scheduler p0: SchedulerProtocol) {
        return cuckoo_manager.call(
            "didTrigger(scheduler p0: SchedulerProtocol)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.didTrigger(scheduler: p0)
        )
    }

    struct __StubbingProxy_SchedulerDelegate: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func didTrigger<M1: Cuckoo.Matchable>(scheduler p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SchedulerProtocol)> where M1.MatchedType == SchedulerProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSchedulerDelegate.self,
                method: "didTrigger(scheduler p0: SchedulerProtocol)",
                parameterMatchers: matchers
            ))
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
        func didTrigger<M1: Cuckoo.Matchable>(scheduler p0: M1) -> Cuckoo.__DoNotUse<(SchedulerProtocol), Void> where M1.MatchedType == SchedulerProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "didTrigger(scheduler p0: SchedulerProtocol)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class SchedulerDelegateStub:SchedulerDelegate, @unchecked Sendable {


    
    func didTrigger(scheduler p0: SchedulerProtocol) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/LocalAuthentication/BiometryAuth.swift'

import Cuckoo
import Foundation
import LocalAuthentication
import UIKit.UIImage
@testable import fearless
@testable import SoraKeystore

class MockBiometryAuthProtocol: BiometryAuthProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = BiometryAuthProtocol
    typealias Stubbing = __StubbingProxy_BiometryAuthProtocol
    typealias Verification = __VerificationProxy_BiometryAuthProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any BiometryAuthProtocol)?

    func enableDefaultImplementation(_ stub: any BiometryAuthProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }

    var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter(
                "availableBiometryType",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.availableBiometryType
            )
        }
    }


    func authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return cuckoo_manager.call(
            "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.authenticate(localizedReason: p0, completionQueue: p1, completionBlock: p2)
        )
    }

    struct __StubbingProxy_BiometryAuthProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        var availableBiometryType: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockBiometryAuthProtocol,AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType")
        }
        
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue,  (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self,
                method: "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                parameterMatchers: matchers
            ))
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
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue,  (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class BiometryAuthProtocolStub:BiometryAuthProtocol, @unchecked Sendable {
    
    var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
    }


    
    func authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockBiometryAuth: BiometryAuth, Cuckoo.ClassMock, @unchecked Sendable {
    typealias MocksType = BiometryAuth
    typealias Stubbing = __StubbingProxy_BiometryAuth
    typealias Verification = __VerificationProxy_BiometryAuth

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    private var __defaultImplStub: BiometryAuth?

    func enableDefaultImplementation(_ stub: BiometryAuth) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }

    override var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter(
                "availableBiometryType",
                superclassCall: super.availableBiometryType,
                defaultCall: __defaultImplStub!.availableBiometryType
            )
        }
    }


    override func authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return cuckoo_manager.call(
            "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: super.authenticate(localizedReason: p0, completionQueue: p1, completionBlock: p2),
            defaultCall: __defaultImplStub!.authenticate(localizedReason: p0, completionQueue: p1, completionBlock: p2)
        )
    }

    struct __StubbingProxy_BiometryAuth: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        var availableBiometryType: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockBiometryAuth,AvailableBiometryType> {
            return .init(manager: cuckoo_manager, name: "availableBiometryType")
        }
        
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.ClassStubNoReturnFunction<(String, DispatchQueue,  (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self,
                method: "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                parameterMatchers: matchers
            ))
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
        func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason p0: M1, completionQueue p1: M2, completionBlock p2: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue,  (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType ==  (Bool) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue,  (Bool) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class BiometryAuthStub:BiometryAuth, @unchecked Sendable {
    
    override var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
    }


    
    override func authenticate(localizedReason p0: String, completionQueue p1: DispatchQueue, completionBlock p2: @escaping (Bool) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Network/Misc/DataOperationFactory.swift'

import Cuckoo
import Foundation
import RobinHood
@testable import fearless
@testable import SoraKeystore

class MockDataOperationFactoryProtocol: DataOperationFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = DataOperationFactoryProtocol
    typealias Stubbing = __StubbingProxy_DataOperationFactoryProtocol
    typealias Verification = __VerificationProxy_DataOperationFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any DataOperationFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any DataOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func fetchData(from p0: URL) -> BaseOperation<Data> {
        return cuckoo_manager.call(
            "fetchData(from p0: URL) -> BaseOperation<Data>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchData(from: p0)
        )
    }

    struct __StubbingProxy_DataOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func fetchData<M1: Cuckoo.Matchable>(from p0: M1) -> Cuckoo.ProtocolStubFunction<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockDataOperationFactoryProtocol.self,
                method: "fetchData(from p0: URL) -> BaseOperation<Data>",
                parameterMatchers: matchers
            ))
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
        func fetchData<M1: Cuckoo.Matchable>(from p0: M1) -> Cuckoo.__DoNotUse<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "fetchData(from p0: URL) -> BaseOperation<Data>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class DataOperationFactoryProtocolStub:DataOperationFactoryProtocol, @unchecked Sendable {


    
    func fetchData(from p0: URL) -> BaseOperation<Data> {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Network/Misc/SubstrateOperationFactory.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockSubstrateOperationFactoryProtocol: SubstrateOperationFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = SubstrateOperationFactoryProtocol
    typealias Stubbing = __StubbingProxy_SubstrateOperationFactoryProtocol
    typealias Verification = __VerificationProxy_SubstrateOperationFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SubstrateOperationFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any SubstrateOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func fetchChainOperation(_ p0: URL) -> BaseOperation<String> {
        return cuckoo_manager.call(
            "fetchChainOperation(_ p0: URL) -> BaseOperation<String>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchChainOperation(p0)
        )
    }

    struct __StubbingProxy_SubstrateOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func fetchChainOperation<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubFunction<(URL), BaseOperation<String>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSubstrateOperationFactoryProtocol.self,
                method: "fetchChainOperation(_ p0: URL) -> BaseOperation<String>",
                parameterMatchers: matchers
            ))
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
        func fetchChainOperation<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<(URL), BaseOperation<String>> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "fetchChainOperation(_ p0: URL) -> BaseOperation<String>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class SubstrateOperationFactoryProtocolStub:SubstrateOperationFactoryProtocol, @unchecked Sendable {


    
    func fetchChainOperation(_ p0: URL) -> BaseOperation<String> {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<String>).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/ChainRegistry.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFUtils
import Web3
import SSFChainRegistry
import SSFRuntimeCodingService
import SSFChainConnection
@testable import fearless
@testable import SoraKeystore

class MockChainRegistryProtocol: ChainRegistryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = ChainRegistryProtocol
    typealias Stubbing = __StubbingProxy_ChainRegistryProtocol
    typealias Verification = __VerificationProxy_ChainRegistryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any ChainRegistryProtocol)?

    func enableDefaultImplementation(_ stub: any ChainRegistryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }

    var availableChainIds: Set<ChainModel.Id>? {
        get {
            return cuckoo_manager.getter(
                "availableChainIds",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.availableChainIds
            )
        }
    }

    var availableChains: [ChainModel] {
        get {
            return cuckoo_manager.getter(
                "availableChains",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.availableChains
            )
        }
    }

    var chainsTypesMap: [String: Data] {
        get {
            return cuckoo_manager.getter(
                "chainsTypesMap",
                superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
                defaultCall: __defaultImplStub!.chainsTypesMap
            )
        }
    }


    func resetConnection(for p0: ChainModel.Id) {
        return cuckoo_manager.call(
            "resetConnection(for p0: ChainModel.Id)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.resetConnection(for: p0)
        )
    }

    func retryConnection(for p0: ChainModel.Id) {
        return cuckoo_manager.call(
            "retryConnection(for p0: ChainModel.Id)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.retryConnection(for: p0)
        )
    }

    func getConnection(for p0: ChainModel.Id) -> ChainConnection? {
        return cuckoo_manager.call(
            "getConnection(for p0: ChainModel.Id) -> ChainConnection?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getConnection(for: p0)
        )
    }

    func getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol? {
        return cuckoo_manager.call(
            "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: p0)
        )
    }

    func getChain(for p0: ChainModel.Id) -> ChainModel? {
        return cuckoo_manager.call(
            "getChain(for p0: ChainModel.Id) -> ChainModel?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getChain(for: p0)
        )
    }

    func chainsSubscribe(_ p0: AnyObject, runningInQueue p1: DispatchQueue, updateClosure p2: @escaping ([DataProviderChange<ChainModel>]) -> Void) {
        return cuckoo_manager.call(
            "chainsSubscribe(_ p0: AnyObject, runningInQueue p1: DispatchQueue, updateClosure p2: @escaping ([DataProviderChange<ChainModel>]) -> Void)",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.chainsSubscribe(p0, runningInQueue: p1, updateClosure: p2)
        )
    }

    func getEthereumConnection(for p0: ChainModel.Id) -> Web3.Eth? {
        return cuckoo_manager.call(
            "getEthereumConnection(for p0: ChainModel.Id) -> Web3.Eth?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getEthereumConnection(for: p0)
        )
    }

    func chainsUnsubscribe(_ p0: AnyObject) {
        return cuckoo_manager.call(
            "chainsUnsubscribe(_ p0: AnyObject)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.chainsUnsubscribe(p0)
        )
    }

    func syncUp() {
        return cuckoo_manager.call(
            "syncUp()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.syncUp()
        )
    }

    func performHotBoot() {
        return cuckoo_manager.call(
            "performHotBoot()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.performHotBoot()
        )
    }

    func performColdBoot() {
        return cuckoo_manager.call(
            "performColdBoot()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.performColdBoot()
        )
    }

    func subscribeToChians() {
        return cuckoo_manager.call(
            "subscribeToChians()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.subscribeToChians()
        )
    }

    struct __StubbingProxy_ChainRegistryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        var availableChainIds: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockChainRegistryProtocol,Set<ChainModel.Id>?> {
            return .init(manager: cuckoo_manager, name: "availableChainIds")
        }
        
        var availableChains: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockChainRegistryProtocol,[ChainModel]> {
            return .init(manager: cuckoo_manager, name: "availableChains")
        }
        
        var chainsTypesMap: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockChainRegistryProtocol,[String: Data]> {
            return .init(manager: cuckoo_manager, name: "chainsTypesMap")
        }
        
        func resetConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "resetConnection(for p0: ChainModel.Id)",
                parameterMatchers: matchers
            ))
        }
        
        func retryConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "retryConnection(for p0: ChainModel.Id)",
                parameterMatchers: matchers
            ))
        }
        
        func getConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "getConnection(for p0: ChainModel.Id) -> ChainConnection?",
                parameterMatchers: matchers
            ))
        }
        
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
                parameterMatchers: matchers
            ))
        }
        
        func getChain<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainModel?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "getChain(for p0: ChainModel.Id) -> ChainModel?",
                parameterMatchers: matchers
            ))
        }
        
        func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ p0: M1, runningInQueue p1: M2, updateClosure p2: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject, DispatchQueue,  ([DataProviderChange<ChainModel>]) -> Void)> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.MatchedType ==  ([DataProviderChange<ChainModel>]) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue,  ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "chainsSubscribe(_ p0: AnyObject, runningInQueue p1: DispatchQueue, updateClosure p2: @escaping ([DataProviderChange<ChainModel>]) -> Void)",
                parameterMatchers: matchers
            ))
        }
        
        func getEthereumConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Web3.Eth?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "getEthereumConnection(for p0: ChainModel.Id) -> Web3.Eth?",
                parameterMatchers: matchers
            ))
        }
        
        func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject)> where M1.MatchedType == AnyObject {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "chainsUnsubscribe(_ p0: AnyObject)",
                parameterMatchers: matchers
            ))
        }
        
        func syncUp() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "syncUp()",
                parameterMatchers: matchers
            ))
        }
        
        func performHotBoot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "performHotBoot()",
                parameterMatchers: matchers
            ))
        }
        
        func performColdBoot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "performColdBoot()",
                parameterMatchers: matchers
            ))
        }
        
        func subscribeToChians() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self,
                method: "subscribeToChians()",
                parameterMatchers: matchers
            ))
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
        
        var availableChains: Cuckoo.VerifyReadOnlyProperty<[ChainModel]> {
            return .init(manager: cuckoo_manager, name: "availableChains", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        var chainsTypesMap: Cuckoo.VerifyReadOnlyProperty<[String: Data]> {
            return .init(manager: cuckoo_manager, name: "chainsTypesMap", callMatcher: callMatcher, sourceLocation: sourceLocation)
        }
        
        
        @discardableResult
        func resetConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "resetConnection(for p0: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func retryConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "retryConnection(for p0: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getConnection(for p0: ChainModel.Id) -> ChainConnection?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getChain<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainModel?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getChain(for p0: ChainModel.Id) -> ChainModel?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ p0: M1, runningInQueue p1: M2, updateClosure p2: M3) -> Cuckoo.__DoNotUse<(AnyObject, DispatchQueue,  ([DataProviderChange<ChainModel>]) -> Void), Void> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.MatchedType ==  ([DataProviderChange<ChainModel>]) -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue,  ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "chainsSubscribe(_ p0: AnyObject, runningInQueue p1: DispatchQueue, updateClosure p2: @escaping ([DataProviderChange<ChainModel>]) -> Void)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getEthereumConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Web3.Eth?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getEthereumConnection(for p0: ChainModel.Id) -> Web3.Eth?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<(AnyObject), Void> where M1.MatchedType == AnyObject {
            let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "chainsUnsubscribe(_ p0: AnyObject)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func syncUp() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "syncUp()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func performHotBoot() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "performHotBoot()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func performColdBoot() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "performColdBoot()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func subscribeToChians() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "subscribeToChians()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class ChainRegistryProtocolStub:ChainRegistryProtocol, @unchecked Sendable {
    
    var availableChainIds: Set<ChainModel.Id>? {
        get {
            return DefaultValueRegistry.defaultValue(for: (Set<ChainModel.Id>?).self)
        }
    }
    
    var availableChains: [ChainModel] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([ChainModel]).self)
        }
    }
    
    var chainsTypesMap: [String: Data] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([String: Data]).self)
        }
    }


    
    func resetConnection(for p0: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func retryConnection(for p0: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func getConnection(for p0: ChainModel.Id) -> ChainConnection? {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    func getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol? {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
    
    func getChain(for p0: ChainModel.Id) -> ChainModel? {
        return DefaultValueRegistry.defaultValue(for: (ChainModel?).self)
    }
    
    func chainsSubscribe(_ p0: AnyObject, runningInQueue p1: DispatchQueue, updateClosure p2: @escaping ([DataProviderChange<ChainModel>]) -> Void) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func getEthereumConnection(for p0: ChainModel.Id) -> Web3.Eth? {
        return DefaultValueRegistry.defaultValue(for: (Web3.Eth?).self)
    }
    
    func chainsUnsubscribe(_ p0: AnyObject) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func syncUp() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func performHotBoot() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func performColdBoot() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func subscribeToChians() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/ConnectionPool/ConnectionFactory.swift'

import Cuckoo
import Foundation
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockConnectionFactoryProtocol: ConnectionFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = ConnectionFactoryProtocol
    typealias Stubbing = __StubbingProxy_ConnectionFactoryProtocol
    typealias Verification = __VerificationProxy_ConnectionFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any ConnectionFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any ConnectionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func createConnection(connectionName p0: String?, for p1: [URL], delegate p2: WebSocketEngineDelegate) throws -> ChainConnection {
        return try cuckoo_manager.callThrows(
            "createConnection(connectionName p0: String?, for p1: [URL], delegate p2: WebSocketEngineDelegate) throws -> ChainConnection",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createConnection(connectionName: p0, for: p1, delegate: p2)
        )
    }

    struct __StubbingProxy_ConnectionFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func createConnection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(connectionName p0: M1, for p1: M2, delegate p2: M3) -> Cuckoo.ProtocolStubThrowingFunction<(String?, [URL], WebSocketEngineDelegate), ChainConnection,Swift.Error> where M1.OptionalMatchedType == String, M2.MatchedType == [URL], M3.MatchedType == WebSocketEngineDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(String?, [URL], WebSocketEngineDelegate)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self,
                method: "createConnection(connectionName p0: String?, for p1: [URL], delegate p2: WebSocketEngineDelegate) throws -> ChainConnection",
                parameterMatchers: matchers
            ))
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
        func createConnection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(connectionName p0: M1, for p1: M2, delegate p2: M3) -> Cuckoo.__DoNotUse<(String?, [URL], WebSocketEngineDelegate), ChainConnection> where M1.OptionalMatchedType == String, M2.MatchedType == [URL], M3.MatchedType == WebSocketEngineDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(String?, [URL], WebSocketEngineDelegate)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "createConnection(connectionName p0: String?, for p1: [URL], delegate p2: WebSocketEngineDelegate) throws -> ChainConnection",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class ConnectionFactoryProtocolStub:ConnectionFactoryProtocol, @unchecked Sendable {


    
    func createConnection(connectionName p0: String?, for p1: [URL], delegate p2: WebSocketEngineDelegate) throws -> ChainConnection {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift'

import Cuckoo
import Foundation
import SSFUtils
import SoraFoundation
@testable import fearless
@testable import SoraKeystore

class MockConnectionPoolProtocol<T>: ConnectionPoolProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = DefaultImplCaller
    typealias Stubbing = __StubbingProxy_ConnectionPoolProtocol
    typealias Verification = __VerificationProxy_ConnectionPoolProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    class DefaultImplCaller: ConnectionPoolProtocol, @unchecked Sendable {
        private let reference: Any
    
        
        init<_CUCKOO$$GENERIC: ConnectionPoolProtocol>(from defaultImpl: UnsafeMutablePointer<_CUCKOO$$GENERIC>, keeping reference: @escaping @autoclosure () -> Any?) where _CUCKOO$$GENERIC.T == T {
            self.reference = reference
    
            _storage$1$setupConnection = defaultImpl.pointee.setupConnection
            _storage$2$getConnection = defaultImpl.pointee.getConnection
            _storage$3$setDelegate = defaultImpl.pointee.setDelegate
            _storage$4$resetConnection = defaultImpl.pointee.resetConnection
        }
    

        private let _storage$1$setupConnection: (ChainModel) throws -> T
        func setupConnection(for p0: ChainModel) throws -> T {
            return try _storage$1$setupConnection(p0)
        }

        private let _storage$2$getConnection: (ChainModel.Id) -> T?
        func getConnection(for p0: ChainModel.Id) -> T? {
            return _storage$2$getConnection(p0)
        }

        private let _storage$3$setDelegate: (ConnectionPoolDelegate) -> Void
        func setDelegate(_ p0: ConnectionPoolDelegate) {
            return _storage$3$setDelegate(p0)
        }

        private let _storage$4$resetConnection: (ChainModel.Id) -> Void
        func resetConnection(for p0: ChainModel.Id) {
            return _storage$4$resetConnection(p0)
        }
    }

    private var __defaultImplStub: DefaultImplCaller?

    func enableDefaultImplementation<_CUCKOO$$GENERIC: ConnectionPoolProtocol>(_ stub: _CUCKOO$$GENERIC) where _CUCKOO$$GENERIC.T == T {
        var mutableStub = stub
        __defaultImplStub = DefaultImplCaller(from: &mutableStub, keeping: mutableStub)
        cuckoo_manager.enableDefaultStubImplementation()
    }

    func enableDefaultImplementation<_CUCKOO$$GENERIC: ConnectionPoolProtocol>(mutating stub: UnsafeMutablePointer<_CUCKOO$$GENERIC>) where _CUCKOO$$GENERIC.T == T {
        __defaultImplStub = DefaultImplCaller(from: stub, keeping: nil)
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func setupConnection(for p0: ChainModel) throws -> T {
        return try cuckoo_manager.callThrows(
            "setupConnection(for p0: ChainModel) throws -> T",
            parameters: (p0),
            escapingParameters: (p0),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.setupConnection(for: p0)
        )
    }

    func getConnection(for p0: ChainModel.Id) -> T? {
        return cuckoo_manager.call(
            "getConnection(for p0: ChainModel.Id) -> T?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getConnection(for: p0)
        )
    }

    func setDelegate(_ p0: ConnectionPoolDelegate) {
        return cuckoo_manager.call(
            "setDelegate(_ p0: ConnectionPoolDelegate)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.setDelegate(p0)
        )
    }

    func resetConnection(for p0: ChainModel.Id) {
        return cuckoo_manager.call(
            "resetConnection(for p0: ChainModel.Id)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.resetConnection(for: p0)
        )
    }

    struct __StubbingProxy_ConnectionPoolProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func setupConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel), T,Swift.Error> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self,
                method: "setupConnection(for p0: ChainModel) throws -> T",
                parameterMatchers: matchers
            ))
        }
        
        func getConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), T?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self,
                method: "getConnection(for p0: ChainModel.Id) -> T?",
                parameterMatchers: matchers
            ))
        }
        
        func setDelegate<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionPoolDelegate)> where M1.MatchedType == ConnectionPoolDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(ConnectionPoolDelegate)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self,
                method: "setDelegate(_ p0: ConnectionPoolDelegate)",
                parameterMatchers: matchers
            ))
        }
        
        func resetConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self,
                method: "resetConnection(for p0: ChainModel.Id)",
                parameterMatchers: matchers
            ))
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
        func setupConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel), T> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "setupConnection(for p0: ChainModel) throws -> T",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), T?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getConnection(for p0: ChainModel.Id) -> T?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func setDelegate<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<(ConnectionPoolDelegate), Void> where M1.MatchedType == ConnectionPoolDelegate {
            let matchers: [Cuckoo.ParameterMatcher<(ConnectionPoolDelegate)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "setDelegate(_ p0: ConnectionPoolDelegate)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func resetConnection<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "resetConnection(for p0: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class ConnectionPoolProtocolStub<T>:ConnectionPoolProtocol, @unchecked Sendable {


    
    func setupConnection(for p0: ChainModel) throws -> T {
        return DefaultValueRegistry.defaultValue(for: (T).self)
    }
    
    func getConnection(for p0: ChainModel.Id) -> T? {
        return DefaultValueRegistry.defaultValue(for: (T?).self)
    }
    
    func setDelegate(_ p0: ConnectionPoolDelegate) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func resetConnection(for p0: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockConnectionPoolDelegate: ConnectionPoolDelegate, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = ConnectionPoolDelegate
    typealias Stubbing = __StubbingProxy_ConnectionPoolDelegate
    typealias Verification = __VerificationProxy_ConnectionPoolDelegate

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any ConnectionPoolDelegate)?

    func enableDefaultImplementation(_ stub: any ConnectionPoolDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func webSocketDidChangeState(chainId p0: ChainModel.Id, state p1: WebSocketEngine.State) {
        return cuckoo_manager.call(
            "webSocketDidChangeState(chainId p0: ChainModel.Id, state p1: WebSocketEngine.State)",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.webSocketDidChangeState(chainId: p0, state: p1)
        )
    }

    struct __StubbingProxy_ConnectionPoolDelegate: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func webSocketDidChangeState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chainId p0: M1, state p1: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id, WebSocketEngine.State)> where M1.MatchedType == ChainModel.Id, M2.MatchedType == WebSocketEngine.State {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, WebSocketEngine.State)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolDelegate.self,
                method: "webSocketDidChangeState(chainId p0: ChainModel.Id, state p1: WebSocketEngine.State)",
                parameterMatchers: matchers
            ))
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
        func webSocketDidChangeState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chainId p0: M1, state p1: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, WebSocketEngine.State), Void> where M1.MatchedType == ChainModel.Id, M2.MatchedType == WebSocketEngine.State {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, WebSocketEngine.State)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "webSocketDidChangeState(chainId p0: ChainModel.Id, state p1: WebSocketEngine.State)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class ConnectionPoolDelegateStub:ConnectionPoolDelegate, @unchecked Sendable {


    
    func webSocketDidChangeState(chainId p0: ChainModel.Id, state p1: WebSocketEngine.State) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/RuntimeFilesOperationFactory.swift'

import Cuckoo
import Foundation
import RobinHood
@testable import fearless
@testable import SoraKeystore

class MockRuntimeFilesOperationFactoryProtocol: RuntimeFilesOperationFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = RuntimeFilesOperationFactoryProtocol
    typealias Stubbing = __StubbingProxy_RuntimeFilesOperationFactoryProtocol
    typealias Verification = __VerificationProxy_RuntimeFilesOperationFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any RuntimeFilesOperationFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any RuntimeFilesOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        return cuckoo_manager.call(
            "fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchCommonTypesOperation()
        )
    }

    func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> {
        return cuckoo_manager.call(
            "fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchChainsTypesOperation()
        )
    }

    func fetchChainTypesOperation(for p0: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        return cuckoo_manager.call(
            "fetchChainTypesOperation(for p0: ChainModel.Id) -> CompoundOperationWrapper<Data?>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.fetchChainTypesOperation(for: p0)
        )
    }

    func saveCommonTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return cuckoo_manager.call(
            "saveCommonTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.saveCommonTypesOperation(data: p0)
        )
    }

    func saveChainsTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return cuckoo_manager.call(
            "saveChainsTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.saveChainsTypesOperation(data: p0)
        )
    }

    func saveChainTypesOperation(for p0: ChainModel.Id, data p1: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return cuckoo_manager.call(
            "saveChainTypesOperation(for p0: ChainModel.Id, data p1: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.saveChainTypesOperation(for: p0, data: p1)
        )
    }

    struct __StubbingProxy_RuntimeFilesOperationFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func fetchCommonTypesOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>",
                parameterMatchers: matchers
            ))
        }
        
        func fetchChainsTypesOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>",
                parameterMatchers: matchers
            ))
        }
        
        func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "fetchChainTypesOperation(for p0: ChainModel.Id) -> CompoundOperationWrapper<Data?>",
                parameterMatchers: matchers
            ))
        }
        
        func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data p0: M1) -> Cuckoo.ProtocolStubFunction<( () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<( () throws -> Data)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "saveCommonTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                parameterMatchers: matchers
            ))
        }
        
        func saveChainsTypesOperation<M1: Cuckoo.Matchable>(data p0: M1) -> Cuckoo.ProtocolStubFunction<( () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<( () throws -> Data)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "saveChainsTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                parameterMatchers: matchers
            ))
        }
        
        func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for p0: M1, data p1: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id,  () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id,  () throws -> Data)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self,
                method: "saveChainTypesOperation(for p0: ChainModel.Id, data p1: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                parameterMatchers: matchers
            ))
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
                "fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func fetchChainsTypesOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<Data?>> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "fetchChainTypesOperation(for p0: ChainModel.Id) -> CompoundOperationWrapper<Data?>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data p0: M1) -> Cuckoo.__DoNotUse<( () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<( () throws -> Data)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "saveCommonTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func saveChainsTypesOperation<M1: Cuckoo.Matchable>(data p0: M1) -> Cuckoo.__DoNotUse<( () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<( () throws -> Data)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "saveChainsTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for p0: M1, data p1: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id,  () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType ==  () throws -> Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id,  () throws -> Data)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "saveChainTypesOperation(for p0: ChainModel.Id, data p1: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class RuntimeFilesOperationFactoryProtocolStub:RuntimeFilesOperationFactoryProtocol, @unchecked Sendable {


    
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    func fetchChainTypesOperation(for p0: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    func saveCommonTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    func saveChainsTypesOperation(data p0: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    func saveChainTypesOperation(for p0: ChainModel.Id, data p1: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeProvider.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless
@testable import SoraKeystore



// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeProviderFactory.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFRuntimeCodingService
@testable import fearless
@testable import SoraKeystore

class MockRuntimeProviderFactoryProtocol: RuntimeProviderFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = RuntimeProviderFactoryProtocol
    typealias Stubbing = __StubbingProxy_RuntimeProviderFactoryProtocol
    typealias Verification = __VerificationProxy_RuntimeProviderFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any RuntimeProviderFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any RuntimeProviderFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func createRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?, usedRuntimePaths p2: [String: [String]]) -> RuntimeProviderProtocol {
        return cuckoo_manager.call(
            "createRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?, usedRuntimePaths p2: [String: [String]]) -> RuntimeProviderProtocol",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createRuntimeProvider(for: p0, chainTypes: p1, usedRuntimePaths: p2)
        )
    }

    func createHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data, usedRuntimePaths p3: [String: [String]]) -> RuntimeProviderProtocol {
        return cuckoo_manager.call(
            "createHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data, usedRuntimePaths p3: [String: [String]]) -> RuntimeProviderProtocol",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createHotRuntimeProvider(for: p0, runtimeItem: p1, chainTypes: p2, usedRuntimePaths: p3)
        )
    }

    struct __StubbingProxy_RuntimeProviderFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func createRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for p0: M1, chainTypes p1: M2, usedRuntimePaths p2: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel, Data?, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data, M3.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?, [String: [String]])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderFactoryProtocol.self,
                method: "createRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?, usedRuntimePaths p2: [String: [String]]) -> RuntimeProviderProtocol",
                parameterMatchers: matchers
            ))
        }
        
        func createHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for p0: M1, runtimeItem p1: M2, chainTypes p2: M3, usedRuntimePaths p3: M4) -> Cuckoo.ProtocolStubFunction<(ChainModel, RuntimeMetadataItem, Data, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, [String: [String]])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderFactoryProtocol.self,
                method: "createHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data, usedRuntimePaths p3: [String: [String]]) -> RuntimeProviderProtocol",
                parameterMatchers: matchers
            ))
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
        func createRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for p0: M1, chainTypes p1: M2, usedRuntimePaths p2: M3) -> Cuckoo.__DoNotUse<(ChainModel, Data?, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data, M3.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?, [String: [String]])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "createRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?, usedRuntimePaths p2: [String: [String]]) -> RuntimeProviderProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for p0: M1, runtimeItem p1: M2, chainTypes p2: M3, usedRuntimePaths p3: M4) -> Cuckoo.__DoNotUse<(ChainModel, RuntimeMetadataItem, Data, [String: [String]]), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data, M4.MatchedType == [String: [String]] {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data, [String: [String]])>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "createHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data, usedRuntimePaths p3: [String: [String]]) -> RuntimeProviderProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class RuntimeProviderFactoryProtocolStub:RuntimeProviderFactoryProtocol, @unchecked Sendable {


    
    func createRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?, usedRuntimePaths p2: [String: [String]]) -> RuntimeProviderProtocol {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    func createHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data, usedRuntimePaths p3: [String: [String]]) -> RuntimeProviderProtocol {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeProviderPool.swift'

import Cuckoo
import Foundation
import SSFRuntimeCodingService
@testable import fearless
@testable import SoraKeystore

class MockRuntimeProviderPoolProtocol: RuntimeProviderPoolProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = RuntimeProviderPoolProtocol
    typealias Stubbing = __StubbingProxy_RuntimeProviderPoolProtocol
    typealias Verification = __VerificationProxy_RuntimeProviderPoolProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any RuntimeProviderPoolProtocol)?

    func enableDefaultImplementation(_ stub: any RuntimeProviderPoolProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func setupRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?) -> RuntimeProviderProtocol {
        return cuckoo_manager.call(
            "setupRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?) -> RuntimeProviderProtocol",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.setupRuntimeProvider(for: p0, chainTypes: p1)
        )
    }

    func setupHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data) -> RuntimeProviderProtocol {
        return cuckoo_manager.call(
            "setupHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data) -> RuntimeProviderProtocol",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.setupHotRuntimeProvider(for: p0, runtimeItem: p1, chainTypes: p2)
        )
    }

    func destroyRuntimeProvider(for p0: ChainModel.Id) {
        return cuckoo_manager.call(
            "destroyRuntimeProvider(for p0: ChainModel.Id)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.destroyRuntimeProvider(for: p0)
        )
    }

    func getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol? {
        return cuckoo_manager.call(
            "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: p0)
        )
    }

    struct __StubbingProxy_RuntimeProviderPoolProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func setupRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for p0: M1, chainTypes p1: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel, Data?), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self,
                method: "setupRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?) -> RuntimeProviderProtocol",
                parameterMatchers: matchers
            ))
        }
        
        func setupHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, runtimeItem p1: M2, chainTypes p2: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel, RuntimeMetadataItem, Data), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self,
                method: "setupHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data) -> RuntimeProviderProtocol",
                parameterMatchers: matchers
            ))
        }
        
        func destroyRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self,
                method: "destroyRuntimeProvider(for p0: ChainModel.Id)",
                parameterMatchers: matchers
            ))
        }
        
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self,
                method: "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
                parameterMatchers: matchers
            ))
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
        func setupRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for p0: M1, chainTypes p1: M2) -> Cuckoo.__DoNotUse<(ChainModel, Data?), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.OptionalMatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, Data?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "setupRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?) -> RuntimeProviderProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func setupHotRuntimeProvider<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for p0: M1, runtimeItem p1: M2, chainTypes p2: M3) -> Cuckoo.__DoNotUse<(ChainModel, RuntimeMetadataItem, Data), RuntimeProviderProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == RuntimeMetadataItem, M3.MatchedType == Data {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, RuntimeMetadataItem, Data)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "setupHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data) -> RuntimeProviderProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func destroyRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "destroyRuntimeProvider(for p0: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func getRuntimeProvider<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class RuntimeProviderPoolProtocolStub:RuntimeProviderPoolProtocol, @unchecked Sendable {


    
    func setupRuntimeProvider(for p0: ChainModel, chainTypes p1: Data?) -> RuntimeProviderProtocol {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    func setupHotRuntimeProvider(for p0: ChainModel, runtimeItem p1: RuntimeMetadataItem, chainTypes p2: Data) -> RuntimeProviderProtocol {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    func destroyRuntimeProvider(for p0: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func getRuntimeProvider(for p0: ChainModel.Id) -> RuntimeProviderProtocol? {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeSyncService.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockRuntimeSyncServiceProtocol: RuntimeSyncServiceProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = RuntimeSyncServiceProtocol
    typealias Stubbing = __StubbingProxy_RuntimeSyncServiceProtocol
    typealias Verification = __VerificationProxy_RuntimeSyncServiceProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any RuntimeSyncServiceProtocol)?

    func enableDefaultImplementation(_ stub: any RuntimeSyncServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func register(chain p0: ChainModel, with p1: ChainConnection) {
        return cuckoo_manager.call(
            "register(chain p0: ChainModel, with p1: ChainConnection)",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.register(chain: p0, with: p1)
        )
    }

    func unregister(chainId p0: ChainModel.Id) {
        return cuckoo_manager.call(
            "unregister(chainId p0: ChainModel.Id)",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.unregister(chainId: p0)
        )
    }

    func apply(version p0: RuntimeVersion, for p1: ChainModel.Id) {
        return cuckoo_manager.call(
            "apply(version p0: RuntimeVersion, for p1: ChainModel.Id)",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.apply(version: p0, for: p1)
        )
    }

    func hasChain(with p0: ChainModel.Id) -> Bool {
        return cuckoo_manager.call(
            "hasChain(with p0: ChainModel.Id) -> Bool",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.hasChain(with: p0)
        )
    }

    func isChainSyncing(_ p0: ChainModel.Id) -> Bool {
        return cuckoo_manager.call(
            "isChainSyncing(_ p0: ChainModel.Id) -> Bool",
            parameters: (p0),
            escapingParameters: (p0),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.isChainSyncing(p0)
        )
    }

    struct __StubbingProxy_RuntimeSyncServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain p0: M1, with p1: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel, ChainConnection)> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self,
                method: "register(chain p0: ChainModel, with p1: ChainConnection)",
                parameterMatchers: matchers
            ))
        }
        
        func unregister<M1: Cuckoo.Matchable>(chainId p0: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self,
                method: "unregister(chainId p0: ChainModel.Id)",
                parameterMatchers: matchers
            ))
        }
        
        func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version p0: M1, for p1: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeVersion, ChainModel.Id)> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self,
                method: "apply(version p0: RuntimeVersion, for p1: ChainModel.Id)",
                parameterMatchers: matchers
            ))
        }
        
        func hasChain<M1: Cuckoo.Matchable>(with p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self,
                method: "hasChain(with p0: ChainModel.Id) -> Bool",
                parameterMatchers: matchers
            ))
        }
        
        func isChainSyncing<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self,
                method: "isChainSyncing(_ p0: ChainModel.Id) -> Bool",
                parameterMatchers: matchers
            ))
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
        func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain p0: M1, with p1: M2) -> Cuckoo.__DoNotUse<(ChainModel, ChainConnection), Void> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "register(chain p0: ChainModel, with p1: ChainConnection)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func unregister<M1: Cuckoo.Matchable>(chainId p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "unregister(chainId p0: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version p0: M1, for p1: M2) -> Cuckoo.__DoNotUse<(RuntimeVersion, ChainModel.Id), Void> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "apply(version p0: RuntimeVersion, for p1: ChainModel.Id)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func hasChain<M1: Cuckoo.Matchable>(with p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "hasChain(with p0: ChainModel.Id) -> Bool",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func isChainSyncing<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "isChainSyncing(_ p0: ChainModel.Id) -> Bool",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class RuntimeSyncServiceProtocolStub:RuntimeSyncServiceProtocol, @unchecked Sendable {


    
    func register(chain p0: ChainModel, with p1: ChainConnection) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func unregister(chainId p0: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func apply(version p0: RuntimeVersion, for p1: ChainModel.Id) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func hasChain(with p0: ChainModel.Id) -> Bool {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    func isChainSyncing(_ p0: ChainModel.Id) -> Bool {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/SpecVersionSubscription.swift'

import Cuckoo
import Foundation
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockSpecVersionSubscriptionProtocol: SpecVersionSubscriptionProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = SpecVersionSubscriptionProtocol
    typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionProtocol
    typealias Verification = __VerificationProxy_SpecVersionSubscriptionProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SpecVersionSubscriptionProtocol)?

    func enableDefaultImplementation(_ stub: any SpecVersionSubscriptionProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func subscribe() {
        return cuckoo_manager.call(
            "subscribe()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.subscribe()
        )
    }

    func unsubscribe() {
        return cuckoo_manager.call(
            "unsubscribe()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.unsubscribe()
        )
    }

    struct __StubbingProxy_SpecVersionSubscriptionProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func subscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self,
                method: "subscribe()",
                parameterMatchers: matchers
            ))
        }
        
        func unsubscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self,
                method: "unsubscribe()",
                parameterMatchers: matchers
            ))
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
                "subscribe()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func unsubscribe() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "unsubscribe()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class SpecVersionSubscriptionProtocolStub:SpecVersionSubscriptionProtocol, @unchecked Sendable {


    
    func subscribe() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func unsubscribe() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/ChainRegistry/SpecVersionSubscriptionFactory.swift'

import Cuckoo
import Foundation
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockSpecVersionSubscriptionFactoryProtocol: SpecVersionSubscriptionFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = SpecVersionSubscriptionFactoryProtocol
    typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionFactoryProtocol
    typealias Verification = __VerificationProxy_SpecVersionSubscriptionFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any SpecVersionSubscriptionFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any SpecVersionSubscriptionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func createSubscription(for p0: ChainModel.Id, connection p1: JSONRPCEngine) -> SpecVersionSubscriptionProtocol {
        return cuckoo_manager.call(
            "createSubscription(for p0: ChainModel.Id, connection p1: JSONRPCEngine) -> SpecVersionSubscriptionProtocol",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createSubscription(for: p0, connection: p1)
        )
    }

    struct __StubbingProxy_SpecVersionSubscriptionFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for p0: M1, connection p1: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == JSONRPCEngine {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, JSONRPCEngine)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionFactoryProtocol.self,
                method: "createSubscription(for p0: ChainModel.Id, connection p1: JSONRPCEngine) -> SpecVersionSubscriptionProtocol",
                parameterMatchers: matchers
            ))
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
        func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for p0: M1, connection p1: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == JSONRPCEngine {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, JSONRPCEngine)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return cuckoo_manager.verify(
                "createSubscription(for p0: ChainModel.Id, connection p1: JSONRPCEngine) -> SpecVersionSubscriptionProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class SpecVersionSubscriptionFactoryProtocolStub:SpecVersionSubscriptionFactoryProtocol, @unchecked Sendable {


    
    func createSubscription(for p0: ChainModel.Id, connection p1: JSONRPCEngine) -> SpecVersionSubscriptionProtocol {
        return DefaultValueRegistry.defaultValue(for: (SpecVersionSubscriptionProtocol).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/RemoteSubscription/CrowdloanRemoteSubscriptionService.swift'

import Cuckoo
import Foundation
@testable import fearless
@testable import SoraKeystore

class MockCrowdloanRemoteSubscriptionServiceProtocol: CrowdloanRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = CrowdloanRemoteSubscriptionServiceProtocol
    typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol
    typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionServiceProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any CrowdloanRemoteSubscriptionServiceProtocol)?

    func enableDefaultImplementation(_ stub: any CrowdloanRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID? {
        return cuckoo_manager.call(
            "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.attach(for: p0, runningCompletionIn: p1, completion: p2)
        )
    }

    func detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?) {
        return cuckoo_manager.call(
            "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.detach(for: p0, chainId: p1, runningCompletionIn: p2, completion: p3)
        )
    }

    struct __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for p0: M1, runningCompletionIn p1: M2, completion p2: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self,
                method: "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
                parameterMatchers: matchers
            ))
        }
        
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, runningCompletionIn p2: M3, completion p3: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self,
                method: "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
                parameterMatchers: matchers
            ))
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
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for p0: M1, runningCompletionIn p1: M2, completion p2: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, runningCompletionIn p2: M3, completion p3: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class CrowdloanRemoteSubscriptionServiceProtocolStub:CrowdloanRemoteSubscriptionServiceProtocol, @unchecked Sendable {


    
    func attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID? {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    func detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockCrowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionService, Cuckoo.ClassMock, @unchecked Sendable {
    typealias MocksType = CrowdloanRemoteSubscriptionService
    typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionService
    typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionService

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    private var __defaultImplStub: CrowdloanRemoteSubscriptionService?

    func enableDefaultImplementation(_ stub: CrowdloanRemoteSubscriptionService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    override func attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID? {
        return cuckoo_manager.call(
            "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
            parameters: (p0, p1, p2),
            escapingParameters: (p0, p1, p2),
            superclassCall: super.attach(for: p0, runningCompletionIn: p1, completion: p2),
            defaultCall: __defaultImplStub!.attach(for: p0, runningCompletionIn: p1, completion: p2)
        )
    }

    override func detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?) {
        return cuckoo_manager.call(
            "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: super.detach(for: p0, chainId: p1, runningCompletionIn: p2, completion: p3),
            defaultCall: __defaultImplStub!.detach(for: p0, chainId: p1, runningCompletionIn: p2, completion: p3)
        )
    }

    struct __StubbingProxy_CrowdloanRemoteSubscriptionService: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for p0: M1, runningCompletionIn p1: M2, completion p2: M3) -> Cuckoo.ClassStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self,
                method: "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
                parameterMatchers: matchers
            ))
        }
        
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, runningCompletionIn p2: M3, completion p3: M4) -> Cuckoo.ClassStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self,
                method: "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
                parameterMatchers: matchers
            ))
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
        func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for p0: M1, runningCompletionIn p1: M2, completion p2: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }]
            return cuckoo_manager.verify(
                "attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, runningCompletionIn p2: M3, completion p3: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class CrowdloanRemoteSubscriptionServiceStub:CrowdloanRemoteSubscriptionService, @unchecked Sendable {


    
    override func attach(for p0: ChainModel.Id, runningCompletionIn p1: DispatchQueue?, completion p2: RemoteSubscriptionClosure?) -> UUID? {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    override func detach(for p0: UUID, chainId p1: ChainModel.Id, runningCompletionIn p2: DispatchQueue?, completion p3: RemoteSubscriptionClosure?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/RemoteSubscription/StakingAccountUpdatingService.swift'

import Cuckoo
import Foundation
import RobinHood
@testable import fearless
@testable import SoraKeystore

class MockStakingAccountUpdatingServiceProtocol: StakingAccountUpdatingServiceProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = StakingAccountUpdatingServiceProtocol
    typealias Stubbing = __StubbingProxy_StakingAccountUpdatingServiceProtocol
    typealias Verification = __VerificationProxy_StakingAccountUpdatingServiceProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any StakingAccountUpdatingServiceProtocol)?

    func enableDefaultImplementation(_ stub: any StakingAccountUpdatingServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func setupSubscription(for p0: AccountId, chainAsset p1: ChainAsset, chainFormat p2: ChainFormat, stakingType p3: StakingType) throws {
        return try cuckoo_manager.callThrows(
            "setupSubscription(for p0: AccountId, chainAsset p1: ChainAsset, chainFormat p2: ChainFormat, stakingType p3: StakingType) throws",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.setupSubscription(for: p0, chainAsset: p1, chainFormat: p2, stakingType: p3)
        )
    }

    func clearSubscription() {
        return cuckoo_manager.call(
            "clearSubscription()",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.clearSubscription()
        )
    }

    struct __StubbingProxy_StakingAccountUpdatingServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for p0: M1, chainAsset p1: M2, chainFormat p2: M3, stakingType p3: M4) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(AccountId, ChainAsset, ChainFormat, StakingType),Swift.Error> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.MatchedType == ChainFormat, M4.MatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, ChainFormat, StakingType)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self,
                method: "setupSubscription(for p0: AccountId, chainAsset p1: ChainAsset, chainFormat p2: ChainFormat, stakingType p3: StakingType) throws",
                parameterMatchers: matchers
            ))
        }
        
        func clearSubscription() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self,
                method: "clearSubscription()",
                parameterMatchers: matchers
            ))
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
        func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(for p0: M1, chainAsset p1: M2, chainFormat p2: M3, stakingType p3: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, ChainFormat, StakingType), Void> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.MatchedType == ChainFormat, M4.MatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, ChainFormat, StakingType)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "setupSubscription(for p0: AccountId, chainAsset p1: ChainAsset, chainFormat p2: ChainFormat, stakingType p3: StakingType) throws",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func clearSubscription() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
                "clearSubscription()",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class StakingAccountUpdatingServiceProtocolStub:StakingAccountUpdatingServiceProtocol, @unchecked Sendable {


    
    func setupSubscription(for p0: AccountId, chainAsset p1: ChainAsset, chainFormat p2: ChainFormat, stakingType p3: StakingType) throws {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    func clearSubscription() {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/RemoteSubscription/StakingRemoteSubscriptionService.swift'

import Cuckoo
import Foundation
import SSFUtils
@testable import fearless
@testable import SoraKeystore

class MockStakingRemoteSubscriptionServiceProtocol: StakingRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = StakingRemoteSubscriptionServiceProtocol
    typealias Stubbing = __StubbingProxy_StakingRemoteSubscriptionServiceProtocol
    typealias Verification = __VerificationProxy_StakingRemoteSubscriptionServiceProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any StakingRemoteSubscriptionServiceProtocol)?

    func enableDefaultImplementation(_ stub: any StakingRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func attachToGlobalData(for p0: ChainModel.Id, queue p1: DispatchQueue?, closure p2: RemoteSubscriptionClosure?, stakingType p3: StakingType?) -> UUID? {
        return cuckoo_manager.call(
            "attachToGlobalData(for p0: ChainModel.Id, queue p1: DispatchQueue?, closure p2: RemoteSubscriptionClosure?, stakingType p3: StakingType?) -> UUID?",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.attachToGlobalData(for: p0, queue: p1, closure: p2, stakingType: p3)
        )
    }

    func detachFromGlobalData(for p0: UUID, chainId p1: ChainModel.Id, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?, stakingType p4: StakingType?) {
        return cuckoo_manager.call(
            "detachFromGlobalData(for p0: UUID, chainId p1: ChainModel.Id, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?, stakingType p4: StakingType?)",
            parameters: (p0, p1, p2, p3, p4),
            escapingParameters: (p0, p1, p2, p3, p4),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.detachFromGlobalData(for: p0, chainId: p1, queue: p2, closure: p3, stakingType: p4)
        )
    }

    struct __StubbingProxy_StakingRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func attachToGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, queue p1: M2, closure p2: M3, stakingType p3: M4) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure, M4.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingRemoteSubscriptionServiceProtocol.self,
                method: "attachToGlobalData(for p0: ChainModel.Id, queue p1: DispatchQueue?, closure p2: RemoteSubscriptionClosure?, stakingType p3: StakingType?) -> UUID?",
                parameterMatchers: matchers
            ))
        }
        
        func detachFromGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, queue p2: M3, closure p3: M4, stakingType p4: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure, M5.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }, wrap(matchable: p4) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingRemoteSubscriptionServiceProtocol.self,
                method: "detachFromGlobalData(for p0: UUID, chainId p1: ChainModel.Id, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?, stakingType p4: StakingType?)",
                parameterMatchers: matchers
            ))
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
        func attachToGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, queue p1: M2, closure p2: M3, stakingType p3: M4) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure, M4.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "attachToGlobalData(for p0: ChainModel.Id, queue p1: DispatchQueue?, closure p2: RemoteSubscriptionClosure?, stakingType p3: StakingType?) -> UUID?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func detachFromGlobalData<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(for p0: M1, chainId p1: M2, queue p2: M3, closure p3: M4, stakingType p4: M5) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure, M5.OptionalMatchedType == StakingType {
            let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?, StakingType?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }, wrap(matchable: p4) { $0.4 }]
            return cuckoo_manager.verify(
                "detachFromGlobalData(for p0: UUID, chainId p1: ChainModel.Id, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?, stakingType p4: StakingType?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class StakingRemoteSubscriptionServiceProtocolStub:StakingRemoteSubscriptionServiceProtocol, @unchecked Sendable {


    
    func attachToGlobalData(for p0: ChainModel.Id, queue p1: DispatchQueue?, closure p2: RemoteSubscriptionClosure?, stakingType p3: StakingType?) -> UUID? {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    func detachFromGlobalData(for p0: UUID, chainId p1: ChainModel.Id, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?, stakingType p4: StakingType?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Common/Services/RemoteSubscription/WalletRemoteSubscriptionService.swift'

import Cuckoo
import Foundation
@testable import fearless
@testable import SoraKeystore

class MockWalletRemoteSubscriptionServiceProtocol: WalletRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = WalletRemoteSubscriptionServiceProtocol
    typealias Stubbing = __StubbingProxy_WalletRemoteSubscriptionServiceProtocol
    typealias Verification = __VerificationProxy_WalletRemoteSubscriptionServiceProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any WalletRemoteSubscriptionServiceProtocol)?

    func enableDefaultImplementation(_ stub: any WalletRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String? {
        return await cuckoo_manager.call(
            "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: await __defaultImplStub!.attachToAccountInfo(of: p0, chainAsset: p1, queue: p2, closure: p3)
        )
    }

    func detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) {
        return cuckoo_manager.call(
            "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.detachFromAccountInfo(for: p0, chainAssetKey: p1, queue: p2, closure: p3)
        )
    }

    struct __StubbingProxy_WalletRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of p0: M1, chainAsset p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.ProtocolStubFunction<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), String?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionServiceProtocol.self,
                method: "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
                parameterMatchers: matchers
            ))
        }
        
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainAssetKey p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == String, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionServiceProtocol.self,
                method: "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
                parameterMatchers: matchers
            ))
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
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of p0: M1, chainAsset p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), String?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainAssetKey p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.__DoNotUse<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == String, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class WalletRemoteSubscriptionServiceProtocolStub:WalletRemoteSubscriptionServiceProtocol, @unchecked Sendable {


    
    func attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String? {
        return DefaultValueRegistry.defaultValue(for: (String?).self)
    }
    
    func detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}


class MockWalletRemoteSubscriptionService: WalletRemoteSubscriptionService, Cuckoo.ClassMock, @unchecked Sendable {
    typealias MocksType = WalletRemoteSubscriptionService
    typealias Stubbing = __StubbingProxy_WalletRemoteSubscriptionService
    typealias Verification = __VerificationProxy_WalletRemoteSubscriptionService

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    private var __defaultImplStub: WalletRemoteSubscriptionService?

    func enableDefaultImplementation(_ stub: WalletRemoteSubscriptionService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    override func attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String? {
        return await cuckoo_manager.call(
            "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: await super.attachToAccountInfo(of: p0, chainAsset: p1, queue: p2, closure: p3),
            defaultCall: await __defaultImplStub!.attachToAccountInfo(of: p0, chainAsset: p1, queue: p2, closure: p3)
        )
    }

    override func detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) {
        return cuckoo_manager.call(
            "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            superclassCall: super.detachFromAccountInfo(for: p0, chainAssetKey: p1, queue: p2, closure: p3),
            defaultCall: __defaultImplStub!.detachFromAccountInfo(for: p0, chainAssetKey: p1, queue: p2, closure: p3)
        )
    }

    struct __StubbingProxy_WalletRemoteSubscriptionService: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of p0: M1, chainAsset p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.ClassStubFunction<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), String?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionService.self,
                method: "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
                parameterMatchers: matchers
            ))
        }
        
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainAssetKey p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.ClassStubNoReturnFunction<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == String, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockWalletRemoteSubscriptionService.self,
                method: "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
                parameterMatchers: matchers
            ))
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
        func attachToAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(of p0: M1, chainAsset p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.__DoNotUse<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?), String?> where M1.MatchedType == AccountId, M2.MatchedType == ChainAsset, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainAsset, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String?",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func detachFromAccountInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, chainAssetKey p1: M2, queue p2: M3, closure p3: M4) -> Cuckoo.__DoNotUse<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == String, M2.MatchedType == ChainAssetKey, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
            let matchers: [Cuckoo.ParameterMatcher<(String, ChainAssetKey, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?)",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class WalletRemoteSubscriptionServiceStub:WalletRemoteSubscriptionService, @unchecked Sendable {


    
    override func attachToAccountInfo(of p0: AccountId, chainAsset p1: ChainAsset, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) async -> String? {
        return DefaultValueRegistry.defaultValue(for: (String?).self)
    }
    
    override func detachFromAccountInfo(for p0: String, chainAssetKey p1: ChainAssetKey, queue p2: DispatchQueue?, closure p3: RemoteSubscriptionClosure?) {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
}




// MARK: - Mocks generated from file: 'fearless/Modules/Staking/Services/StakingServiceFactory.swift'

import Cuckoo
import Foundation
import RobinHood
import SSFUtils
import SSFStorageQueryKit
import SSFAssetManagmentStorage
@testable import fearless
@testable import SoraKeystore

class MockStakingServiceFactoryProtocol: StakingServiceFactoryProtocol, Cuckoo.ProtocolMock, @unchecked Sendable {
    typealias MocksType = StakingServiceFactoryProtocol
    typealias Stubbing = __StubbingProxy_StakingServiceFactoryProtocol
    typealias Verification = __VerificationProxy_StakingServiceFactoryProtocol

    // Original typealiases

    let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any StakingServiceFactoryProtocol)?

    func enableDefaultImplementation(_ stub: any StakingServiceFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }


    func createEraValidatorService(for p0: ChainModel) throws -> EraValidatorServiceProtocol {
        return try cuckoo_manager.callThrows(
            "createEraValidatorService(for p0: ChainModel) throws -> EraValidatorServiceProtocol",
            parameters: (p0),
            escapingParameters: (p0),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createEraValidatorService(for: p0)
        )
    }

    func createRewardCalculatorService(for p0: ChainAsset, assetPrecision p1: Int16, validatorService p2: EraValidatorServiceProtocol, collatorOperationFactory p3: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol {
        return try cuckoo_manager.callThrows(
            "createRewardCalculatorService(for p0: ChainAsset, assetPrecision p1: Int16, validatorService p2: EraValidatorServiceProtocol, collatorOperationFactory p3: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol",
            parameters: (p0, p1, p2, p3),
            escapingParameters: (p0, p1, p2, p3),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: __defaultImplStub!.createRewardCalculatorService(for: p0, assetPrecision: p1, validatorService: p2, collatorOperationFactory: p3)
        )
    }

    struct __StubbingProxy_StakingServiceFactoryProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
        init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        func createEraValidatorService<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel), EraValidatorServiceProtocol,Swift.Error> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self,
                method: "createEraValidatorService(for p0: ChainModel) throws -> EraValidatorServiceProtocol",
                parameterMatchers: matchers
            ))
        }
        
        func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, assetPrecision p1: M2, validatorService p2: M3, collatorOperationFactory p3: M4) -> Cuckoo.ProtocolStubThrowingFunction<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?), RewardCalculatorServiceProtocol,Swift.Error> where M1.MatchedType == ChainAsset, M2.MatchedType == Int16, M3.MatchedType == EraValidatorServiceProtocol, M4.OptionalMatchedType == ParachainCollatorOperationFactory {
            let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self,
                method: "createRewardCalculatorService(for p0: ChainAsset, assetPrecision p1: Int16, validatorService p2: EraValidatorServiceProtocol, collatorOperationFactory p3: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol",
                parameterMatchers: matchers
            ))
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
        func createEraValidatorService<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<(ChainModel), EraValidatorServiceProtocol> where M1.MatchedType == ChainModel {
            let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: p0) { $0 }]
            return cuckoo_manager.verify(
                "createEraValidatorService(for p0: ChainModel) throws -> EraValidatorServiceProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        
        
        @discardableResult
        func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable>(for p0: M1, assetPrecision p1: M2, validatorService p2: M3, collatorOperationFactory p3: M4) -> Cuckoo.__DoNotUse<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?), RewardCalculatorServiceProtocol> where M1.MatchedType == ChainAsset, M2.MatchedType == Int16, M3.MatchedType == EraValidatorServiceProtocol, M4.OptionalMatchedType == ParachainCollatorOperationFactory {
            let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, Int16, EraValidatorServiceProtocol, ParachainCollatorOperationFactory?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }, wrap(matchable: p2) { $0.2 }, wrap(matchable: p3) { $0.3 }]
            return cuckoo_manager.verify(
                "createRewardCalculatorService(for p0: ChainAsset, assetPrecision p1: Int16, validatorService p2: EraValidatorServiceProtocol, collatorOperationFactory p3: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
    }
}

class StakingServiceFactoryProtocolStub:StakingServiceFactoryProtocol, @unchecked Sendable {


    
    func createEraValidatorService(for p0: ChainModel) throws -> EraValidatorServiceProtocol {
        return DefaultValueRegistry.defaultValue(for: (EraValidatorServiceProtocol).self)
    }
    
    func createRewardCalculatorService(for p0: ChainAsset, assetPrecision p1: Int16, validatorService p2: EraValidatorServiceProtocol, collatorOperationFactory p3: ParachainCollatorOperationFactory?) throws -> RewardCalculatorServiceProtocol {
        return DefaultValueRegistry.defaultValue(for: (RewardCalculatorServiceProtocol).self)
    }
}
