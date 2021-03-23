import Cuckoo
@testable import fearless

import Foundation


public class MockLocalizable: Localizable, Cuckoo.ProtocolMock {
    
    public typealias MocksType = Localizable
    
    public typealias Stubbing = __StubbingProxy_Localizable
    public typealias Verification = __VerificationProxy_Localizable

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: Localizable?

    public func enableDefaultImplementation(_ stub: Localizable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    

    

    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    

	public struct __StubbingProxy_Localizable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockLocalizable, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLocalizable.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_Localizable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class LocalizableStub: Localizable {
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    

    

    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockAlertPresentable: AlertPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = AlertPresentable
    
     typealias Stubbing = __StubbingProxy_AlertPresentable
     typealias Verification = __VerificationProxy_AlertPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AlertPresentable?

     func enableDefaultImplementation(_ stub: AlertPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AlertPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AlertPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AlertPresentableStub: AlertPresentable {
    

    

    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockControllerBackedProtocol: ControllerBackedProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ControllerBackedProtocol
    
     typealias Stubbing = __StubbingProxy_ControllerBackedProtocol
     typealias Verification = __VerificationProxy_ControllerBackedProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ControllerBackedProtocol?

     func enableDefaultImplementation(_ stub: ControllerBackedProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ControllerBackedProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	}

	 struct __VerificationProxy_ControllerBackedProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ControllerBackedProtocolStub: ControllerBackedProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import fearless

import SoraUI
import UIKit


 class MockLoadableViewProtocol: LoadableViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LoadableViewProtocol
    
     typealias Stubbing = __StubbingProxy_LoadableViewProtocol
     typealias Verification = __VerificationProxy_LoadableViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LoadableViewProtocol?

     func enableDefaultImplementation(_ stub: LoadableViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_LoadableViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LoadableViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LoadableViewProtocolStub: LoadableViewProtocol {
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockModalAlertPresenting: ModalAlertPresenting, Cuckoo.ProtocolMock {
    
     typealias MocksType = ModalAlertPresenting
    
     typealias Stubbing = __StubbingProxy_ModalAlertPresenting
     typealias Verification = __VerificationProxy_ModalAlertPresenting

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ModalAlertPresenting?

     func enableDefaultImplementation(_ stub: ModalAlertPresenting) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)  {
        
    return cuckoo_manager.call("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)",
            parameters: (title, view, closure),
            escapingParameters: (title, view, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentSuccessNotification(title, from: view, completion: closure))
        
    }
    

	 struct __StubbingProxy_ModalAlertPresenting: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ControllerBackedProtocol?, (() -> Void)?)> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockModalAlertPresenting.self, method: "presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ModalAlertPresenting: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(String, ControllerBackedProtocol?, (() -> Void)?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ModalAlertPresentingStub: ModalAlertPresenting {
    

    

    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockSharingPresentable: SharingPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = SharingPresentable
    
     typealias Stubbing = __StubbingProxy_SharingPresentable
     typealias Verification = __VerificationProxy_SharingPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SharingPresentable?

     func enableDefaultImplementation(_ stub: SharingPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    

	 struct __StubbingProxy_SharingPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSharingPresentable.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SharingPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SharingPresentableStub: SharingPresentable {
    

    

    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SafariServices
import UIKit


 class MockWebPresentable: WebPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = WebPresentable
    
     typealias Stubbing = __StubbingProxy_WebPresentable
     typealias Verification = __VerificationProxy_WebPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: WebPresentable?

     func enableDefaultImplementation(_ stub: WebPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_WebPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockWebPresentable.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_WebPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class WebPresentableStub: WebPresentable {
    

    

    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless


 class MockAccountConfirmViewProtocol: AccountConfirmViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmViewProtocol
     typealias Verification = __VerificationProxy_AccountConfirmViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmViewProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReceive(words: [String], afterConfirmationFail: Bool)  {
        
    return cuckoo_manager.call("didReceive(words: [String], afterConfirmationFail: Bool)",
            parameters: (words, afterConfirmationFail),
            escapingParameters: (words, afterConfirmationFail),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(words: words, afterConfirmationFail: afterConfirmationFail))
        
    }
    

	 struct __StubbingProxy_AccountConfirmViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountConfirmViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountConfirmViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.ProtocolStubNoReturnFunction<([String], Bool)> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmViewProtocol.self, method: "didReceive(words: [String], afterConfirmationFail: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.__DoNotUse<([String], Bool), Void> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(words: [String], afterConfirmationFail: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmViewProtocolStub: AccountConfirmViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReceive(words: [String], afterConfirmationFail: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmPresenterProtocol: AccountConfirmPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmPresenterProtocol
     typealias Verification = __VerificationProxy_AccountConfirmPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func requestWords()  {
        
    return cuckoo_manager.call("requestWords()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestWords())
        
    }
    
    
    
     func confirm(words: [String])  {
        
    return cuckoo_manager.call("confirm(words: [String])",
            parameters: (words),
            escapingParameters: (words),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(words: words))
        
    }
    
    
    
     func skip()  {
        
    return cuckoo_manager.call("skip()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.skip())
        
    }
    

	 struct __StubbingProxy_AccountConfirmPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func requestWords() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "requestWords()", parameterMatchers: matchers))
	    }
	    
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "confirm(words: [String])", parameterMatchers: matchers))
	    }
	    
	    func skip() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "skip()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func requestWords() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("requestWords()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return cuckoo_manager.verify("confirm(words: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func skip() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("skip()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmPresenterProtocolStub: AccountConfirmPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func requestWords()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func confirm(words: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func skip()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmInteractorInputProtocol: AccountConfirmInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountConfirmInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func requestWords()  {
        
    return cuckoo_manager.call("requestWords()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestWords())
        
    }
    
    
    
     func confirm(words: [String])  {
        
    return cuckoo_manager.call("confirm(words: [String])",
            parameters: (words),
            escapingParameters: (words),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(words: words))
        
    }
    
    
    
     func skipConfirmation()  {
        
    return cuckoo_manager.call("skipConfirmation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.skipConfirmation())
        
    }
    

	 struct __StubbingProxy_AccountConfirmInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func requestWords() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "requestWords()", parameterMatchers: matchers))
	    }
	    
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "confirm(words: [String])", parameterMatchers: matchers))
	    }
	    
	    func skipConfirmation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "skipConfirmation()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func requestWords() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("requestWords()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return cuckoo_manager.verify("confirm(words: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func skipConfirmation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("skipConfirmation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmInteractorInputProtocolStub: AccountConfirmInteractorInputProtocol {
    

    

    
     func requestWords()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func confirm(words: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func skipConfirmation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmInteractorOutputProtocol: AccountConfirmInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountConfirmInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(words: [String], afterConfirmationFail: Bool)  {
        
    return cuckoo_manager.call("didReceive(words: [String], afterConfirmationFail: Bool)",
            parameters: (words, afterConfirmationFail),
            escapingParameters: (words, afterConfirmationFail),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(words: words, afterConfirmationFail: afterConfirmationFail))
        
    }
    
    
    
     func didCompleteConfirmation()  {
        
    return cuckoo_manager.call("didCompleteConfirmation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteConfirmation())
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_AccountConfirmInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.ProtocolStubNoReturnFunction<([String], Bool)> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didReceive(words: [String], afterConfirmationFail: Bool)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteConfirmation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didCompleteConfirmation()", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.__DoNotUse<([String], Bool), Void> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(words: [String], afterConfirmationFail: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteConfirmation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteConfirmation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmInteractorOutputProtocolStub: AccountConfirmInteractorOutputProtocol {
    

    

    
     func didReceive(words: [String], afterConfirmationFail: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteConfirmation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmWireframeProtocol: AccountConfirmWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmWireframeProtocol
     typealias Verification = __VerificationProxy_AccountConfirmWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: AccountConfirmViewProtocol?)  {
        
    return cuckoo_manager.call("proceed(from: AccountConfirmViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountConfirmWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountConfirmViewProtocol?)> where M1.OptionalMatchedType == AccountConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "proceed(from: AccountConfirmViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountConfirmViewProtocol?), Void> where M1.OptionalMatchedType == AccountConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("proceed(from: AccountConfirmViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmWireframeProtocolStub: AccountConfirmWireframeProtocol {
    

    

    
     func proceed(from view: AccountConfirmViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto
import SoraFoundation


 class MockAccountCreateViewProtocol: AccountCreateViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateViewProtocol
     typealias Verification = __VerificationProxy_AccountCreateViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateViewProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(mnemonic: [String])  {
        
    return cuckoo_manager.call("set(mnemonic: [String])",
            parameters: (mnemonic),
            escapingParameters: (mnemonic),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(mnemonic: mnemonic))
        
    }
    
    
    
     func setSelectedCrypto(model: TitleWithSubtitleViewModel)  {
        
    return cuckoo_manager.call("setSelectedCrypto(model: TitleWithSubtitleViewModel)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedCrypto(model: model))
        
    }
    
    
    
     func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)  {
        
    return cuckoo_manager.call("setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedNetwork(model: model))
        
    }
    
    
    
     func setDerivationPath(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setDerivationPath(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setDerivationPath(viewModel: viewModel))
        
    }
    
    
    
     func didCompleteCryptoTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteCryptoTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteCryptoTypeSelection())
        
    }
    
    
    
     func didCompleteNetworkTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteNetworkTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteNetworkTypeSelection())
        
    }
    
    
    
     func didValidateDerivationPath(_ status: FieldStatus)  {
        
    return cuckoo_manager.call("didValidateDerivationPath(_: FieldStatus)",
            parameters: (status),
            escapingParameters: (status),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didValidateDerivationPath(status))
        
    }
    

	 struct __StubbingProxy_AccountCreateViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "set(mnemonic: [String])", parameterMatchers: matchers))
	    }
	    
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TitleWithSubtitleViewModel)> where M1.MatchedType == TitleWithSubtitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(TitleWithSubtitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setSelectedCrypto(model: TitleWithSubtitleViewModel)", parameterMatchers: matchers))
	    }
	    
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectableViewModel<IconWithTitleViewModel>)> where M1.MatchedType == SelectableViewModel<IconWithTitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<IconWithTitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)", parameterMatchers: matchers))
	    }
	    
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setDerivationPath(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteCryptoTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didCompleteCryptoTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteNetworkTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didCompleteNetworkTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FieldStatus)> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didValidateDerivationPath(_: FieldStatus)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return cuckoo_manager.verify("set(mnemonic: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(TitleWithSubtitleViewModel), Void> where M1.MatchedType == TitleWithSubtitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(TitleWithSubtitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedCrypto(model: TitleWithSubtitleViewModel)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(SelectableViewModel<IconWithTitleViewModel>), Void> where M1.MatchedType == SelectableViewModel<IconWithTitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<IconWithTitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setDerivationPath(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteCryptoTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteCryptoTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteNetworkTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteNetworkTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.__DoNotUse<(FieldStatus), Void> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return cuckoo_manager.verify("didValidateDerivationPath(_: FieldStatus)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateViewProtocolStub: AccountCreateViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(mnemonic: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedCrypto(model: TitleWithSubtitleViewModel)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setDerivationPath(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteCryptoTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteNetworkTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didValidateDerivationPath(_ status: FieldStatus)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreatePresenterProtocol: AccountCreatePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreatePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreatePresenterProtocol
     typealias Verification = __VerificationProxy_AccountCreatePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreatePresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountCreatePresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func selectCryptoType()  {
        
    return cuckoo_manager.call("selectCryptoType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectCryptoType())
        
    }
    
    
    
     func selectNetworkType()  {
        
    return cuckoo_manager.call("selectNetworkType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectNetworkType())
        
    }
    
    
    
     func activateInfo()  {
        
    return cuckoo_manager.call("activateInfo()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateInfo())
        
    }
    
    
    
     func validate()  {
        
    return cuckoo_manager.call("validate()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.validate())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_AccountCreatePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func selectCryptoType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "selectCryptoType()", parameterMatchers: matchers))
	    }
	    
	    func selectNetworkType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "selectNetworkType()", parameterMatchers: matchers))
	    }
	    
	    func activateInfo() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "activateInfo()", parameterMatchers: matchers))
	    }
	    
	    func validate() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "validate()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreatePresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectCryptoType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectCryptoType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectNetworkType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectNetworkType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateInfo() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateInfo()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func validate() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("validate()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreatePresenterProtocolStub: AccountCreatePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectCryptoType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectNetworkType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateInfo()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func validate()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorInputProtocol: AccountCreateInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_AccountCreateInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateInteractorInputProtocolStub: AccountCreateInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorOutputProtocol: AccountCreateInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(metadata: AccountCreationMetadata)  {
        
    return cuckoo_manager.call("didReceive(metadata: AccountCreationMetadata)",
            parameters: (metadata),
            escapingParameters: (metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(metadata: metadata))
        
    }
    
    
    
     func didReceiveMnemonicGeneration(error: Error)  {
        
    return cuckoo_manager.call("didReceiveMnemonicGeneration(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveMnemonicGeneration(error: error))
        
    }
    

	 struct __StubbingProxy_AccountCreateInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreationMetadata)> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceive(metadata: AccountCreationMetadata)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceiveMnemonicGeneration(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.__DoNotUse<(AccountCreationMetadata), Void> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return cuckoo_manager.verify("didReceive(metadata: AccountCreationMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveMnemonicGeneration(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateInteractorOutputProtocolStub: AccountCreateInteractorOutputProtocol {
    

    

    
     func didReceive(metadata: AccountCreationMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveMnemonicGeneration(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateWireframeProtocol: AccountCreateWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateWireframeProtocol
     typealias Verification = __VerificationProxy_AccountCreateWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func confirm(from view: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)  {
        
    return cuckoo_manager.call("confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)",
            parameters: (view, request, metadata),
            escapingParameters: (view, request, metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(from: view, request: request, metadata: metadata))
        
    }
    
    
    
     func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentCryptoTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentNetworkTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountCreateWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func confirm<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, request: M2, metadata: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == AccountCreationRequest, M3.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: request) { $0.1 }, wrap(matchable: metadata) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)", parameterMatchers: matchers))
	    }
	    
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [Chain], M3.MatchedType == Chain, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, request: M2, metadata: M3) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == AccountCreationRequest, M3.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: request) { $0.1 }, wrap(matchable: metadata) { $0.2 }]
	        return cuckoo_manager.verify("confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [Chain], M3.MatchedType == Chain, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateWireframeProtocolStub: AccountCreateWireframeProtocol {
    

    

    
     func confirm(from view: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto
import SoraFoundation


 class MockAccountImportViewProtocol: AccountImportViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportViewProtocol
     typealias Verification = __VerificationProxy_AccountImportViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportViewProtocol?

     func enableDefaultImplementation(_ stub: AccountImportViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func setSource(type: AccountImportSource)  {
        
    return cuckoo_manager.call("setSource(type: AccountImportSource)",
            parameters: (type),
            escapingParameters: (type),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSource(type: type))
        
    }
    
    
    
     func setSource(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setSource(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSource(viewModel: viewModel))
        
    }
    
    
    
     func setName(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setName(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setName(viewModel: viewModel))
        
    }
    
    
    
     func setPassword(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setPassword(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setPassword(viewModel: viewModel))
        
    }
    
    
    
     func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)  {
        
    return cuckoo_manager.call("setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedCrypto(model: model))
        
    }
    
    
    
     func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)  {
        
    return cuckoo_manager.call("setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedNetwork(model: model))
        
    }
    
    
    
     func setDerivationPath(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setDerivationPath(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setDerivationPath(viewModel: viewModel))
        
    }
    
    
    
     func setUploadWarning(message: String)  {
        
    return cuckoo_manager.call("setUploadWarning(message: String)",
            parameters: (message),
            escapingParameters: (message),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setUploadWarning(message: message))
        
    }
    
    
    
     func didCompleteSourceTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteSourceTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteSourceTypeSelection())
        
    }
    
    
    
     func didCompleteCryptoTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteCryptoTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteCryptoTypeSelection())
        
    }
    
    
    
     func didCompleteAddressTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteAddressTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteAddressTypeSelection())
        
    }
    
    
    
     func didValidateDerivationPath(_ status: FieldStatus)  {
        
    return cuckoo_manager.call("didValidateDerivationPath(_: FieldStatus)",
            parameters: (status),
            escapingParameters: (status),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didValidateDerivationPath(status))
        
    }
    

	 struct __StubbingProxy_AccountImportViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountImportViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountImportViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func setSource<M1: Cuckoo.Matchable>(type: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportSource)> where M1.MatchedType == AccountImportSource {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSource)>] = [wrap(matchable: type) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSource(type: AccountImportSource)", parameterMatchers: matchers))
	    }
	    
	    func setSource<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSource(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setName<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setName(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setPassword<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setPassword(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectableViewModel<TitleWithSubtitleViewModel>)> where M1.MatchedType == SelectableViewModel<TitleWithSubtitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<TitleWithSubtitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)", parameterMatchers: matchers))
	    }
	    
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectableViewModel<IconWithTitleViewModel>)> where M1.MatchedType == SelectableViewModel<IconWithTitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<IconWithTitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)", parameterMatchers: matchers))
	    }
	    
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setDerivationPath(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setUploadWarning<M1: Cuckoo.Matchable>(message: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: message) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setUploadWarning(message: String)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteSourceTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "didCompleteSourceTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteCryptoTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "didCompleteCryptoTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteAddressTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "didCompleteAddressTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FieldStatus)> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "didValidateDerivationPath(_: FieldStatus)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setSource<M1: Cuckoo.Matchable>(type: M1) -> Cuckoo.__DoNotUse<(AccountImportSource), Void> where M1.MatchedType == AccountImportSource {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSource)>] = [wrap(matchable: type) { $0 }]
	        return cuckoo_manager.verify("setSource(type: AccountImportSource)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSource<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setSource(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setName<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setName(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setPassword<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setPassword(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(SelectableViewModel<TitleWithSubtitleViewModel>), Void> where M1.MatchedType == SelectableViewModel<TitleWithSubtitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<TitleWithSubtitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(SelectableViewModel<IconWithTitleViewModel>), Void> where M1.MatchedType == SelectableViewModel<IconWithTitleViewModel> {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectableViewModel<IconWithTitleViewModel>)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setDerivationPath(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setUploadWarning<M1: Cuckoo.Matchable>(message: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: message) { $0 }]
	        return cuckoo_manager.verify("setUploadWarning(message: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteSourceTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteSourceTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteCryptoTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteCryptoTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteAddressTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteAddressTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.__DoNotUse<(FieldStatus), Void> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return cuckoo_manager.verify("didValidateDerivationPath(_: FieldStatus)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportViewProtocolStub: AccountImportViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func setSource(type: AccountImportSource)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSource(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setName(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setPassword(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setDerivationPath(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setUploadWarning(message: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteSourceTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteCryptoTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteAddressTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didValidateDerivationPath(_ status: FieldStatus)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportPresenterProtocol: AccountImportPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportPresenterProtocol
     typealias Verification = __VerificationProxy_AccountImportPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountImportPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func selectSourceType()  {
        
    return cuckoo_manager.call("selectSourceType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectSourceType())
        
    }
    
    
    
     func selectCryptoType()  {
        
    return cuckoo_manager.call("selectCryptoType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectCryptoType())
        
    }
    
    
    
     func selectNetworkType()  {
        
    return cuckoo_manager.call("selectNetworkType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectNetworkType())
        
    }
    
    
    
     func activateUpload()  {
        
    return cuckoo_manager.call("activateUpload()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateUpload())
        
    }
    
    
    
     func validateDerivationPath()  {
        
    return cuckoo_manager.call("validateDerivationPath()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.validateDerivationPath())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_AccountImportPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func selectSourceType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "selectSourceType()", parameterMatchers: matchers))
	    }
	    
	    func selectCryptoType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "selectCryptoType()", parameterMatchers: matchers))
	    }
	    
	    func selectNetworkType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "selectNetworkType()", parameterMatchers: matchers))
	    }
	    
	    func activateUpload() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "activateUpload()", parameterMatchers: matchers))
	    }
	    
	    func validateDerivationPath() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "validateDerivationPath()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectSourceType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectSourceType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectCryptoType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectCryptoType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectNetworkType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectNetworkType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateUpload() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateUpload()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func validateDerivationPath() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("validateDerivationPath()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportPresenterProtocolStub: AccountImportPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectSourceType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectCryptoType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectNetworkType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateUpload()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func validateDerivationPath()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportInteractorInputProtocol: AccountImportInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountImportInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountImportInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func importAccountWithMnemonic(request: AccountImportMnemonicRequest)  {
        
    return cuckoo_manager.call("importAccountWithMnemonic(request: AccountImportMnemonicRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithMnemonic(request: request))
        
    }
    
    
    
     func importAccountWithSeed(request: AccountImportSeedRequest)  {
        
    return cuckoo_manager.call("importAccountWithSeed(request: AccountImportSeedRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithSeed(request: request))
        
    }
    
    
    
     func importAccountWithKeystore(request: AccountImportKeystoreRequest)  {
        
    return cuckoo_manager.call("importAccountWithKeystore(request: AccountImportKeystoreRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithKeystore(request: request))
        
    }
    
    
    
     func deriveMetadataFromKeystore(_ keystore: String)  {
        
    return cuckoo_manager.call("deriveMetadataFromKeystore(_: String)",
            parameters: (keystore),
            escapingParameters: (keystore),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.deriveMetadataFromKeystore(keystore))
        
    }
    

	 struct __StubbingProxy_AccountImportInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithMnemonic<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportMnemonicRequest)> where M1.MatchedType == AccountImportMnemonicRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMnemonicRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithMnemonic(request: AccountImportMnemonicRequest)", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithSeed<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportSeedRequest)> where M1.MatchedType == AccountImportSeedRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSeedRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithSeed(request: AccountImportSeedRequest)", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithKeystore<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportKeystoreRequest)> where M1.MatchedType == AccountImportKeystoreRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportKeystoreRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithKeystore(request: AccountImportKeystoreRequest)", parameterMatchers: matchers))
	    }
	    
	    func deriveMetadataFromKeystore<M1: Cuckoo.Matchable>(_ keystore: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: keystore) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "deriveMetadataFromKeystore(_: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func importAccountWithMnemonic<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportMnemonicRequest), Void> where M1.MatchedType == AccountImportMnemonicRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMnemonicRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithMnemonic(request: AccountImportMnemonicRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func importAccountWithSeed<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportSeedRequest), Void> where M1.MatchedType == AccountImportSeedRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSeedRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithSeed(request: AccountImportSeedRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func importAccountWithKeystore<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportKeystoreRequest), Void> where M1.MatchedType == AccountImportKeystoreRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportKeystoreRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithKeystore(request: AccountImportKeystoreRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func deriveMetadataFromKeystore<M1: Cuckoo.Matchable>(_ keystore: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: keystore) { $0 }]
	        return cuckoo_manager.verify("deriveMetadataFromKeystore(_: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportInteractorInputProtocolStub: AccountImportInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithMnemonic(request: AccountImportMnemonicRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithSeed(request: AccountImportSeedRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithKeystore(request: AccountImportKeystoreRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func deriveMetadataFromKeystore(_ keystore: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportInteractorOutputProtocol: AccountImportInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountImportInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountImportInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceiveAccountImport(metadata: AccountImportMetadata)  {
        
    return cuckoo_manager.call("didReceiveAccountImport(metadata: AccountImportMetadata)",
            parameters: (metadata),
            escapingParameters: (metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveAccountImport(metadata: metadata))
        
    }
    
    
    
     func didCompleteAccountImport()  {
        
    return cuckoo_manager.call("didCompleteAccountImport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteAccountImport())
        
    }
    
    
    
     func didReceiveAccountImport(error: Error)  {
        
    return cuckoo_manager.call("didReceiveAccountImport(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveAccountImport(error: error))
        
    }
    
    
    
     func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)  {
        
    return cuckoo_manager.call("didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)",
            parameters: (text, preferredInfo),
            escapingParameters: (text, preferredInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSuggestKeystore(text: text, preferredInfo: preferredInfo))
        
    }
    

	 struct __StubbingProxy_AccountImportInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportMetadata)> where M1.MatchedType == AccountImportMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didReceiveAccountImport(metadata: AccountImportMetadata)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteAccountImport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didCompleteAccountImport()", parameterMatchers: matchers))
	    }
	    
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didReceiveAccountImport(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didSuggestKeystore<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(text: M1, preferredInfo: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(String, AccountImportPreferredInfo?)> where M1.MatchedType == String, M2.OptionalMatchedType == AccountImportPreferredInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, AccountImportPreferredInfo?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: preferredInfo) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.__DoNotUse<(AccountImportMetadata), Void> where M1.MatchedType == AccountImportMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return cuckoo_manager.verify("didReceiveAccountImport(metadata: AccountImportMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteAccountImport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteAccountImport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveAccountImport(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didSuggestKeystore<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(text: M1, preferredInfo: M2) -> Cuckoo.__DoNotUse<(String, AccountImportPreferredInfo?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == AccountImportPreferredInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, AccountImportPreferredInfo?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: preferredInfo) { $0.1 }]
	        return cuckoo_manager.verify("didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportInteractorOutputProtocolStub: AccountImportInteractorOutputProtocol {
    

    

    
     func didReceiveAccountImport(metadata: AccountImportMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteAccountImport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveAccountImport(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportWireframeProtocol: AccountImportWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportWireframeProtocol
     typealias Verification = __VerificationProxy_AccountImportWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountImportWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: AccountImportViewProtocol?)  {
        
    return cuckoo_manager.call("proceed(from: AccountImportViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view))
        
    }
    
    
    
     func presentSourceTypeSelection(from view: AccountImportViewProtocol?, availableSources: [AccountImportSource], selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentSourceTypeSelection(from: AccountImportViewProtocol?, availableSources: [AccountImportSource], selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableSources, selectedSource, delegate, context),
            escapingParameters: (view, availableSources, selectedSource, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentSourceTypeSelection(from: view, availableSources: availableSources, selectedSource: selectedSource, delegate: delegate, context: context))
        
    }
    
    
    
     func presentCryptoTypeSelection(from view: AccountImportViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentCryptoTypeSelection(from: AccountImportViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentCryptoTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func presentNetworkTypeSelection(from view: AccountImportViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentNetworkTypeSelection(from: AccountImportViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentNetworkTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountImportWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportViewProtocol?)> where M1.OptionalMatchedType == AccountImportViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "proceed(from: AccountImportViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentSourceTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableSources: M2, selectedSource: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportViewProtocol?, [AccountImportSource], AccountImportSource, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [AccountImportSource], M3.MatchedType == AccountImportSource, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [AccountImportSource], AccountImportSource, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableSources) { $0.1 }, wrap(matchable: selectedSource) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "presentSourceTypeSelection(from: AccountImportViewProtocol?, availableSources: [AccountImportSource], selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "presentCryptoTypeSelection(from: AccountImportViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [Chain], M3.MatchedType == Chain, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "presentNetworkTypeSelection(from: AccountImportViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountImportViewProtocol?), Void> where M1.OptionalMatchedType == AccountImportViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("proceed(from: AccountImportViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentSourceTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableSources: M2, selectedSource: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountImportViewProtocol?, [AccountImportSource], AccountImportSource, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [AccountImportSource], M3.MatchedType == AccountImportSource, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [AccountImportSource], AccountImportSource, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableSources) { $0.1 }, wrap(matchable: selectedSource) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentSourceTypeSelection(from: AccountImportViewProtocol?, availableSources: [AccountImportSource], selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountImportViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentCryptoTypeSelection(from: AccountImportViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountImportViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountImportViewProtocol, M2.MatchedType == [Chain], M3.MatchedType == Chain, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?, [Chain], Chain, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentNetworkTypeSelection(from: AccountImportViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportWireframeProtocolStub: AccountImportWireframeProtocol {
    

    

    
     func proceed(from view: AccountImportViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentSourceTypeSelection(from view: AccountImportViewProtocol?, availableSources: [AccountImportSource], selectedSource: AccountImportSource, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentCryptoTypeSelection(from view: AccountImportViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentNetworkTypeSelection(from view: AccountImportViewProtocol?, availableTypes: [Chain], selectedType: Chain, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto
import SoraFoundation


 class MockAccountInfoViewProtocol: AccountInfoViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountInfoViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountInfoViewProtocol
     typealias Verification = __VerificationProxy_AccountInfoViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountInfoViewProtocol?

     func enableDefaultImplementation(_ stub: AccountInfoViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(usernameViewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(usernameViewModel: InputViewModelProtocol)",
            parameters: (usernameViewModel),
            escapingParameters: (usernameViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(usernameViewModel: usernameViewModel))
        
    }
    
    
    
     func set(address: String)  {
        
    return cuckoo_manager.call("set(address: String)",
            parameters: (address),
            escapingParameters: (address),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(address: address))
        
    }
    
    
    
     func set(networkType: Chain)  {
        
    return cuckoo_manager.call("set(networkType: Chain)",
            parameters: (networkType),
            escapingParameters: (networkType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(networkType: networkType))
        
    }
    
    
    
     func set(cryptoType: CryptoType)  {
        
    return cuckoo_manager.call("set(cryptoType: CryptoType)",
            parameters: (cryptoType),
            escapingParameters: (cryptoType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(cryptoType: cryptoType))
        
    }
    

	 struct __StubbingProxy_AccountInfoViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountInfoViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountInfoViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(usernameViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: usernameViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoViewProtocol.self, method: "set(usernameViewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoViewProtocol.self, method: "set(address: String)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(networkType: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Chain)> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: networkType) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoViewProtocol.self, method: "set(networkType: Chain)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(cryptoType: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(CryptoType)> where M1.MatchedType == CryptoType {
	        let matchers: [Cuckoo.ParameterMatcher<(CryptoType)>] = [wrap(matchable: cryptoType) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoViewProtocol.self, method: "set(cryptoType: CryptoType)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountInfoViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(usernameViewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: usernameViewModel) { $0 }]
	        return cuckoo_manager.verify("set(usernameViewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return cuckoo_manager.verify("set(address: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(networkType: M1) -> Cuckoo.__DoNotUse<(Chain), Void> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: networkType) { $0 }]
	        return cuckoo_manager.verify("set(networkType: Chain)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(cryptoType: M1) -> Cuckoo.__DoNotUse<(CryptoType), Void> where M1.MatchedType == CryptoType {
	        let matchers: [Cuckoo.ParameterMatcher<(CryptoType)>] = [wrap(matchable: cryptoType) { $0 }]
	        return cuckoo_manager.verify("set(cryptoType: CryptoType)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountInfoViewProtocolStub: AccountInfoViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(usernameViewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(address: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(networkType: Chain)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(cryptoType: CryptoType)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountInfoPresenterProtocol: AccountInfoPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountInfoPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountInfoPresenterProtocol
     typealias Verification = __VerificationProxy_AccountInfoPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountInfoPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountInfoPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func activateClose()  {
        
    return cuckoo_manager.call("activateClose()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateClose())
        
    }
    
    
    
     func activateExport()  {
        
    return cuckoo_manager.call("activateExport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateExport())
        
    }
    
    
    
     func activateAddressAction()  {
        
    return cuckoo_manager.call("activateAddressAction()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAddressAction())
        
    }
    
    
    
     func finalizeUsername()  {
        
    return cuckoo_manager.call("finalizeUsername()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.finalizeUsername())
        
    }
    

	 struct __StubbingProxy_AccountInfoPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateClose() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoPresenterProtocol.self, method: "activateClose()", parameterMatchers: matchers))
	    }
	    
	    func activateExport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoPresenterProtocol.self, method: "activateExport()", parameterMatchers: matchers))
	    }
	    
	    func activateAddressAction() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoPresenterProtocol.self, method: "activateAddressAction()", parameterMatchers: matchers))
	    }
	    
	    func finalizeUsername() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoPresenterProtocol.self, method: "finalizeUsername()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountInfoPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateClose() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateClose()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateExport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateExport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAddressAction() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAddressAction()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func finalizeUsername() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("finalizeUsername()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountInfoPresenterProtocolStub: AccountInfoPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateClose()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateExport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAddressAction()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func finalizeUsername()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountInfoInteractorInputProtocol: AccountInfoInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountInfoInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountInfoInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountInfoInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountInfoInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountInfoInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup(address: String)  {
        
    return cuckoo_manager.call("setup(address: String)",
            parameters: (address),
            escapingParameters: (address),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup(address: address))
        
    }
    
    
    
     func save(username: String, address: String)  {
        
    return cuckoo_manager.call("save(username: String, address: String)",
            parameters: (username, address),
            escapingParameters: (username, address),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save(username: username, address: address))
        
    }
    
    
    
     func requestExportOptions(accountItem: ManagedAccountItem)  {
        
    return cuckoo_manager.call("requestExportOptions(accountItem: ManagedAccountItem)",
            parameters: (accountItem),
            escapingParameters: (accountItem),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestExportOptions(accountItem: accountItem))
        
    }
    
    
    
     func flushPendingUsername()  {
        
    return cuckoo_manager.call("flushPendingUsername()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.flushPendingUsername())
        
    }
    

	 struct __StubbingProxy_AccountInfoInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorInputProtocol.self, method: "setup(address: String)", parameterMatchers: matchers))
	    }
	    
	    func save<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(username: M1, address: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(String, String)> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: username) { $0.0 }, wrap(matchable: address) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorInputProtocol.self, method: "save(username: String, address: String)", parameterMatchers: matchers))
	    }
	    
	    func requestExportOptions<M1: Cuckoo.Matchable>(accountItem: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedAccountItem)> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: accountItem) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorInputProtocol.self, method: "requestExportOptions(accountItem: ManagedAccountItem)", parameterMatchers: matchers))
	    }
	    
	    func flushPendingUsername() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorInputProtocol.self, method: "flushPendingUsername()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountInfoInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return cuckoo_manager.verify("setup(address: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func save<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(username: M1, address: M2) -> Cuckoo.__DoNotUse<(String, String), Void> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: username) { $0.0 }, wrap(matchable: address) { $0.1 }]
	        return cuckoo_manager.verify("save(username: String, address: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func requestExportOptions<M1: Cuckoo.Matchable>(accountItem: M1) -> Cuckoo.__DoNotUse<(ManagedAccountItem), Void> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: accountItem) { $0 }]
	        return cuckoo_manager.verify("requestExportOptions(accountItem: ManagedAccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func flushPendingUsername() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("flushPendingUsername()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountInfoInteractorInputProtocolStub: AccountInfoInteractorInputProtocol {
    

    

    
     func setup(address: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func save(username: String, address: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func requestExportOptions(accountItem: ManagedAccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func flushPendingUsername()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountInfoInteractorOutputProtocol: AccountInfoInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountInfoInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountInfoInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountInfoInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountInfoInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountInfoInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(exportOptions: [ExportOption])  {
        
    return cuckoo_manager.call("didReceive(exportOptions: [ExportOption])",
            parameters: (exportOptions),
            escapingParameters: (exportOptions),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(exportOptions: exportOptions))
        
    }
    
    
    
     func didReceive(accountItem: ManagedAccountItem)  {
        
    return cuckoo_manager.call("didReceive(accountItem: ManagedAccountItem)",
            parameters: (accountItem),
            escapingParameters: (accountItem),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(accountItem: accountItem))
        
    }
    
    
    
     func didSave(username: String)  {
        
    return cuckoo_manager.call("didSave(username: String)",
            parameters: (username),
            escapingParameters: (username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSave(username: username))
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_AccountInfoInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(exportOptions: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ExportOption])> where M1.MatchedType == [ExportOption] {
	        let matchers: [Cuckoo.ParameterMatcher<([ExportOption])>] = [wrap(matchable: exportOptions) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorOutputProtocol.self, method: "didReceive(exportOptions: [ExportOption])", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(accountItem: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedAccountItem)> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: accountItem) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorOutputProtocol.self, method: "didReceive(accountItem: ManagedAccountItem)", parameterMatchers: matchers))
	    }
	    
	    func didSave<M1: Cuckoo.Matchable>(username: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: username) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorOutputProtocol.self, method: "didSave(username: String)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountInfoInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(exportOptions: M1) -> Cuckoo.__DoNotUse<([ExportOption]), Void> where M1.MatchedType == [ExportOption] {
	        let matchers: [Cuckoo.ParameterMatcher<([ExportOption])>] = [wrap(matchable: exportOptions) { $0 }]
	        return cuckoo_manager.verify("didReceive(exportOptions: [ExportOption])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(accountItem: M1) -> Cuckoo.__DoNotUse<(ManagedAccountItem), Void> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: accountItem) { $0 }]
	        return cuckoo_manager.verify("didReceive(accountItem: ManagedAccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didSave<M1: Cuckoo.Matchable>(username: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: username) { $0 }]
	        return cuckoo_manager.verify("didSave(username: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountInfoInteractorOutputProtocolStub: AccountInfoInteractorOutputProtocol {
    

    

    
     func didReceive(exportOptions: [ExportOption])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(accountItem: ManagedAccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didSave(username: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountInfoWireframeProtocol: AccountInfoWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountInfoWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountInfoWireframeProtocol
     typealias Verification = __VerificationProxy_AccountInfoWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountInfoWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountInfoWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: AccountInfoViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: AccountInfoViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func showExport(for address: String, options: [ExportOption], locale: Locale?, from view: AccountInfoViewProtocol?)  {
        
    return cuckoo_manager.call("showExport(for: String, options: [ExportOption], locale: Locale?, from: AccountInfoViewProtocol?)",
            parameters: (address, options, locale, view),
            escapingParameters: (address, options, locale, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showExport(for: address, options: options, locale: locale, from: view))
        
    }
    
    
    
     func presentAddressOptions(_ address: String, chain: Chain, locale: Locale, copyClosure: @escaping () -> Void, from view: AccountInfoViewProtocol?)  {
        
    return cuckoo_manager.call("presentAddressOptions(_: String, chain: Chain, locale: Locale, copyClosure: @escaping () -> Void, from: AccountInfoViewProtocol?)",
            parameters: (address, chain, locale, copyClosure, view),
            escapingParameters: (address, chain, locale, copyClosure, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAddressOptions(address, chain: chain, locale: locale, copyClosure: copyClosure, from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)  {
        
    return cuckoo_manager.call("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)",
            parameters: (title, view, closure),
            escapingParameters: (title, view, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentSuccessNotification(title, from: view, completion: closure))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_AccountInfoWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountInfoViewProtocol?)> where M1.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountInfoViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "close(view: AccountInfoViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showExport<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for address: M1, options: M2, locale: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String, [ExportOption], Locale?, AccountInfoViewProtocol?)> where M1.MatchedType == String, M2.MatchedType == [ExportOption], M3.OptionalMatchedType == Locale, M4.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String, [ExportOption], Locale?, AccountInfoViewProtocol?)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: options) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "showExport(for: String, options: [ExportOption], locale: Locale?, from: AccountInfoViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentAddressOptions<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.OptionalMatchable>(_ address: M1, chain: M2, locale: M3, copyClosure: M4, from view: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(String, Chain, Locale, () -> Void, AccountInfoViewProtocol?)> where M1.MatchedType == String, M2.MatchedType == Chain, M3.MatchedType == Locale, M4.MatchedType == () -> Void, M5.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String, Chain, Locale, () -> Void, AccountInfoViewProtocol?)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: chain) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: copyClosure) { $0.3 }, wrap(matchable: view) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "presentAddressOptions(_: String, chain: Chain, locale: Locale, copyClosure: @escaping () -> Void, from: AccountInfoViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ControllerBackedProtocol?, (() -> Void)?)> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountInfoWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountInfoWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(AccountInfoViewProtocol?), Void> where M1.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountInfoViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: AccountInfoViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showExport<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for address: M1, options: M2, locale: M3, from view: M4) -> Cuckoo.__DoNotUse<(String, [ExportOption], Locale?, AccountInfoViewProtocol?), Void> where M1.MatchedType == String, M2.MatchedType == [ExportOption], M3.OptionalMatchedType == Locale, M4.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String, [ExportOption], Locale?, AccountInfoViewProtocol?)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: options) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("showExport(for: String, options: [ExportOption], locale: Locale?, from: AccountInfoViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentAddressOptions<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.OptionalMatchable>(_ address: M1, chain: M2, locale: M3, copyClosure: M4, from view: M5) -> Cuckoo.__DoNotUse<(String, Chain, Locale, () -> Void, AccountInfoViewProtocol?), Void> where M1.MatchedType == String, M2.MatchedType == Chain, M3.MatchedType == Locale, M4.MatchedType == () -> Void, M5.OptionalMatchedType == AccountInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String, Chain, Locale, () -> Void, AccountInfoViewProtocol?)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: chain) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: copyClosure) { $0.3 }, wrap(matchable: view) { $0.4 }]
	        return cuckoo_manager.verify("presentAddressOptions(_: String, chain: Chain, locale: Locale, copyClosure: @escaping () -> Void, from: AccountInfoViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(String, ControllerBackedProtocol?, (() -> Void)?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountInfoWireframeProtocolStub: AccountInfoWireframeProtocol {
    

    

    
     func close(view: AccountInfoViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showExport(for address: String, options: [ExportOption], locale: Locale?, from view: AccountInfoViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentAddressOptions(_ address: String, chain: Chain, locale: Locale, copyClosure: @escaping () -> Void, from view: AccountInfoViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import RobinHood


 class MockAccountManagementViewProtocol: AccountManagementViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountManagementViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountManagementViewProtocol
     typealias Verification = __VerificationProxy_AccountManagementViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountManagementViewProtocol?

     func enableDefaultImplementation(_ stub: AccountManagementViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func reload()  {
        
    return cuckoo_manager.call("reload()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reload())
        
    }
    
    
    
     func didRemoveItem(at index: Int, in section: Int)  {
        
    return cuckoo_manager.call("didRemoveItem(at: Int, in: Int)",
            parameters: (index, section),
            escapingParameters: (index, section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRemoveItem(at: index, in: section))
        
    }
    
    
    
     func didRemoveSection(at section: Int)  {
        
    return cuckoo_manager.call("didRemoveSection(at: Int)",
            parameters: (section),
            escapingParameters: (section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRemoveSection(at: section))
        
    }
    

	 struct __StubbingProxy_AccountManagementViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountManagementViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountManagementViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func reload() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementViewProtocol.self, method: "reload()", parameterMatchers: matchers))
	    }
	    
	    func didRemoveItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementViewProtocol.self, method: "didRemoveItem(at: Int, in: Int)", parameterMatchers: matchers))
	    }
	    
	    func didRemoveSection<M1: Cuckoo.Matchable>(at section: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: section) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementViewProtocol.self, method: "didRemoveSection(at: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountManagementViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func reload() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("reload()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRemoveItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.__DoNotUse<(Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return cuckoo_manager.verify("didRemoveItem(at: Int, in: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRemoveSection<M1: Cuckoo.Matchable>(at section: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: section) { $0 }]
	        return cuckoo_manager.verify("didRemoveSection(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountManagementViewProtocolStub: AccountManagementViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func reload()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRemoveItem(at index: Int, in section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRemoveSection(at section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountManagementPresenterProtocol: AccountManagementPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountManagementPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountManagementPresenterProtocol
     typealias Verification = __VerificationProxy_AccountManagementPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountManagementPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountManagementPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func numberOfSections() -> Int {
        
    return cuckoo_manager.call("numberOfSections() -> Int",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.numberOfSections())
        
    }
    
    
    
     func section(at index: Int) -> ManagedAccountViewModelSection {
        
    return cuckoo_manager.call("section(at: Int) -> ManagedAccountViewModelSection",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.section(at: index))
        
    }
    
    
    
     func activateDetails(at index: Int, in section: Int)  {
        
    return cuckoo_manager.call("activateDetails(at: Int, in: Int)",
            parameters: (index, section),
            escapingParameters: (index, section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateDetails(at: index, in: section))
        
    }
    
    
    
     func activateAddAccount()  {
        
    return cuckoo_manager.call("activateAddAccount()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAddAccount())
        
    }
    
    
    
     func selectItem(at index: Int, in section: Int)  {
        
    return cuckoo_manager.call("selectItem(at: Int, in: Int)",
            parameters: (index, section),
            escapingParameters: (index, section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectItem(at: index, in: section))
        
    }
    
    
    
     func moveItem(at startIndex: Int, to finalIndex: Int, in section: Int)  {
        
    return cuckoo_manager.call("moveItem(at: Int, to: Int, in: Int)",
            parameters: (startIndex, finalIndex, section),
            escapingParameters: (startIndex, finalIndex, section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.moveItem(at: startIndex, to: finalIndex, in: section))
        
    }
    
    
    
     func removeItem(at index: Int, in section: Int)  {
        
    return cuckoo_manager.call("removeItem(at: Int, in: Int)",
            parameters: (index, section),
            escapingParameters: (index, section),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeItem(at: index, in: section))
        
    }
    
    
    
     func removeSection(at index: Int)  {
        
    return cuckoo_manager.call("removeSection(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeSection(at: index))
        
    }
    

	 struct __StubbingProxy_AccountManagementPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func numberOfSections() -> Cuckoo.ProtocolStubFunction<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "numberOfSections() -> Int", parameterMatchers: matchers))
	    }
	    
	    func section<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubFunction<(Int), ManagedAccountViewModelSection> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "section(at: Int) -> ManagedAccountViewModelSection", parameterMatchers: matchers))
	    }
	    
	    func activateDetails<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "activateDetails(at: Int, in: Int)", parameterMatchers: matchers))
	    }
	    
	    func activateAddAccount() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "activateAddAccount()", parameterMatchers: matchers))
	    }
	    
	    func selectItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "selectItem(at: Int, in: Int)", parameterMatchers: matchers))
	    }
	    
	    func moveItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(at startIndex: M1, to finalIndex: M2, in section: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int, M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int, Int)>] = [wrap(matchable: startIndex) { $0.0 }, wrap(matchable: finalIndex) { $0.1 }, wrap(matchable: section) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "moveItem(at: Int, to: Int, in: Int)", parameterMatchers: matchers))
	    }
	    
	    func removeItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "removeItem(at: Int, in: Int)", parameterMatchers: matchers))
	    }
	    
	    func removeSection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementPresenterProtocol.self, method: "removeSection(at: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountManagementPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func numberOfSections() -> Cuckoo.__DoNotUse<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("numberOfSections() -> Int", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func section<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), ManagedAccountViewModelSection> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("section(at: Int) -> ManagedAccountViewModelSection", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateDetails<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.__DoNotUse<(Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return cuckoo_manager.verify("activateDetails(at: Int, in: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAddAccount() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAddAccount()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.__DoNotUse<(Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return cuckoo_manager.verify("selectItem(at: Int, in: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func moveItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(at startIndex: M1, to finalIndex: M2, in section: M3) -> Cuckoo.__DoNotUse<(Int, Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int, M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int, Int)>] = [wrap(matchable: startIndex) { $0.0 }, wrap(matchable: finalIndex) { $0.1 }, wrap(matchable: section) { $0.2 }]
	        return cuckoo_manager.verify("moveItem(at: Int, to: Int, in: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at index: M1, in section: M2) -> Cuckoo.__DoNotUse<(Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: index) { $0.0 }, wrap(matchable: section) { $0.1 }]
	        return cuckoo_manager.verify("removeItem(at: Int, in: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeSection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("removeSection(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountManagementPresenterProtocolStub: AccountManagementPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func numberOfSections() -> Int  {
        return DefaultValueRegistry.defaultValue(for: (Int).self)
    }
    
     func section(at index: Int) -> ManagedAccountViewModelSection  {
        return DefaultValueRegistry.defaultValue(for: (ManagedAccountViewModelSection).self)
    }
    
     func activateDetails(at index: Int, in section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAddAccount()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectItem(at index: Int, in section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func moveItem(at startIndex: Int, to finalIndex: Int, in section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func removeItem(at index: Int, in section: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func removeSection(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountManagementInteractorInputProtocol: AccountManagementInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountManagementInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountManagementInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountManagementInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountManagementInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountManagementInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func select(item: ManagedAccountItem)  {
        
    return cuckoo_manager.call("select(item: ManagedAccountItem)",
            parameters: (item),
            escapingParameters: (item),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.select(item: item))
        
    }
    
    
    
     func save(items: [ManagedAccountItem])  {
        
    return cuckoo_manager.call("save(items: [ManagedAccountItem])",
            parameters: (items),
            escapingParameters: (items),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save(items: items))
        
    }
    
    
    
     func remove(item: ManagedAccountItem)  {
        
    return cuckoo_manager.call("remove(item: ManagedAccountItem)",
            parameters: (item),
            escapingParameters: (item),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(item: item))
        
    }
    

	 struct __StubbingProxy_AccountManagementInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func select<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedAccountItem)> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: item) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorInputProtocol.self, method: "select(item: ManagedAccountItem)", parameterMatchers: matchers))
	    }
	    
	    func save<M1: Cuckoo.Matchable>(items: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ManagedAccountItem])> where M1.MatchedType == [ManagedAccountItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ManagedAccountItem])>] = [wrap(matchable: items) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorInputProtocol.self, method: "save(items: [ManagedAccountItem])", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedAccountItem)> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: item) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorInputProtocol.self, method: "remove(item: ManagedAccountItem)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountManagementInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func select<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.__DoNotUse<(ManagedAccountItem), Void> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: item) { $0 }]
	        return cuckoo_manager.verify("select(item: ManagedAccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func save<M1: Cuckoo.Matchable>(items: M1) -> Cuckoo.__DoNotUse<([ManagedAccountItem]), Void> where M1.MatchedType == [ManagedAccountItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ManagedAccountItem])>] = [wrap(matchable: items) { $0 }]
	        return cuckoo_manager.verify("save(items: [ManagedAccountItem])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.__DoNotUse<(ManagedAccountItem), Void> where M1.MatchedType == ManagedAccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem)>] = [wrap(matchable: item) { $0 }]
	        return cuckoo_manager.verify("remove(item: ManagedAccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountManagementInteractorInputProtocolStub: AccountManagementInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func select(item: ManagedAccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func save(items: [ManagedAccountItem])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func remove(item: ManagedAccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountManagementInteractorOutputProtocol: AccountManagementInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountManagementInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountManagementInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountManagementInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountManagementInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountManagementInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceiveSelected(item: AccountItem)  {
        
    return cuckoo_manager.call("didReceiveSelected(item: AccountItem)",
            parameters: (item),
            escapingParameters: (item),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveSelected(item: item))
        
    }
    
    
    
     func didReceive(changes: [DataProviderChange<ManagedAccountItem>])  {
        
    return cuckoo_manager.call("didReceive(changes: [DataProviderChange<ManagedAccountItem>])",
            parameters: (changes),
            escapingParameters: (changes),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(changes: changes))
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_AccountManagementInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceiveSelected<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountItem)> where M1.MatchedType == AccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem)>] = [wrap(matchable: item) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorOutputProtocol.self, method: "didReceiveSelected(item: AccountItem)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(changes: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([DataProviderChange<ManagedAccountItem>])> where M1.MatchedType == [DataProviderChange<ManagedAccountItem>] {
	        let matchers: [Cuckoo.ParameterMatcher<([DataProviderChange<ManagedAccountItem>])>] = [wrap(matchable: changes) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorOutputProtocol.self, method: "didReceive(changes: [DataProviderChange<ManagedAccountItem>])", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountManagementInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceiveSelected<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.__DoNotUse<(AccountItem), Void> where M1.MatchedType == AccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem)>] = [wrap(matchable: item) { $0 }]
	        return cuckoo_manager.verify("didReceiveSelected(item: AccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(changes: M1) -> Cuckoo.__DoNotUse<([DataProviderChange<ManagedAccountItem>]), Void> where M1.MatchedType == [DataProviderChange<ManagedAccountItem>] {
	        let matchers: [Cuckoo.ParameterMatcher<([DataProviderChange<ManagedAccountItem>])>] = [wrap(matchable: changes) { $0 }]
	        return cuckoo_manager.verify("didReceive(changes: [DataProviderChange<ManagedAccountItem>])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountManagementInteractorOutputProtocolStub: AccountManagementInteractorOutputProtocol {
    

    

    
     func didReceiveSelected(item: AccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(changes: [DataProviderChange<ManagedAccountItem>])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountManagementWireframeProtocol: AccountManagementWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountManagementWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountManagementWireframeProtocol
     typealias Verification = __VerificationProxy_AccountManagementWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountManagementWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountManagementWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountDetails(_: ManagedAccountItem, from: AccountManagementViewProtocol?)",
            parameters: (account, view),
            escapingParameters: (account, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountDetails(account, from: view))
        
    }
    
    
    
     func showAddAccount(from view: AccountManagementViewProtocol?)  {
        
    return cuckoo_manager.call("showAddAccount(from: AccountManagementViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAddAccount(from: view))
        
    }
    
    
    
     func complete(from view: AccountManagementViewProtocol?)  {
        
    return cuckoo_manager.call("complete(from: AccountManagementViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.complete(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountManagementWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showAccountDetails<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ account: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedAccountItem, AccountManagementViewProtocol?)> where M1.MatchedType == ManagedAccountItem, M2.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem, AccountManagementViewProtocol?)>] = [wrap(matchable: account) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementWireframeProtocol.self, method: "showAccountDetails(_: ManagedAccountItem, from: AccountManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAddAccount<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountManagementViewProtocol?)> where M1.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementWireframeProtocol.self, method: "showAddAccount(from: AccountManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountManagementViewProtocol?)> where M1.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementWireframeProtocol.self, method: "complete(from: AccountManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountManagementWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountManagementWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showAccountDetails<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ account: M1, from view: M2) -> Cuckoo.__DoNotUse<(ManagedAccountItem, AccountManagementViewProtocol?), Void> where M1.MatchedType == ManagedAccountItem, M2.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedAccountItem, AccountManagementViewProtocol?)>] = [wrap(matchable: account) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("showAccountDetails(_: ManagedAccountItem, from: AccountManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAddAccount<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountManagementViewProtocol?), Void> where M1.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAddAccount(from: AccountManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountManagementViewProtocol?), Void> where M1.OptionalMatchedType == AccountManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("complete(from: AccountManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountManagementWireframeProtocolStub: AccountManagementWireframeProtocol {
    

    

    
     func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAddAccount(from view: AccountManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func complete(from view: AccountManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SoraFoundation


 class MockAddConnectionViewProtocol: AddConnectionViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AddConnectionViewProtocol
    
     typealias Stubbing = __StubbingProxy_AddConnectionViewProtocol
     typealias Verification = __VerificationProxy_AddConnectionViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AddConnectionViewProtocol?

     func enableDefaultImplementation(_ stub: AddConnectionViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func set(nameViewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(nameViewModel: InputViewModelProtocol)",
            parameters: (nameViewModel),
            escapingParameters: (nameViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(nameViewModel: nameViewModel))
        
    }
    
    
    
     func set(nodeViewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(nodeViewModel: InputViewModelProtocol)",
            parameters: (nodeViewModel),
            escapingParameters: (nodeViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(nodeViewModel: nodeViewModel))
        
    }
    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_AddConnectionViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAddConnectionViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAddConnectionViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAddConnectionViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAddConnectionViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(nameViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nameViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionViewProtocol.self, method: "set(nameViewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(nodeViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nodeViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionViewProtocol.self, method: "set(nodeViewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AddConnectionViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(nameViewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nameViewModel) { $0 }]
	        return cuckoo_manager.verify("set(nameViewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(nodeViewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nodeViewModel) { $0 }]
	        return cuckoo_manager.verify("set(nodeViewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AddConnectionViewProtocolStub: AddConnectionViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func set(nameViewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(nodeViewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAddConnectionPresenterProtocol: AddConnectionPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AddConnectionPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AddConnectionPresenterProtocol
     typealias Verification = __VerificationProxy_AddConnectionPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AddConnectionPresenterProtocol?

     func enableDefaultImplementation(_ stub: AddConnectionPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func add()  {
        
    return cuckoo_manager.call("add()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add())
        
    }
    

	 struct __StubbingProxy_AddConnectionPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func add() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionPresenterProtocol.self, method: "add()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AddConnectionPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func add() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("add()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AddConnectionPresenterProtocolStub: AddConnectionPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func add()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAddConnectionInteractorInputProtocol: AddConnectionInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AddConnectionInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AddConnectionInteractorInputProtocol
     typealias Verification = __VerificationProxy_AddConnectionInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AddConnectionInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AddConnectionInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func addConnection(url: URL, name: String)  {
        
    return cuckoo_manager.call("addConnection(url: URL, name: String)",
            parameters: (url, name),
            escapingParameters: (url, name),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addConnection(url: url, name: name))
        
    }
    

	 struct __StubbingProxy_AddConnectionInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func addConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(url: M1, name: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, String)> where M1.MatchedType == URL, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, String)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: name) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionInteractorInputProtocol.self, method: "addConnection(url: URL, name: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AddConnectionInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func addConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(url: M1, name: M2) -> Cuckoo.__DoNotUse<(URL, String), Void> where M1.MatchedType == URL, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, String)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: name) { $0.1 }]
	        return cuckoo_manager.verify("addConnection(url: URL, name: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AddConnectionInteractorInputProtocolStub: AddConnectionInteractorInputProtocol {
    

    

    
     func addConnection(url: URL, name: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAddConnectionInteractorOutputProtocol: AddConnectionInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AddConnectionInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AddConnectionInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AddConnectionInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AddConnectionInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AddConnectionInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didStartAdding(url: URL)  {
        
    return cuckoo_manager.call("didStartAdding(url: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartAdding(url: url))
        
    }
    
    
    
     func didCompleteAdding(url: URL)  {
        
    return cuckoo_manager.call("didCompleteAdding(url: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteAdding(url: url))
        
    }
    
    
    
     func didReceiveError(error: Error, for url: URL)  {
        
    return cuckoo_manager.call("didReceiveError(error: Error, for: URL)",
            parameters: (error, url),
            escapingParameters: (error, url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveError(error: error, for: url))
        
    }
    

	 struct __StubbingProxy_AddConnectionInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didStartAdding<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionInteractorOutputProtocol.self, method: "didStartAdding(url: URL)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteAdding<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionInteractorOutputProtocol.self, method: "didCompleteAdding(url: URL)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveError<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for url: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, URL)> where M1.MatchedType == Error, M2.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, URL)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: url) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionInteractorOutputProtocol.self, method: "didReceiveError(error: Error, for: URL)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AddConnectionInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didStartAdding<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("didStartAdding(url: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteAdding<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("didCompleteAdding(url: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveError<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for url: M2) -> Cuckoo.__DoNotUse<(Error, URL), Void> where M1.MatchedType == Error, M2.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, URL)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: url) { $0.1 }]
	        return cuckoo_manager.verify("didReceiveError(error: Error, for: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AddConnectionInteractorOutputProtocolStub: AddConnectionInteractorOutputProtocol {
    

    

    
     func didStartAdding(url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteAdding(url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveError(error: Error, for url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAddConnectionWireframeProtocol: AddConnectionWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AddConnectionWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AddConnectionWireframeProtocol
     typealias Verification = __VerificationProxy_AddConnectionWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AddConnectionWireframeProtocol?

     func enableDefaultImplementation(_ stub: AddConnectionWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: AddConnectionViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: AddConnectionViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AddConnectionWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AddConnectionViewProtocol?)> where M1.OptionalMatchedType == AddConnectionViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AddConnectionViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionWireframeProtocol.self, method: "close(view: AddConnectionViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAddConnectionWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AddConnectionWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(AddConnectionViewProtocol?), Void> where M1.OptionalMatchedType == AddConnectionViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AddConnectionViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: AddConnectionViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AddConnectionWireframeProtocolStub: AddConnectionWireframeProtocol {
    

    

    
     func close(view: AddConnectionViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SoraFoundation


 class MockAccountExportPasswordViewProtocol: AccountExportPasswordViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountExportPasswordViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountExportPasswordViewProtocol
     typealias Verification = __VerificationProxy_AccountExportPasswordViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountExportPasswordViewProtocol?

     func enableDefaultImplementation(_ stub: AccountExportPasswordViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setPasswordInputViewModel(_: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setPasswordInputViewModel(viewModel))
        
    }
    
    
    
     func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setPasswordConfirmationViewModel(_: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setPasswordConfirmationViewModel(viewModel))
        
    }
    
    
    
     func set(error: AccountExportPasswordError)  {
        
    return cuckoo_manager.call("set(error: AccountExportPasswordError)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(error: error))
        
    }
    

	 struct __StubbingProxy_AccountExportPasswordViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountExportPasswordViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountExportPasswordViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func setPasswordInputViewModel<M1: Cuckoo.Matchable>(_ viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordViewProtocol.self, method: "setPasswordInputViewModel(_: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setPasswordConfirmationViewModel<M1: Cuckoo.Matchable>(_ viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordViewProtocol.self, method: "setPasswordConfirmationViewModel(_: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountExportPasswordError)> where M1.MatchedType == AccountExportPasswordError {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountExportPasswordError)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordViewProtocol.self, method: "set(error: AccountExportPasswordError)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountExportPasswordViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setPasswordInputViewModel<M1: Cuckoo.Matchable>(_ viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setPasswordInputViewModel(_: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setPasswordConfirmationViewModel<M1: Cuckoo.Matchable>(_ viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setPasswordConfirmationViewModel(_: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(AccountExportPasswordError), Void> where M1.MatchedType == AccountExportPasswordError {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountExportPasswordError)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("set(error: AccountExportPasswordError)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountExportPasswordViewProtocolStub: AccountExportPasswordViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(error: AccountExportPasswordError)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountExportPasswordPresenterProtocol: AccountExportPasswordPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountExportPasswordPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountExportPasswordPresenterProtocol
     typealias Verification = __VerificationProxy_AccountExportPasswordPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountExportPasswordPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountExportPasswordPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_AccountExportPasswordPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountExportPasswordPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountExportPasswordPresenterProtocolStub: AccountExportPasswordPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountExportPasswordInteractorInputProtocol: AccountExportPasswordInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountExportPasswordInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountExportPasswordInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountExportPasswordInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountExportPasswordInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountExportPasswordInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func exportAccount(address: String, password: String)  {
        
    return cuckoo_manager.call("exportAccount(address: String, password: String)",
            parameters: (address, password),
            escapingParameters: (address, password),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.exportAccount(address: address, password: password))
        
    }
    

	 struct __StubbingProxy_AccountExportPasswordInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func exportAccount<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(address: M1, password: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(String, String)> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: password) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordInteractorInputProtocol.self, method: "exportAccount(address: String, password: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountExportPasswordInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func exportAccount<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(address: M1, password: M2) -> Cuckoo.__DoNotUse<(String, String), Void> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: address) { $0.0 }, wrap(matchable: password) { $0.1 }]
	        return cuckoo_manager.verify("exportAccount(address: String, password: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountExportPasswordInteractorInputProtocolStub: AccountExportPasswordInteractorInputProtocol {
    

    

    
     func exportAccount(address: String, password: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountExportPasswordInteractorOutputProtocol: AccountExportPasswordInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountExportPasswordInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountExportPasswordInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountExportPasswordInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountExportPasswordInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountExportPasswordInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didExport(json: RestoreJson)  {
        
    return cuckoo_manager.call("didExport(json: RestoreJson)",
            parameters: (json),
            escapingParameters: (json),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didExport(json: json))
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_AccountExportPasswordInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didExport<M1: Cuckoo.Matchable>(json: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RestoreJson)> where M1.MatchedType == RestoreJson {
	        let matchers: [Cuckoo.ParameterMatcher<(RestoreJson)>] = [wrap(matchable: json) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordInteractorOutputProtocol.self, method: "didExport(json: RestoreJson)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountExportPasswordInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didExport<M1: Cuckoo.Matchable>(json: M1) -> Cuckoo.__DoNotUse<(RestoreJson), Void> where M1.MatchedType == RestoreJson {
	        let matchers: [Cuckoo.ParameterMatcher<(RestoreJson)>] = [wrap(matchable: json) { $0 }]
	        return cuckoo_manager.verify("didExport(json: RestoreJson)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountExportPasswordInteractorOutputProtocolStub: AccountExportPasswordInteractorOutputProtocol {
    

    

    
     func didExport(json: RestoreJson)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountExportPasswordWireframeProtocol: AccountExportPasswordWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountExportPasswordWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountExportPasswordWireframeProtocol
     typealias Verification = __VerificationProxy_AccountExportPasswordWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountExportPasswordWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountExportPasswordWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showJSONExport(_ json: RestoreJson, from view: AccountExportPasswordViewProtocol?)  {
        
    return cuckoo_manager.call("showJSONExport(_: RestoreJson, from: AccountExportPasswordViewProtocol?)",
            parameters: (json, view),
            escapingParameters: (json, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showJSONExport(json, from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountExportPasswordWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showJSONExport<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ json: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RestoreJson, AccountExportPasswordViewProtocol?)> where M1.MatchedType == RestoreJson, M2.OptionalMatchedType == AccountExportPasswordViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RestoreJson, AccountExportPasswordViewProtocol?)>] = [wrap(matchable: json) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordWireframeProtocol.self, method: "showJSONExport(_: RestoreJson, from: AccountExportPasswordViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountExportPasswordWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountExportPasswordWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showJSONExport<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ json: M1, from view: M2) -> Cuckoo.__DoNotUse<(RestoreJson, AccountExportPasswordViewProtocol?), Void> where M1.MatchedType == RestoreJson, M2.OptionalMatchedType == AccountExportPasswordViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RestoreJson, AccountExportPasswordViewProtocol?)>] = [wrap(matchable: json) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("showJSONExport(_: RestoreJson, from: AccountExportPasswordViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountExportPasswordWireframeProtocolStub: AccountExportPasswordWireframeProtocol {
    

    

    
     func showJSONExport(_ json: RestoreJson, from view: AccountExportPasswordViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SoraFoundation


 class MockExportGenericViewProtocol: ExportGenericViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportGenericViewProtocol
    
     typealias Stubbing = __StubbingProxy_ExportGenericViewProtocol
     typealias Verification = __VerificationProxy_ExportGenericViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportGenericViewProtocol?

     func enableDefaultImplementation(_ stub: ExportGenericViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(viewModel: ExportGenericViewModelProtocol)  {
        
    return cuckoo_manager.call("set(viewModel: ExportGenericViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(viewModel: viewModel))
        
    }
    

	 struct __StubbingProxy_ExportGenericViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockExportGenericViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockExportGenericViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportGenericViewModelProtocol)> where M1.MatchedType == ExportGenericViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericViewProtocol.self, method: "set(viewModel: ExportGenericViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportGenericViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(ExportGenericViewModelProtocol), Void> where M1.MatchedType == ExportGenericViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("set(viewModel: ExportGenericViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportGenericViewProtocolStub: ExportGenericViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(viewModel: ExportGenericViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockExportGenericPresenterProtocol: ExportGenericPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportGenericPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_ExportGenericPresenterProtocol
     typealias Verification = __VerificationProxy_ExportGenericPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportGenericPresenterProtocol?

     func enableDefaultImplementation(_ stub: ExportGenericPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func activateExport()  {
        
    return cuckoo_manager.call("activateExport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateExport())
        
    }
    
    
    
     func activateAccessoryOption()  {
        
    return cuckoo_manager.call("activateAccessoryOption()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAccessoryOption())
        
    }
    

	 struct __StubbingProxy_ExportGenericPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateExport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericPresenterProtocol.self, method: "activateExport()", parameterMatchers: matchers))
	    }
	    
	    func activateAccessoryOption() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericPresenterProtocol.self, method: "activateAccessoryOption()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportGenericPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateExport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateExport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAccessoryOption() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAccessoryOption()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportGenericPresenterProtocolStub: ExportGenericPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateExport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAccessoryOption()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockExportGenericWireframeProtocol: ExportGenericWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportGenericWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ExportGenericWireframeProtocol
     typealias Verification = __VerificationProxy_ExportGenericWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportGenericWireframeProtocol?

     func enableDefaultImplementation(_ stub: ExportGenericWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: ExportGenericViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: ExportGenericViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    

	 struct __StubbingProxy_ExportGenericWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportGenericViewProtocol?)> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericWireframeProtocol.self, method: "close(view: ExportGenericViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportGenericWireframeProtocol.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportGenericWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(ExportGenericViewProtocol?), Void> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: ExportGenericViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportGenericWireframeProtocolStub: ExportGenericWireframeProtocol {
    

    

    
     func close(view: ExportGenericViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto


 class MockExportMnemonicInteractorInputProtocol: ExportMnemonicInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportMnemonicInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_ExportMnemonicInteractorInputProtocol
     typealias Verification = __VerificationProxy_ExportMnemonicInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportMnemonicInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: ExportMnemonicInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchExportDataForAddress(_ address: String)  {
        
    return cuckoo_manager.call("fetchExportDataForAddress(_: String)",
            parameters: (address),
            escapingParameters: (address),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchExportDataForAddress(address))
        
    }
    

	 struct __StubbingProxy_ExportMnemonicInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchExportDataForAddress<M1: Cuckoo.Matchable>(_ address: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicInteractorInputProtocol.self, method: "fetchExportDataForAddress(_: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportMnemonicInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchExportDataForAddress<M1: Cuckoo.Matchable>(_ address: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
	        return cuckoo_manager.verify("fetchExportDataForAddress(_: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportMnemonicInteractorInputProtocolStub: ExportMnemonicInteractorInputProtocol {
    

    

    
     func fetchExportDataForAddress(_ address: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockExportMnemonicInteractorOutputProtocol: ExportMnemonicInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportMnemonicInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_ExportMnemonicInteractorOutputProtocol
     typealias Verification = __VerificationProxy_ExportMnemonicInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportMnemonicInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: ExportMnemonicInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(exportData: ExportMnemonicData)  {
        
    return cuckoo_manager.call("didReceive(exportData: ExportMnemonicData)",
            parameters: (exportData),
            escapingParameters: (exportData),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(exportData: exportData))
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_ExportMnemonicInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(exportData: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportMnemonicData)> where M1.MatchedType == ExportMnemonicData {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportMnemonicData)>] = [wrap(matchable: exportData) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicInteractorOutputProtocol.self, method: "didReceive(exportData: ExportMnemonicData)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportMnemonicInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(exportData: M1) -> Cuckoo.__DoNotUse<(ExportMnemonicData), Void> where M1.MatchedType == ExportMnemonicData {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportMnemonicData)>] = [wrap(matchable: exportData) { $0 }]
	        return cuckoo_manager.verify("didReceive(exportData: ExportMnemonicData)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportMnemonicInteractorOutputProtocolStub: ExportMnemonicInteractorOutputProtocol {
    

    

    
     func didReceive(exportData: ExportMnemonicData)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockExportMnemonicWireframeProtocol: ExportMnemonicWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportMnemonicWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ExportMnemonicWireframeProtocol
     typealias Verification = __VerificationProxy_ExportMnemonicWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportMnemonicWireframeProtocol?

     func enableDefaultImplementation(_ stub: ExportMnemonicWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: ExportGenericViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: ExportGenericViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ExportGenericViewProtocol?)  {
        
    return cuckoo_manager.call("openConfirmationForMnemonic(_: IRMnemonicProtocol, from: ExportGenericViewProtocol?)",
            parameters: (mnemonic, view),
            escapingParameters: (mnemonic, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.openConfirmationForMnemonic(mnemonic, from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    

	 struct __StubbingProxy_ExportMnemonicWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportGenericViewProtocol?)> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicWireframeProtocol.self, method: "close(view: ExportGenericViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func openConfirmationForMnemonic<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ mnemonic: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(IRMnemonicProtocol, ExportGenericViewProtocol?)> where M1.MatchedType == IRMnemonicProtocol, M2.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(IRMnemonicProtocol, ExportGenericViewProtocol?)>] = [wrap(matchable: mnemonic) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicWireframeProtocol.self, method: "openConfirmationForMnemonic(_: IRMnemonicProtocol, from: ExportGenericViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportMnemonicWireframeProtocol.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportMnemonicWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(ExportGenericViewProtocol?), Void> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: ExportGenericViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func openConfirmationForMnemonic<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(_ mnemonic: M1, from view: M2) -> Cuckoo.__DoNotUse<(IRMnemonicProtocol, ExportGenericViewProtocol?), Void> where M1.MatchedType == IRMnemonicProtocol, M2.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(IRMnemonicProtocol, ExportGenericViewProtocol?)>] = [wrap(matchable: mnemonic) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("openConfirmationForMnemonic(_: IRMnemonicProtocol, from: ExportGenericViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportMnemonicWireframeProtocolStub: ExportMnemonicWireframeProtocol {
    

    

    
     func close(view: ExportGenericViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ExportGenericViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation


 class MockExportRestoreJsonWireframeProtocol: ExportRestoreJsonWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ExportRestoreJsonWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ExportRestoreJsonWireframeProtocol
     typealias Verification = __VerificationProxy_ExportRestoreJsonWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ExportRestoreJsonWireframeProtocol?

     func enableDefaultImplementation(_ stub: ExportRestoreJsonWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: ExportGenericViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: ExportGenericViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func showChangePassword(from view: ExportGenericViewProtocol?)  {
        
    return cuckoo_manager.call("showChangePassword(from: ExportGenericViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showChangePassword(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    

	 struct __StubbingProxy_ExportRestoreJsonWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportGenericViewProtocol?)> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportRestoreJsonWireframeProtocol.self, method: "close(view: ExportGenericViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showChangePassword<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ExportGenericViewProtocol?)> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportRestoreJsonWireframeProtocol.self, method: "showChangePassword(from: ExportGenericViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportRestoreJsonWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportRestoreJsonWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockExportRestoreJsonWireframeProtocol.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ExportRestoreJsonWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(ExportGenericViewProtocol?), Void> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: ExportGenericViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showChangePassword<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ExportGenericViewProtocol?), Void> where M1.OptionalMatchedType == ExportGenericViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ExportGenericViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showChangePassword(from: ExportGenericViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ExportRestoreJsonWireframeProtocolStub: ExportRestoreJsonWireframeProtocol {
    

    

    
     func close(view: ExportGenericViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showChangePassword(from view: ExportGenericViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import SoraFoundation


 class MockNetworkInfoViewProtocol: NetworkInfoViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkInfoViewProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkInfoViewProtocol
     typealias Verification = __VerificationProxy_NetworkInfoViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkInfoViewProtocol?

     func enableDefaultImplementation(_ stub: NetworkInfoViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func set(nameViewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(nameViewModel: InputViewModelProtocol)",
            parameters: (nameViewModel),
            escapingParameters: (nameViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(nameViewModel: nameViewModel))
        
    }
    
    
    
     func set(nodeViewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(nodeViewModel: InputViewModelProtocol)",
            parameters: (nodeViewModel),
            escapingParameters: (nodeViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(nodeViewModel: nodeViewModel))
        
    }
    
    
    
     func set(networkType: Chain)  {
        
    return cuckoo_manager.call("set(networkType: Chain)",
            parameters: (networkType),
            escapingParameters: (networkType),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(networkType: networkType))
        
    }
    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_NetworkInfoViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkInfoViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkInfoViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkInfoViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkInfoViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(nameViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nameViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoViewProtocol.self, method: "set(nameViewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(nodeViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nodeViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoViewProtocol.self, method: "set(nodeViewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func set<M1: Cuckoo.Matchable>(networkType: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Chain)> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: networkType) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoViewProtocol.self, method: "set(networkType: Chain)", parameterMatchers: matchers))
	    }
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkInfoViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(nameViewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nameViewModel) { $0 }]
	        return cuckoo_manager.verify("set(nameViewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(nodeViewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: nodeViewModel) { $0 }]
	        return cuckoo_manager.verify("set(nodeViewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(networkType: M1) -> Cuckoo.__DoNotUse<(Chain), Void> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: networkType) { $0 }]
	        return cuckoo_manager.verify("set(networkType: Chain)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkInfoViewProtocolStub: NetworkInfoViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func set(nameViewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(nodeViewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func set(networkType: Chain)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkInfoPresenterProtocol: NetworkInfoPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkInfoPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkInfoPresenterProtocol
     typealias Verification = __VerificationProxy_NetworkInfoPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkInfoPresenterProtocol?

     func enableDefaultImplementation(_ stub: NetworkInfoPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func activateCopy()  {
        
    return cuckoo_manager.call("activateCopy()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateCopy())
        
    }
    
    
    
     func activateClose()  {
        
    return cuckoo_manager.call("activateClose()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateClose())
        
    }
    
    
    
     func activateUpdate()  {
        
    return cuckoo_manager.call("activateUpdate()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateUpdate())
        
    }
    

	 struct __StubbingProxy_NetworkInfoPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateCopy() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoPresenterProtocol.self, method: "activateCopy()", parameterMatchers: matchers))
	    }
	    
	    func activateClose() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoPresenterProtocol.self, method: "activateClose()", parameterMatchers: matchers))
	    }
	    
	    func activateUpdate() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoPresenterProtocol.self, method: "activateUpdate()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkInfoPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateCopy() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateCopy()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateClose() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateClose()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateUpdate() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateUpdate()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkInfoPresenterProtocolStub: NetworkInfoPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateCopy()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateClose()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateUpdate()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkInfoInteractorInputProtocol: NetworkInfoInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkInfoInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkInfoInteractorInputProtocol
     typealias Verification = __VerificationProxy_NetworkInfoInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkInfoInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: NetworkInfoInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func updateConnection(_ oldConnection: ConnectionItem, newURL: URL, newName: String)  {
        
    return cuckoo_manager.call("updateConnection(_: ConnectionItem, newURL: URL, newName: String)",
            parameters: (oldConnection, newURL, newName),
            escapingParameters: (oldConnection, newURL, newName),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateConnection(oldConnection, newURL: newURL, newName: newName))
        
    }
    

	 struct __StubbingProxy_NetworkInfoInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func updateConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ oldConnection: M1, newURL: M2, newName: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem, URL, String)> where M1.MatchedType == ConnectionItem, M2.MatchedType == URL, M3.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, URL, String)>] = [wrap(matchable: oldConnection) { $0.0 }, wrap(matchable: newURL) { $0.1 }, wrap(matchable: newName) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoInteractorInputProtocol.self, method: "updateConnection(_: ConnectionItem, newURL: URL, newName: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkInfoInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func updateConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ oldConnection: M1, newURL: M2, newName: M3) -> Cuckoo.__DoNotUse<(ConnectionItem, URL, String), Void> where M1.MatchedType == ConnectionItem, M2.MatchedType == URL, M3.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, URL, String)>] = [wrap(matchable: oldConnection) { $0.0 }, wrap(matchable: newURL) { $0.1 }, wrap(matchable: newName) { $0.2 }]
	        return cuckoo_manager.verify("updateConnection(_: ConnectionItem, newURL: URL, newName: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkInfoInteractorInputProtocolStub: NetworkInfoInteractorInputProtocol {
    

    

    
     func updateConnection(_ oldConnection: ConnectionItem, newURL: URL, newName: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkInfoInteractorOutputProtocol: NetworkInfoInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkInfoInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkInfoInteractorOutputProtocol
     typealias Verification = __VerificationProxy_NetworkInfoInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkInfoInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: NetworkInfoInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didStartConnectionUpdate(with url: URL)  {
        
    return cuckoo_manager.call("didStartConnectionUpdate(with: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartConnectionUpdate(with: url))
        
    }
    
    
    
     func didCompleteConnectionUpdate(with url: URL)  {
        
    return cuckoo_manager.call("didCompleteConnectionUpdate(with: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteConnectionUpdate(with: url))
        
    }
    
    
    
     func didReceive(error: Error, for url: URL)  {
        
    return cuckoo_manager.call("didReceive(error: Error, for: URL)",
            parameters: (error, url),
            escapingParameters: (error, url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error, for: url))
        
    }
    

	 struct __StubbingProxy_NetworkInfoInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didStartConnectionUpdate<M1: Cuckoo.Matchable>(with url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoInteractorOutputProtocol.self, method: "didStartConnectionUpdate(with: URL)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteConnectionUpdate<M1: Cuckoo.Matchable>(with url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoInteractorOutputProtocol.self, method: "didCompleteConnectionUpdate(with: URL)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for url: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, URL)> where M1.MatchedType == Error, M2.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, URL)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: url) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoInteractorOutputProtocol.self, method: "didReceive(error: Error, for: URL)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkInfoInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didStartConnectionUpdate<M1: Cuckoo.Matchable>(with url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("didStartConnectionUpdate(with: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteConnectionUpdate<M1: Cuckoo.Matchable>(with url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("didCompleteConnectionUpdate(with: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for url: M2) -> Cuckoo.__DoNotUse<(Error, URL), Void> where M1.MatchedType == Error, M2.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, URL)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: url) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(error: Error, for: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkInfoInteractorOutputProtocolStub: NetworkInfoInteractorOutputProtocol {
    

    

    
     func didStartConnectionUpdate(with url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteConnectionUpdate(with url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error, for url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkInfoWireframeProtocol: NetworkInfoWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkInfoWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkInfoWireframeProtocol
     typealias Verification = __VerificationProxy_NetworkInfoWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkInfoWireframeProtocol?

     func enableDefaultImplementation(_ stub: NetworkInfoWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: NetworkInfoViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: NetworkInfoViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)  {
        
    return cuckoo_manager.call("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)",
            parameters: (title, view, closure),
            escapingParameters: (title, view, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentSuccessNotification(title, from: view, completion: closure))
        
    }
    

	 struct __StubbingProxy_NetworkInfoWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(NetworkInfoViewProtocol?)> where M1.OptionalMatchedType == NetworkInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkInfoViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoWireframeProtocol.self, method: "close(view: NetworkInfoViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ControllerBackedProtocol?, (() -> Void)?)> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkInfoWireframeProtocol.self, method: "presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkInfoWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(NetworkInfoViewProtocol?), Void> where M1.OptionalMatchedType == NetworkInfoViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkInfoViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: NetworkInfoViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(String, ControllerBackedProtocol?, (() -> Void)?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkInfoWireframeProtocolStub: NetworkInfoWireframeProtocol {
    

    

    
     func close(view: NetworkInfoViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto
import RobinHood


 class MockNetworkManagementViewProtocol: NetworkManagementViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkManagementViewProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkManagementViewProtocol
     typealias Verification = __VerificationProxy_NetworkManagementViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkManagementViewProtocol?

     func enableDefaultImplementation(_ stub: NetworkManagementViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func reload()  {
        
    return cuckoo_manager.call("reload()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reload())
        
    }
    
    
    
     func didRemoveCustomItem(at index: Int)  {
        
    return cuckoo_manager.call("didRemoveCustomItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRemoveCustomItem(at: index))
        
    }
    

	 struct __StubbingProxy_NetworkManagementViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkManagementViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockNetworkManagementViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func reload() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementViewProtocol.self, method: "reload()", parameterMatchers: matchers))
	    }
	    
	    func didRemoveCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementViewProtocol.self, method: "didRemoveCustomItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkManagementViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func reload() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("reload()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRemoveCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("didRemoveCustomItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkManagementViewProtocolStub: NetworkManagementViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func reload()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRemoveCustomItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkManagementPresenterProtocol: NetworkManagementPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkManagementPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkManagementPresenterProtocol
     typealias Verification = __VerificationProxy_NetworkManagementPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkManagementPresenterProtocol?

     func enableDefaultImplementation(_ stub: NetworkManagementPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func activateConnectionAdd()  {
        
    return cuckoo_manager.call("activateConnectionAdd()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateConnectionAdd())
        
    }
    
    
    
     func activateDefaultConnectionDetails(at index: Int)  {
        
    return cuckoo_manager.call("activateDefaultConnectionDetails(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateDefaultConnectionDetails(at: index))
        
    }
    
    
    
     func activateCustomConnectionDetails(at index: Int)  {
        
    return cuckoo_manager.call("activateCustomConnectionDetails(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateCustomConnectionDetails(at: index))
        
    }
    
    
    
     func selectDefaultItem(at index: Int)  {
        
    return cuckoo_manager.call("selectDefaultItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectDefaultItem(at: index))
        
    }
    
    
    
     func selectCustomItem(at index: Int)  {
        
    return cuckoo_manager.call("selectCustomItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectCustomItem(at: index))
        
    }
    
    
    
     func moveCustomItem(at startIndex: Int, to finalIndex: Int)  {
        
    return cuckoo_manager.call("moveCustomItem(at: Int, to: Int)",
            parameters: (startIndex, finalIndex),
            escapingParameters: (startIndex, finalIndex),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.moveCustomItem(at: startIndex, to: finalIndex))
        
    }
    
    
    
     func removeCustomItem(at index: Int)  {
        
    return cuckoo_manager.call("removeCustomItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeCustomItem(at: index))
        
    }
    
    
    
     func numberOfDefaultConnections() -> Int {
        
    return cuckoo_manager.call("numberOfDefaultConnections() -> Int",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.numberOfDefaultConnections())
        
    }
    
    
    
     func defaultConnection(at index: Int) -> ManagedConnectionViewModel {
        
    return cuckoo_manager.call("defaultConnection(at: Int) -> ManagedConnectionViewModel",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.defaultConnection(at: index))
        
    }
    
    
    
     func numberOfCustomConnections() -> Int {
        
    return cuckoo_manager.call("numberOfCustomConnections() -> Int",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.numberOfCustomConnections())
        
    }
    
    
    
     func customConnection(at index: Int) -> ManagedConnectionViewModel {
        
    return cuckoo_manager.call("customConnection(at: Int) -> ManagedConnectionViewModel",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.customConnection(at: index))
        
    }
    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_NetworkManagementPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func activateConnectionAdd() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "activateConnectionAdd()", parameterMatchers: matchers))
	    }
	    
	    func activateDefaultConnectionDetails<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "activateDefaultConnectionDetails(at: Int)", parameterMatchers: matchers))
	    }
	    
	    func activateCustomConnectionDetails<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "activateCustomConnectionDetails(at: Int)", parameterMatchers: matchers))
	    }
	    
	    func selectDefaultItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "selectDefaultItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	    func selectCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "selectCustomItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	    func moveCustomItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at startIndex: M1, to finalIndex: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Int, Int)> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: startIndex) { $0.0 }, wrap(matchable: finalIndex) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "moveCustomItem(at: Int, to: Int)", parameterMatchers: matchers))
	    }
	    
	    func removeCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "removeCustomItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	    func numberOfDefaultConnections() -> Cuckoo.ProtocolStubFunction<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "numberOfDefaultConnections() -> Int", parameterMatchers: matchers))
	    }
	    
	    func defaultConnection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubFunction<(Int), ManagedConnectionViewModel> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "defaultConnection(at: Int) -> ManagedConnectionViewModel", parameterMatchers: matchers))
	    }
	    
	    func numberOfCustomConnections() -> Cuckoo.ProtocolStubFunction<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "numberOfCustomConnections() -> Int", parameterMatchers: matchers))
	    }
	    
	    func customConnection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubFunction<(Int), ManagedConnectionViewModel> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "customConnection(at: Int) -> ManagedConnectionViewModel", parameterMatchers: matchers))
	    }
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkManagementPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func activateConnectionAdd() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateConnectionAdd()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateDefaultConnectionDetails<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("activateDefaultConnectionDetails(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateCustomConnectionDetails<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("activateCustomConnectionDetails(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectDefaultItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("selectDefaultItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("selectCustomItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func moveCustomItem<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(at startIndex: M1, to finalIndex: M2) -> Cuckoo.__DoNotUse<(Int, Int), Void> where M1.MatchedType == Int, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int, Int)>] = [wrap(matchable: startIndex) { $0.0 }, wrap(matchable: finalIndex) { $0.1 }]
	        return cuckoo_manager.verify("moveCustomItem(at: Int, to: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeCustomItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("removeCustomItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func numberOfDefaultConnections() -> Cuckoo.__DoNotUse<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("numberOfDefaultConnections() -> Int", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func defaultConnection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), ManagedConnectionViewModel> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("defaultConnection(at: Int) -> ManagedConnectionViewModel", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func numberOfCustomConnections() -> Cuckoo.__DoNotUse<(), Int> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("numberOfCustomConnections() -> Int", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func customConnection<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), ManagedConnectionViewModel> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("customConnection(at: Int) -> ManagedConnectionViewModel", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkManagementPresenterProtocolStub: NetworkManagementPresenterProtocol {
    

    

    
     func activateConnectionAdd()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateDefaultConnectionDetails(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateCustomConnectionDetails(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectDefaultItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectCustomItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func moveCustomItem(at startIndex: Int, to finalIndex: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func removeCustomItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func numberOfDefaultConnections() -> Int  {
        return DefaultValueRegistry.defaultValue(for: (Int).self)
    }
    
     func defaultConnection(at index: Int) -> ManagedConnectionViewModel  {
        return DefaultValueRegistry.defaultValue(for: (ManagedConnectionViewModel).self)
    }
    
     func numberOfCustomConnections() -> Int  {
        return DefaultValueRegistry.defaultValue(for: (Int).self)
    }
    
     func customConnection(at index: Int) -> ManagedConnectionViewModel  {
        return DefaultValueRegistry.defaultValue(for: (ManagedConnectionViewModel).self)
    }
    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkManagementInteractorInputProtocol: NetworkManagementInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkManagementInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkManagementInteractorInputProtocol
     typealias Verification = __VerificationProxy_NetworkManagementInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkManagementInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: NetworkManagementInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func select(connection: ConnectionItem)  {
        
    return cuckoo_manager.call("select(connection: ConnectionItem)",
            parameters: (connection),
            escapingParameters: (connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.select(connection: connection))
        
    }
    
    
    
     func select(connection: ConnectionItem, account: AccountItem)  {
        
    return cuckoo_manager.call("select(connection: ConnectionItem, account: AccountItem)",
            parameters: (connection, account),
            escapingParameters: (connection, account),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.select(connection: connection, account: account))
        
    }
    
    
    
     func save(items: [ManagedConnectionItem])  {
        
    return cuckoo_manager.call("save(items: [ManagedConnectionItem])",
            parameters: (items),
            escapingParameters: (items),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save(items: items))
        
    }
    
    
    
     func remove(item: ManagedConnectionItem)  {
        
    return cuckoo_manager.call("remove(item: ManagedConnectionItem)",
            parameters: (item),
            escapingParameters: (item),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(item: item))
        
    }
    

	 struct __StubbingProxy_NetworkManagementInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func select<M1: Cuckoo.Matchable>(connection: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem)> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: connection) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorInputProtocol.self, method: "select(connection: ConnectionItem)", parameterMatchers: matchers))
	    }
	    
	    func select<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(connection: M1, account: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem, AccountItem)> where M1.MatchedType == ConnectionItem, M2.MatchedType == AccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, AccountItem)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: account) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorInputProtocol.self, method: "select(connection: ConnectionItem, account: AccountItem)", parameterMatchers: matchers))
	    }
	    
	    func save<M1: Cuckoo.Matchable>(items: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ManagedConnectionItem])> where M1.MatchedType == [ManagedConnectionItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ManagedConnectionItem])>] = [wrap(matchable: items) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorInputProtocol.self, method: "save(items: [ManagedConnectionItem])", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ManagedConnectionItem)> where M1.MatchedType == ManagedConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedConnectionItem)>] = [wrap(matchable: item) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorInputProtocol.self, method: "remove(item: ManagedConnectionItem)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkManagementInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func select<M1: Cuckoo.Matchable>(connection: M1) -> Cuckoo.__DoNotUse<(ConnectionItem), Void> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: connection) { $0 }]
	        return cuckoo_manager.verify("select(connection: ConnectionItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func select<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(connection: M1, account: M2) -> Cuckoo.__DoNotUse<(ConnectionItem, AccountItem), Void> where M1.MatchedType == ConnectionItem, M2.MatchedType == AccountItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, AccountItem)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: account) { $0.1 }]
	        return cuckoo_manager.verify("select(connection: ConnectionItem, account: AccountItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func save<M1: Cuckoo.Matchable>(items: M1) -> Cuckoo.__DoNotUse<([ManagedConnectionItem]), Void> where M1.MatchedType == [ManagedConnectionItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ManagedConnectionItem])>] = [wrap(matchable: items) { $0 }]
	        return cuckoo_manager.verify("save(items: [ManagedConnectionItem])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(item: M1) -> Cuckoo.__DoNotUse<(ManagedConnectionItem), Void> where M1.MatchedType == ManagedConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ManagedConnectionItem)>] = [wrap(matchable: item) { $0 }]
	        return cuckoo_manager.verify("remove(item: ManagedConnectionItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkManagementInteractorInputProtocolStub: NetworkManagementInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func select(connection: ConnectionItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func select(connection: ConnectionItem, account: AccountItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func save(items: [ManagedConnectionItem])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func remove(item: ManagedConnectionItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkManagementInteractorOutputProtocol: NetworkManagementInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkManagementInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkManagementInteractorOutputProtocol
     typealias Verification = __VerificationProxy_NetworkManagementInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkManagementInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: NetworkManagementInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceiveSelectedConnection(_ item: ConnectionItem)  {
        
    return cuckoo_manager.call("didReceiveSelectedConnection(_: ConnectionItem)",
            parameters: (item),
            escapingParameters: (item),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveSelectedConnection(item))
        
    }
    
    
    
     func didReceiveDefaultConnections(_ connections: [ConnectionItem])  {
        
    return cuckoo_manager.call("didReceiveDefaultConnections(_: [ConnectionItem])",
            parameters: (connections),
            escapingParameters: (connections),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveDefaultConnections(connections))
        
    }
    
    
    
     func didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])  {
        
    return cuckoo_manager.call("didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])",
            parameters: (changes),
            escapingParameters: (changes),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveCustomConnection(changes: changes))
        
    }
    
    
    
     func didReceiveCustomConnection(error: Error)  {
        
    return cuckoo_manager.call("didReceiveCustomConnection(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveCustomConnection(error: error))
        
    }
    
    
    
     func didFindMultiple(accounts: [AccountItem], for connection: ConnectionItem)  {
        
    return cuckoo_manager.call("didFindMultiple(accounts: [AccountItem], for: ConnectionItem)",
            parameters: (accounts, connection),
            escapingParameters: (accounts, connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didFindMultiple(accounts: accounts, for: connection))
        
    }
    
    
    
     func didFindNoAccounts(for connection: ConnectionItem)  {
        
    return cuckoo_manager.call("didFindNoAccounts(for: ConnectionItem)",
            parameters: (connection),
            escapingParameters: (connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didFindNoAccounts(for: connection))
        
    }
    
    
    
     func didReceiveConnection(selectionError: Error)  {
        
    return cuckoo_manager.call("didReceiveConnection(selectionError: Error)",
            parameters: (selectionError),
            escapingParameters: (selectionError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveConnection(selectionError: selectionError))
        
    }
    

	 struct __StubbingProxy_NetworkManagementInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceiveSelectedConnection<M1: Cuckoo.Matchable>(_ item: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem)> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: item) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didReceiveSelectedConnection(_: ConnectionItem)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveDefaultConnections<M1: Cuckoo.Matchable>(_ connections: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ConnectionItem])> where M1.MatchedType == [ConnectionItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ConnectionItem])>] = [wrap(matchable: connections) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didReceiveDefaultConnections(_: [ConnectionItem])", parameterMatchers: matchers))
	    }
	    
	    func didReceiveCustomConnection<M1: Cuckoo.Matchable>(changes: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([DataProviderChange<ManagedConnectionItem>])> where M1.MatchedType == [DataProviderChange<ManagedConnectionItem>] {
	        let matchers: [Cuckoo.ParameterMatcher<([DataProviderChange<ManagedConnectionItem>])>] = [wrap(matchable: changes) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])", parameterMatchers: matchers))
	    }
	    
	    func didReceiveCustomConnection<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didReceiveCustomConnection(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didFindMultiple<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(accounts: M1, for connection: M2) -> Cuckoo.ProtocolStubNoReturnFunction<([AccountItem], ConnectionItem)> where M1.MatchedType == [AccountItem], M2.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<([AccountItem], ConnectionItem)>] = [wrap(matchable: accounts) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didFindMultiple(accounts: [AccountItem], for: ConnectionItem)", parameterMatchers: matchers))
	    }
	    
	    func didFindNoAccounts<M1: Cuckoo.Matchable>(for connection: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem)> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: connection) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didFindNoAccounts(for: ConnectionItem)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveConnection<M1: Cuckoo.Matchable>(selectionError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: selectionError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementInteractorOutputProtocol.self, method: "didReceiveConnection(selectionError: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkManagementInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceiveSelectedConnection<M1: Cuckoo.Matchable>(_ item: M1) -> Cuckoo.__DoNotUse<(ConnectionItem), Void> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: item) { $0 }]
	        return cuckoo_manager.verify("didReceiveSelectedConnection(_: ConnectionItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveDefaultConnections<M1: Cuckoo.Matchable>(_ connections: M1) -> Cuckoo.__DoNotUse<([ConnectionItem]), Void> where M1.MatchedType == [ConnectionItem] {
	        let matchers: [Cuckoo.ParameterMatcher<([ConnectionItem])>] = [wrap(matchable: connections) { $0 }]
	        return cuckoo_manager.verify("didReceiveDefaultConnections(_: [ConnectionItem])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveCustomConnection<M1: Cuckoo.Matchable>(changes: M1) -> Cuckoo.__DoNotUse<([DataProviderChange<ManagedConnectionItem>]), Void> where M1.MatchedType == [DataProviderChange<ManagedConnectionItem>] {
	        let matchers: [Cuckoo.ParameterMatcher<([DataProviderChange<ManagedConnectionItem>])>] = [wrap(matchable: changes) { $0 }]
	        return cuckoo_manager.verify("didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveCustomConnection<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveCustomConnection(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didFindMultiple<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(accounts: M1, for connection: M2) -> Cuckoo.__DoNotUse<([AccountItem], ConnectionItem), Void> where M1.MatchedType == [AccountItem], M2.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<([AccountItem], ConnectionItem)>] = [wrap(matchable: accounts) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return cuckoo_manager.verify("didFindMultiple(accounts: [AccountItem], for: ConnectionItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didFindNoAccounts<M1: Cuckoo.Matchable>(for connection: M1) -> Cuckoo.__DoNotUse<(ConnectionItem), Void> where M1.MatchedType == ConnectionItem {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem)>] = [wrap(matchable: connection) { $0 }]
	        return cuckoo_manager.verify("didFindNoAccounts(for: ConnectionItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveConnection<M1: Cuckoo.Matchable>(selectionError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: selectionError) { $0 }]
	        return cuckoo_manager.verify("didReceiveConnection(selectionError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkManagementInteractorOutputProtocolStub: NetworkManagementInteractorOutputProtocol {
    

    

    
     func didReceiveSelectedConnection(_ item: ConnectionItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveDefaultConnections(_ connections: [ConnectionItem])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveCustomConnection(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didFindMultiple(accounts: [AccountItem], for connection: ConnectionItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didFindNoAccounts(for connection: ConnectionItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveConnection(selectionError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkManagementWireframeProtocol: NetworkManagementWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkManagementWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkManagementWireframeProtocol
     typealias Verification = __VerificationProxy_NetworkManagementWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkManagementWireframeProtocol?

     func enableDefaultImplementation(_ stub: NetworkManagementWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func presentAccountSelection(_ accounts: [AccountItem], addressType: SNAddressType, delegate: ModalPickerViewControllerDelegate, from view: NetworkManagementViewProtocol?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentAccountSelection(_: [AccountItem], addressType: SNAddressType, delegate: ModalPickerViewControllerDelegate, from: NetworkManagementViewProtocol?, context: AnyObject?)",
            parameters: (accounts, addressType, delegate, view, context),
            escapingParameters: (accounts, addressType, delegate, view, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAccountSelection(accounts, addressType: addressType, delegate: delegate, from: view, context: context))
        
    }
    
    
    
     func presentAccountCreation(for connection: ConnectionItem, from view: NetworkManagementViewProtocol?)  {
        
    return cuckoo_manager.call("presentAccountCreation(for: ConnectionItem, from: NetworkManagementViewProtocol?)",
            parameters: (connection, view),
            escapingParameters: (connection, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAccountCreation(for: connection, from: view))
        
    }
    
    
    
     func presentConnectionInfo(_ connectionItem: ConnectionItem, mode: NetworkInfoMode, from view: NetworkManagementViewProtocol?)  {
        
    return cuckoo_manager.call("presentConnectionInfo(_: ConnectionItem, mode: NetworkInfoMode, from: NetworkManagementViewProtocol?)",
            parameters: (connectionItem, mode, view),
            escapingParameters: (connectionItem, mode, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentConnectionInfo(connectionItem, mode: mode, from: view))
        
    }
    
    
    
     func presentConnectionAdd(from view: NetworkManagementViewProtocol?)  {
        
    return cuckoo_manager.call("presentConnectionAdd(from: NetworkManagementViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentConnectionAdd(from: view))
        
    }
    
    
    
     func complete(from view: NetworkManagementViewProtocol?)  {
        
    return cuckoo_manager.call("complete(from: NetworkManagementViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.complete(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_NetworkManagementWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func presentAccountSelection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(_ accounts: M1, addressType: M2, delegate: M3, from view: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<([AccountItem], SNAddressType, ModalPickerViewControllerDelegate, NetworkManagementViewProtocol?, AnyObject?)> where M1.MatchedType == [AccountItem], M2.MatchedType == SNAddressType, M3.MatchedType == ModalPickerViewControllerDelegate, M4.OptionalMatchedType == NetworkManagementViewProtocol, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<([AccountItem], SNAddressType, ModalPickerViewControllerDelegate, NetworkManagementViewProtocol?, AnyObject?)>] = [wrap(matchable: accounts) { $0.0 }, wrap(matchable: addressType) { $0.1 }, wrap(matchable: delegate) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "presentAccountSelection(_: [AccountItem], addressType: SNAddressType, delegate: ModalPickerViewControllerDelegate, from: NetworkManagementViewProtocol?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func presentAccountCreation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for connection: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem, NetworkManagementViewProtocol?)> where M1.MatchedType == ConnectionItem, M2.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, NetworkManagementViewProtocol?)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "presentAccountCreation(for: ConnectionItem, from: NetworkManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentConnectionInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(_ connectionItem: M1, mode: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionItem, NetworkInfoMode, NetworkManagementViewProtocol?)> where M1.MatchedType == ConnectionItem, M2.MatchedType == NetworkInfoMode, M3.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, NetworkInfoMode, NetworkManagementViewProtocol?)>] = [wrap(matchable: connectionItem) { $0.0 }, wrap(matchable: mode) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "presentConnectionInfo(_: ConnectionItem, mode: NetworkInfoMode, from: NetworkManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentConnectionAdd<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(NetworkManagementViewProtocol?)> where M1.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "presentConnectionAdd(from: NetworkManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(NetworkManagementViewProtocol?)> where M1.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "complete(from: NetworkManagementViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkManagementWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkManagementWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func presentAccountSelection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(_ accounts: M1, addressType: M2, delegate: M3, from view: M4, context: M5) -> Cuckoo.__DoNotUse<([AccountItem], SNAddressType, ModalPickerViewControllerDelegate, NetworkManagementViewProtocol?, AnyObject?), Void> where M1.MatchedType == [AccountItem], M2.MatchedType == SNAddressType, M3.MatchedType == ModalPickerViewControllerDelegate, M4.OptionalMatchedType == NetworkManagementViewProtocol, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<([AccountItem], SNAddressType, ModalPickerViewControllerDelegate, NetworkManagementViewProtocol?, AnyObject?)>] = [wrap(matchable: accounts) { $0.0 }, wrap(matchable: addressType) { $0.1 }, wrap(matchable: delegate) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentAccountSelection(_: [AccountItem], addressType: SNAddressType, delegate: ModalPickerViewControllerDelegate, from: NetworkManagementViewProtocol?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentAccountCreation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for connection: M1, from view: M2) -> Cuckoo.__DoNotUse<(ConnectionItem, NetworkManagementViewProtocol?), Void> where M1.MatchedType == ConnectionItem, M2.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, NetworkManagementViewProtocol?)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("presentAccountCreation(for: ConnectionItem, from: NetworkManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentConnectionInfo<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(_ connectionItem: M1, mode: M2, from view: M3) -> Cuckoo.__DoNotUse<(ConnectionItem, NetworkInfoMode, NetworkManagementViewProtocol?), Void> where M1.MatchedType == ConnectionItem, M2.MatchedType == NetworkInfoMode, M3.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionItem, NetworkInfoMode, NetworkManagementViewProtocol?)>] = [wrap(matchable: connectionItem) { $0.0 }, wrap(matchable: mode) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("presentConnectionInfo(_: ConnectionItem, mode: NetworkInfoMode, from: NetworkManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentConnectionAdd<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(NetworkManagementViewProtocol?), Void> where M1.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("presentConnectionAdd(from: NetworkManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(NetworkManagementViewProtocol?), Void> where M1.OptionalMatchedType == NetworkManagementViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkManagementViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("complete(from: NetworkManagementViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkManagementWireframeProtocolStub: NetworkManagementWireframeProtocol {
    

    

    
     func presentAccountSelection(_ accounts: [AccountItem], addressType: SNAddressType, delegate: ModalPickerViewControllerDelegate, from view: NetworkManagementViewProtocol?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentAccountCreation(for connection: ConnectionItem, from view: NetworkManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentConnectionInfo(_ connectionItem: ConnectionItem, mode: NetworkInfoMode, from view: NetworkManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentConnectionAdd(from view: NetworkManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func complete(from view: NetworkManagementViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation


 class MockOnboardingMainViewProtocol: OnboardingMainViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainViewProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainViewProtocol
     typealias Verification = __VerificationProxy_OnboardingMainViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainViewProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    

	 struct __StubbingProxy_OnboardingMainViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	}

	 struct __VerificationProxy_OnboardingMainViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class OnboardingMainViewProtocolStub: OnboardingMainViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
}



 class MockOnboardingMainPresenterProtocol: OnboardingMainPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainPresenterProtocol
     typealias Verification = __VerificationProxy_OnboardingMainPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainPresenterProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func activateSignup()  {
        
    return cuckoo_manager.call("activateSignup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateSignup())
        
    }
    
    
    
     func activateAccountRestore()  {
        
    return cuckoo_manager.call("activateAccountRestore()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAccountRestore())
        
    }
    
    
    
     func activateTerms()  {
        
    return cuckoo_manager.call("activateTerms()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateTerms())
        
    }
    
    
    
     func activatePrivacy()  {
        
    return cuckoo_manager.call("activatePrivacy()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activatePrivacy())
        
    }
    

	 struct __StubbingProxy_OnboardingMainPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateSignup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateSignup()", parameterMatchers: matchers))
	    }
	    
	    func activateAccountRestore() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateAccountRestore()", parameterMatchers: matchers))
	    }
	    
	    func activateTerms() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateTerms()", parameterMatchers: matchers))
	    }
	    
	    func activatePrivacy() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activatePrivacy()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateSignup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateSignup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAccountRestore() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAccountRestore()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateTerms() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateTerms()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activatePrivacy() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activatePrivacy()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainPresenterProtocolStub: OnboardingMainPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateSignup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAccountRestore()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateTerms()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activatePrivacy()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainWireframeProtocol: OnboardingMainWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainWireframeProtocol
     typealias Verification = __VerificationProxy_OnboardingMainWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainWireframeProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSignup(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showSignup(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSignup(from: view))
        
    }
    
    
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountRestore(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountRestore(from: view))
        
    }
    
    
    
     func showKeystoreImport(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showKeystoreImport(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showKeystoreImport(from: view))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_OnboardingMainWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showSignup(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showAccountRestore(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showKeystoreImport<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showKeystoreImport(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showSignup(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAccountRestore(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showKeystoreImport<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showKeystoreImport(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainWireframeProtocolStub: OnboardingMainWireframeProtocol {
    

    

    
     func showSignup(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showKeystoreImport(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainInteractorInputProtocol: OnboardingMainInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainInteractorInputProtocol
     typealias Verification = __VerificationProxy_OnboardingMainInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_OnboardingMainInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainInteractorInputProtocolStub: OnboardingMainInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainInteractorOutputProtocol: OnboardingMainInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainInteractorOutputProtocol
     typealias Verification = __VerificationProxy_OnboardingMainInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didSuggestKeystoreImport()  {
        
    return cuckoo_manager.call("didSuggestKeystoreImport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSuggestKeystoreImport())
        
    }
    

	 struct __StubbingProxy_OnboardingMainInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didSuggestKeystoreImport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainInteractorOutputProtocol.self, method: "didSuggestKeystoreImport()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didSuggestKeystoreImport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didSuggestKeystoreImport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainInteractorOutputProtocolStub: OnboardingMainInteractorOutputProtocol {
    

    

    
     func didSuggestKeystoreImport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockPinSetupViewProtocol: PinSetupViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupViewProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupViewProtocol
     typealias Verification = __VerificationProxy_PinSetupViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupViewProtocol?

     func enableDefaultImplementation(_ stub: PinSetupViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)",
            parameters: (biometryType, completionBlock),
            escapingParameters: (biometryType, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRequestBiometryUsage(biometryType: biometryType, completionBlock: completionBlock))
        
    }
    
    
    
     func didChangeAccessoryState(enabled: Bool)  {
        
    return cuckoo_manager.call("didChangeAccessoryState(enabled: Bool)",
            parameters: (enabled),
            escapingParameters: (enabled),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChangeAccessoryState(enabled: enabled))
        
    }
    
    
    
     func didReceiveWrongPincode()  {
        
    return cuckoo_manager.call("didReceiveWrongPincode()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveWrongPincode())
        
    }
    

	 struct __StubbingProxy_PinSetupViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPinSetupViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPinSetupViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didRequestBiometryUsage<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(biometryType: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(AvailableBiometryType, (Bool) -> Void)> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: biometryType) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func didChangeAccessoryState<M1: Cuckoo.Matchable>(enabled: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: enabled) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didChangeAccessoryState(enabled: Bool)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveWrongPincode() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didReceiveWrongPincode()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didRequestBiometryUsage<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(biometryType: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(AvailableBiometryType, (Bool) -> Void), Void> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: biometryType) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didChangeAccessoryState<M1: Cuckoo.Matchable>(enabled: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: enabled) { $0 }]
	        return cuckoo_manager.verify("didChangeAccessoryState(enabled: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveWrongPincode() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReceiveWrongPincode()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupViewProtocolStub: PinSetupViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didChangeAccessoryState(enabled: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveWrongPincode()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupPresenterProtocol: PinSetupPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupPresenterProtocol
     typealias Verification = __VerificationProxy_PinSetupPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupPresenterProtocol?

     func enableDefaultImplementation(_ stub: PinSetupPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func start()  {
        
    return cuckoo_manager.call("start()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.start())
        
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
    
    
    
     func activateBiometricAuth()  {
        
    return cuckoo_manager.call("activateBiometricAuth()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateBiometricAuth())
        
    }
    
    
    
     func submit(pin: String)  {
        
    return cuckoo_manager.call("submit(pin: String)",
            parameters: (pin),
            escapingParameters: (pin),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.submit(pin: pin))
        
    }
    

	 struct __StubbingProxy_PinSetupPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func start() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "start()", parameterMatchers: matchers))
	    }
	    
	    func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "cancel()", parameterMatchers: matchers))
	    }
	    
	    func activateBiometricAuth() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "activateBiometricAuth()", parameterMatchers: matchers))
	    }
	    
	    func submit<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "submit(pin: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func start() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("start()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancel() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("cancel()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateBiometricAuth() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateBiometricAuth()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func submit<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return cuckoo_manager.verify("submit(pin: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupPresenterProtocolStub: PinSetupPresenterProtocol {
    

    

    
     func start()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func cancel()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateBiometricAuth()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func submit(pin: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupInteractorInputProtocol: PinSetupInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupInteractorInputProtocol
     typealias Verification = __VerificationProxy_PinSetupInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: PinSetupInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func process(pin: String)  {
        
    return cuckoo_manager.call("process(pin: String)",
            parameters: (pin),
            escapingParameters: (pin),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.process(pin: pin))
        
    }
    

	 struct __StubbingProxy_PinSetupInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func process<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorInputProtocol.self, method: "process(pin: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func process<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return cuckoo_manager.verify("process(pin: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupInteractorInputProtocolStub: PinSetupInteractorInputProtocol {
    

    

    
     func process(pin: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupInteractorOutputProtocol: PinSetupInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupInteractorOutputProtocol
     typealias Verification = __VerificationProxy_PinSetupInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: PinSetupInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didSavePin()  {
        
    return cuckoo_manager.call("didSavePin()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSavePin())
        
    }
    
    
    
     func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)",
            parameters: (type, completionBlock),
            escapingParameters: (type, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartWaitingBiometryDecision(type: type, completionBlock: completionBlock))
        
    }
    
    
    
     func didChangeState(from: PinSetupInteractor.PinSetupState)  {
        
    return cuckoo_manager.call("didChangeState(from: PinSetupInteractor.PinSetupState)",
            parameters: (from),
            escapingParameters: (from),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChangeState(from: from))
        
    }
    

	 struct __StubbingProxy_PinSetupInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didSavePin() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didSavePin()", parameterMatchers: matchers))
	    }
	    
	    func didStartWaitingBiometryDecision<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(type: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(AvailableBiometryType, (Bool) -> Void)> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: type) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func didChangeState<M1: Cuckoo.Matchable>(from: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupInteractor.PinSetupState)> where M1.MatchedType == PinSetupInteractor.PinSetupState {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupInteractor.PinSetupState)>] = [wrap(matchable: from) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didChangeState(from: PinSetupInteractor.PinSetupState)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didSavePin() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didSavePin()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartWaitingBiometryDecision<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(type: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(AvailableBiometryType, (Bool) -> Void), Void> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: type) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didChangeState<M1: Cuckoo.Matchable>(from: M1) -> Cuckoo.__DoNotUse<(PinSetupInteractor.PinSetupState), Void> where M1.MatchedType == PinSetupInteractor.PinSetupState {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupInteractor.PinSetupState)>] = [wrap(matchable: from) { $0 }]
	        return cuckoo_manager.verify("didChangeState(from: PinSetupInteractor.PinSetupState)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupInteractorOutputProtocolStub: PinSetupInteractorOutputProtocol {
    

    

    
     func didSavePin()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didChangeState(from: PinSetupInteractor.PinSetupState)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupWireframeProtocol: PinSetupWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupWireframeProtocol
     typealias Verification = __VerificationProxy_PinSetupWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupWireframeProtocol?

     func enableDefaultImplementation(_ stub: PinSetupWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showMain(from view: PinSetupViewProtocol?)  {
        
    return cuckoo_manager.call("showMain(from: PinSetupViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showMain(from: view))
        
    }
    
    
    
     func showSignup(from view: PinSetupViewProtocol?)  {
        
    return cuckoo_manager.call("showSignup(from: PinSetupViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSignup(from: view))
        
    }
    

	 struct __StubbingProxy_PinSetupWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showMain<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?)> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "showMain(from: PinSetupViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?)> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "showSignup(from: PinSetupViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showMain<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?), Void> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showMain(from: PinSetupViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?), Void> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showSignup(from: PinSetupViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupWireframeProtocolStub: PinSetupWireframeProtocol {
    

    

    
     func showMain(from view: PinSetupViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showSignup(from view: PinSetupViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation


 class MockProfileViewProtocol: ProfileViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileViewProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileViewProtocol
     typealias Verification = __VerificationProxy_ProfileViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileViewProtocol?

     func enableDefaultImplementation(_ stub: ProfileViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didLoad(userViewModel: ProfileUserViewModelProtocol)  {
        
    return cuckoo_manager.call("didLoad(userViewModel: ProfileUserViewModelProtocol)",
            parameters: (userViewModel),
            escapingParameters: (userViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(userViewModel: userViewModel))
        
    }
    
    
    
     func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])  {
        
    return cuckoo_manager.call("didLoad(optionViewModels: [ProfileOptionViewModelProtocol])",
            parameters: (optionViewModels),
            escapingParameters: (optionViewModels),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(optionViewModels: optionViewModels))
        
    }
    

	 struct __StubbingProxy_ProfileViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockProfileViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockProfileViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didLoad<M1: Cuckoo.Matchable>(userViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileUserViewModelProtocol)> where M1.MatchedType == ProfileUserViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileUserViewModelProtocol)>] = [wrap(matchable: userViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileViewProtocol.self, method: "didLoad(userViewModel: ProfileUserViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didLoad<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ProfileOptionViewModelProtocol])> where M1.MatchedType == [ProfileOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([ProfileOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileViewProtocol.self, method: "didLoad(optionViewModels: [ProfileOptionViewModelProtocol])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(userViewModel: M1) -> Cuckoo.__DoNotUse<(ProfileUserViewModelProtocol), Void> where M1.MatchedType == ProfileUserViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileUserViewModelProtocol)>] = [wrap(matchable: userViewModel) { $0 }]
	        return cuckoo_manager.verify("didLoad(userViewModel: ProfileUserViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.__DoNotUse<([ProfileOptionViewModelProtocol]), Void> where M1.MatchedType == [ProfileOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([ProfileOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return cuckoo_manager.verify("didLoad(optionViewModels: [ProfileOptionViewModelProtocol])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileViewProtocolStub: ProfileViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didLoad(userViewModel: ProfileUserViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfilePresenterProtocol: ProfilePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfilePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_ProfilePresenterProtocol
     typealias Verification = __VerificationProxy_ProfilePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfilePresenterProtocol?

     func enableDefaultImplementation(_ stub: ProfilePresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func activateAccountDetails()  {
        
    return cuckoo_manager.call("activateAccountDetails()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAccountDetails())
        
    }
    
    
    
     func activateOption(at index: UInt)  {
        
    return cuckoo_manager.call("activateOption(at: UInt)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateOption(at: index))
        
    }
    

	 struct __StubbingProxy_ProfilePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateAccountDetails() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "activateAccountDetails()", parameterMatchers: matchers))
	    }
	    
	    func activateOption<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UInt)> where M1.MatchedType == UInt {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "activateOption(at: UInt)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfilePresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAccountDetails() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAccountDetails()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateOption<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(UInt), Void> where M1.MatchedType == UInt {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("activateOption(at: UInt)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfilePresenterProtocolStub: ProfilePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAccountDetails()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateOption(at index: UInt)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileInteractorInputProtocol: ProfileInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileInteractorInputProtocol
     typealias Verification = __VerificationProxy_ProfileInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: ProfileInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_ProfileInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileInteractorInputProtocolStub: ProfileInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileInteractorOutputProtocol: ProfileInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileInteractorOutputProtocol
     typealias Verification = __VerificationProxy_ProfileInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: ProfileInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(userSettings: UserSettings)  {
        
    return cuckoo_manager.call("didReceive(userSettings: UserSettings)",
            parameters: (userSettings),
            escapingParameters: (userSettings),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(userSettings: userSettings))
        
    }
    
    
    
     func didReceiveUserDataProvider(error: Error)  {
        
    return cuckoo_manager.call("didReceiveUserDataProvider(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveUserDataProvider(error: error))
        
    }
    

	 struct __StubbingProxy_ProfileInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(userSettings: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UserSettings)> where M1.MatchedType == UserSettings {
	        let matchers: [Cuckoo.ParameterMatcher<(UserSettings)>] = [wrap(matchable: userSettings) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileInteractorOutputProtocol.self, method: "didReceive(userSettings: UserSettings)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileInteractorOutputProtocol.self, method: "didReceiveUserDataProvider(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(userSettings: M1) -> Cuckoo.__DoNotUse<(UserSettings), Void> where M1.MatchedType == UserSettings {
	        let matchers: [Cuckoo.ParameterMatcher<(UserSettings)>] = [wrap(matchable: userSettings) { $0 }]
	        return cuckoo_manager.verify("didReceive(userSettings: UserSettings)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveUserDataProvider(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileInteractorOutputProtocolStub: ProfileInteractorOutputProtocol {
    

    

    
     func didReceive(userSettings: UserSettings)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveUserDataProvider(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileWireframeProtocol: ProfileWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileWireframeProtocol
     typealias Verification = __VerificationProxy_ProfileWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileWireframeProtocol?

     func enableDefaultImplementation(_ stub: ProfileWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showAccountDetails(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountDetails(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountDetails(from: view))
        
    }
    
    
    
     func showAccountSelection(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountSelection(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountSelection(from: view))
        
    }
    
    
    
     func showConnectionSelection(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showConnectionSelection(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showConnectionSelection(from: view))
        
    }
    
    
    
     func showLanguageSelection(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showLanguageSelection(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLanguageSelection(from: view))
        
    }
    
    
    
     func showPincodeChange(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showPincodeChange(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPincodeChange(from: view))
        
    }
    
    
    
     func showAbout(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showAbout(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAbout(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)  {
        
    return cuckoo_manager.call("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)",
            parameters: (title, view, closure),
            escapingParameters: (title, view, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentSuccessNotification(title, from: view, completion: closure))
        
    }
    

	 struct __StubbingProxy_ProfileWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showAccountDetails<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showAccountDetails(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAccountSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showAccountSelection(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showConnectionSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showConnectionSelection(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showLanguageSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showLanguageSelection(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showPincodeChange<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showPincodeChange(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAbout<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showAbout(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ControllerBackedProtocol?, (() -> Void)?)> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showAccountDetails<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAccountDetails(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAccountSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAccountSelection(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showConnectionSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showConnectionSelection(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showLanguageSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showLanguageSelection(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showPincodeChange<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showPincodeChange(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAbout<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAbout(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentSuccessNotification<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(_ title: M1, from view: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(String, ControllerBackedProtocol?, (() -> Void)?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ControllerBackedProtocol?, (() -> Void)?)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("presentSuccessNotification(_: String, from: ControllerBackedProtocol?, completion: (() -> Void)?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileWireframeProtocolStub: ProfileWireframeProtocol {
    

    

    
     func showAccountDetails(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAccountSelection(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showConnectionSelection(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showLanguageSelection(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showPincodeChange(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAbout(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockRootPresenterProtocol: RootPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_RootPresenterProtocol
     typealias Verification = __VerificationProxy_RootPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootPresenterProtocol?

     func enableDefaultImplementation(_ stub: RootPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func loadOnLaunch()  {
        
    return cuckoo_manager.call("loadOnLaunch()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.loadOnLaunch())
        
    }
    

	 struct __StubbingProxy_RootPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func loadOnLaunch() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootPresenterProtocol.self, method: "loadOnLaunch()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func loadOnLaunch() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("loadOnLaunch()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootPresenterProtocolStub: RootPresenterProtocol {
    

    

    
     func loadOnLaunch()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootWireframeProtocol: RootWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_RootWireframeProtocol
     typealias Verification = __VerificationProxy_RootWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootWireframeProtocol?

     func enableDefaultImplementation(_ stub: RootWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showLocalAuthentication(on view: UIWindow)  {
        
    return cuckoo_manager.call("showLocalAuthentication(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLocalAuthentication(on: view))
        
    }
    
    
    
     func showOnboarding(on view: UIWindow)  {
        
    return cuckoo_manager.call("showOnboarding(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showOnboarding(on: view))
        
    }
    
    
    
     func showPincodeSetup(on view: UIWindow)  {
        
    return cuckoo_manager.call("showPincodeSetup(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPincodeSetup(on: view))
        
    }
    
    
    
     func showBroken(on view: UIWindow)  {
        
    return cuckoo_manager.call("showBroken(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showBroken(on: view))
        
    }
    

	 struct __StubbingProxy_RootWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showLocalAuthentication<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showLocalAuthentication(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showOnboarding<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showOnboarding(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showPincodeSetup<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showPincodeSetup(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showBroken<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showBroken(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showLocalAuthentication<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showLocalAuthentication(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showOnboarding<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showOnboarding(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showPincodeSetup<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showPincodeSetup(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showBroken<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showBroken(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootWireframeProtocolStub: RootWireframeProtocol {
    

    

    
     func showLocalAuthentication(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showOnboarding(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showPincodeSetup(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showBroken(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootInteractorInputProtocol: RootInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_RootInteractorInputProtocol
     typealias Verification = __VerificationProxy_RootInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: RootInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func decideModuleSynchroniously()  {
        
    return cuckoo_manager.call("decideModuleSynchroniously()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.decideModuleSynchroniously())
        
    }
    

	 struct __StubbingProxy_RootInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func decideModuleSynchroniously() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorInputProtocol.self, method: "decideModuleSynchroniously()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func decideModuleSynchroniously() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("decideModuleSynchroniously()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootInteractorInputProtocolStub: RootInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func decideModuleSynchroniously()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootInteractorOutputProtocol: RootInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_RootInteractorOutputProtocol
     typealias Verification = __VerificationProxy_RootInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: RootInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didDecideOnboarding()  {
        
    return cuckoo_manager.call("didDecideOnboarding()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideOnboarding())
        
    }
    
    
    
     func didDecideLocalAuthentication()  {
        
    return cuckoo_manager.call("didDecideLocalAuthentication()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideLocalAuthentication())
        
    }
    
    
    
     func didDecidePincodeSetup()  {
        
    return cuckoo_manager.call("didDecidePincodeSetup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecidePincodeSetup())
        
    }
    
    
    
     func didDecideBroken()  {
        
    return cuckoo_manager.call("didDecideBroken()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideBroken())
        
    }
    

	 struct __StubbingProxy_RootInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didDecideOnboarding() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideOnboarding()", parameterMatchers: matchers))
	    }
	    
	    func didDecideLocalAuthentication() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideLocalAuthentication()", parameterMatchers: matchers))
	    }
	    
	    func didDecidePincodeSetup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecidePincodeSetup()", parameterMatchers: matchers))
	    }
	    
	    func didDecideBroken() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideBroken()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didDecideOnboarding() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideOnboarding()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideLocalAuthentication() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideLocalAuthentication()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecidePincodeSetup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecidePincodeSetup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideBroken() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideBroken()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootInteractorOutputProtocolStub: RootInteractorOutputProtocol {
    

    

    
     func didDecideOnboarding()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideLocalAuthentication()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecidePincodeSetup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideBroken()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import BigInt
import Foundation
import RobinHood


 class MockNetworkStakingInfoOperationFactoryProtocol: NetworkStakingInfoOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkStakingInfoOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkStakingInfoOperationFactoryProtocol
     typealias Verification = __VerificationProxy_NetworkStakingInfoOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkStakingInfoOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: NetworkStakingInfoOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo> {
        
    return cuckoo_manager.call("networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.networkStakingOperation())
        
    }
    

	 struct __StubbingProxy_NetworkStakingInfoOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func networkStakingOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<NetworkStakingInfo>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkStakingInfoOperationFactoryProtocol.self, method: "networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkStakingInfoOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func networkStakingOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<NetworkStakingInfo>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkStakingInfoOperationFactoryProtocolStub: NetworkStakingInfoOperationFactoryProtocol {
    

    

    
     func networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<NetworkStakingInfo>).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import IrohaCrypto
import RobinHood


 class MockValidatorOperationFactoryProtocol: ValidatorOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorOperationFactoryProtocol
     typealias Verification = __VerificationProxy_ValidatorOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: ValidatorOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        
    return cuckoo_manager.call("allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.allElectedOperation())
        
    }
    

	 struct __StubbingProxy_ValidatorOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func allElectedOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<[ElectedValidatorInfo]>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorOperationFactoryProtocol.self, method: "allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func allElectedOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<[ElectedValidatorInfo]>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorOperationFactoryProtocolStub: ValidatorOperationFactoryProtocol {
    

    

    
     func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<[ElectedValidatorInfo]>).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SoraFoundation


 class MockRecommendedValidatorsViewProtocol: RecommendedValidatorsViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RecommendedValidatorsViewProtocol
    
     typealias Stubbing = __StubbingProxy_RecommendedValidatorsViewProtocol
     typealias Verification = __VerificationProxy_RecommendedValidatorsViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RecommendedValidatorsViewProtocol?

     func enableDefaultImplementation(_ stub: RecommendedValidatorsViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    

    

    
    
    
     func didReceive(viewModel: RecommendedViewModelProtocol)  {
        
    return cuckoo_manager.call("didReceive(viewModel: RecommendedViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(viewModel: viewModel))
        
    }
    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    

	 struct __StubbingProxy_RecommendedValidatorsViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRecommendedValidatorsViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRecommendedValidatorsViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockRecommendedValidatorsViewProtocol, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RecommendedViewModelProtocol)> where M1.MatchedType == RecommendedViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsViewProtocol.self, method: "didReceive(viewModel: RecommendedViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsViewProtocol.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RecommendedValidatorsViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(RecommendedViewModelProtocol), Void> where M1.MatchedType == RecommendedViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(viewModel: RecommendedViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RecommendedValidatorsViewProtocolStub: RecommendedValidatorsViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    

    

    
     func didReceive(viewModel: RecommendedViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRecommendedValidatorsPresenterProtocol: RecommendedValidatorsPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RecommendedValidatorsPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_RecommendedValidatorsPresenterProtocol
     typealias Verification = __VerificationProxy_RecommendedValidatorsPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RecommendedValidatorsPresenterProtocol?

     func enableDefaultImplementation(_ stub: RecommendedValidatorsPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    
    
    
     func selectRecommendedValidators()  {
        
    return cuckoo_manager.call("selectRecommendedValidators()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectRecommendedValidators())
        
    }
    
    
    
     func selectCustomValidators()  {
        
    return cuckoo_manager.call("selectCustomValidators()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectCustomValidators())
        
    }
    

	 struct __StubbingProxy_RecommendedValidatorsPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	    func selectRecommendedValidators() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsPresenterProtocol.self, method: "selectRecommendedValidators()", parameterMatchers: matchers))
	    }
	    
	    func selectCustomValidators() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsPresenterProtocol.self, method: "selectCustomValidators()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RecommendedValidatorsPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectRecommendedValidators() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectRecommendedValidators()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectCustomValidators() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectCustomValidators()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RecommendedValidatorsPresenterProtocolStub: RecommendedValidatorsPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectRecommendedValidators()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectCustomValidators()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRecommendedValidatorsInteractorInputProtocol: RecommendedValidatorsInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RecommendedValidatorsInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_RecommendedValidatorsInteractorInputProtocol
     typealias Verification = __VerificationProxy_RecommendedValidatorsInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RecommendedValidatorsInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: RecommendedValidatorsInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_RecommendedValidatorsInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RecommendedValidatorsInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RecommendedValidatorsInteractorInputProtocolStub: RecommendedValidatorsInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRecommendedValidatorsInteractorOutputProtocol: RecommendedValidatorsInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RecommendedValidatorsInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_RecommendedValidatorsInteractorOutputProtocol
     typealias Verification = __VerificationProxy_RecommendedValidatorsInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RecommendedValidatorsInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: RecommendedValidatorsInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(validators: [ElectedValidatorInfo])  {
        
    return cuckoo_manager.call("didReceive(validators: [ElectedValidatorInfo])",
            parameters: (validators),
            escapingParameters: (validators),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(validators: validators))
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_RecommendedValidatorsInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(validators: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ElectedValidatorInfo])> where M1.MatchedType == [ElectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<([ElectedValidatorInfo])>] = [wrap(matchable: validators) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsInteractorOutputProtocol.self, method: "didReceive(validators: [ElectedValidatorInfo])", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RecommendedValidatorsInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(validators: M1) -> Cuckoo.__DoNotUse<([ElectedValidatorInfo]), Void> where M1.MatchedType == [ElectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<([ElectedValidatorInfo])>] = [wrap(matchable: validators) { $0 }]
	        return cuckoo_manager.verify("didReceive(validators: [ElectedValidatorInfo])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RecommendedValidatorsInteractorOutputProtocolStub: RecommendedValidatorsInteractorOutputProtocol {
    

    

    
     func didReceive(validators: [ElectedValidatorInfo])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRecommendedValidatorsWireframeProtocol: RecommendedValidatorsWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RecommendedValidatorsWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_RecommendedValidatorsWireframeProtocol
     typealias Verification = __VerificationProxy_RecommendedValidatorsWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RecommendedValidatorsWireframeProtocol?

     func enableDefaultImplementation(_ stub: RecommendedValidatorsWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: RecommendedValidatorsViewProtocol?, result: PreparedNomination)  {
        
    return cuckoo_manager.call("proceed(from: RecommendedValidatorsViewProtocol?, result: PreparedNomination)",
            parameters: (view, result),
            escapingParameters: (view, result),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view, result: result))
        
    }
    
    
    
     func showRecommended(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo], maxTargets: Int)  {
        
    return cuckoo_manager.call("showRecommended(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo], maxTargets: Int)",
            parameters: (view, validators, maxTargets),
            escapingParameters: (view, validators, maxTargets),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showRecommended(from: view, validators: validators, maxTargets: maxTargets))
        
    }
    
    
    
     func showCustom(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])  {
        
    return cuckoo_manager.call("showCustom(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])",
            parameters: (view, validators),
            escapingParameters: (view, validators),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showCustom(from: view, validators: validators))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_RecommendedValidatorsWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, result: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RecommendedValidatorsViewProtocol?, PreparedNomination)> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == PreparedNomination {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, PreparedNomination)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: result) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsWireframeProtocol.self, method: "proceed(from: RecommendedValidatorsViewProtocol?, result: PreparedNomination)", parameterMatchers: matchers))
	    }
	    
	    func showRecommended<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, validators: M2, maxTargets: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo], Int)> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == [ElectedValidatorInfo], M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo], Int)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }, wrap(matchable: maxTargets) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsWireframeProtocol.self, method: "showRecommended(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo], maxTargets: Int)", parameterMatchers: matchers))
	    }
	    
	    func showCustom<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, validators: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo])> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == [ElectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo])>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsWireframeProtocol.self, method: "showCustom(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRecommendedValidatorsWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RecommendedValidatorsWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, result: M2) -> Cuckoo.__DoNotUse<(RecommendedValidatorsViewProtocol?, PreparedNomination), Void> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == PreparedNomination {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, PreparedNomination)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: result) { $0.1 }]
	        return cuckoo_manager.verify("proceed(from: RecommendedValidatorsViewProtocol?, result: PreparedNomination)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showRecommended<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, validators: M2, maxTargets: M3) -> Cuckoo.__DoNotUse<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo], Int), Void> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == [ElectedValidatorInfo], M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo], Int)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }, wrap(matchable: maxTargets) { $0.2 }]
	        return cuckoo_manager.verify("showRecommended(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo], maxTargets: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showCustom<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, validators: M2) -> Cuckoo.__DoNotUse<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo]), Void> where M1.OptionalMatchedType == RecommendedValidatorsViewProtocol, M2.MatchedType == [ElectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(RecommendedValidatorsViewProtocol?, [ElectedValidatorInfo])>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }]
	        return cuckoo_manager.verify("showCustom(from: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RecommendedValidatorsWireframeProtocolStub: RecommendedValidatorsWireframeProtocol {
    

    

    
     func proceed(from view: RecommendedValidatorsViewProtocol?, result: PreparedNomination)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showRecommended(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo], maxTargets: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showCustom(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import SoraFoundation


 class MockSelectedValidatorsViewProtocol: SelectedValidatorsViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SelectedValidatorsViewProtocol
    
     typealias Stubbing = __StubbingProxy_SelectedValidatorsViewProtocol
     typealias Verification = __VerificationProxy_SelectedValidatorsViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SelectedValidatorsViewProtocol?

     func enableDefaultImplementation(_ stub: SelectedValidatorsViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    

    

    
    
    
     func didReceive(viewModel: SelectedValidatorsViewModelProtocol)  {
        
    return cuckoo_manager.call("didReceive(viewModel: SelectedValidatorsViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(viewModel: viewModel))
        
    }
    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    

	 struct __StubbingProxy_SelectedValidatorsViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSelectedValidatorsViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSelectedValidatorsViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockSelectedValidatorsViewProtocol, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedValidatorsViewModelProtocol)> where M1.MatchedType == SelectedValidatorsViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedValidatorsViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectedValidatorsViewProtocol.self, method: "didReceive(viewModel: SelectedValidatorsViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectedValidatorsViewProtocol.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SelectedValidatorsViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(SelectedValidatorsViewModelProtocol), Void> where M1.MatchedType == SelectedValidatorsViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedValidatorsViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(viewModel: SelectedValidatorsViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SelectedValidatorsViewProtocolStub: SelectedValidatorsViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    

    

    
     func didReceive(viewModel: SelectedValidatorsViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSelectedValidatorsPresenterProtocol: SelectedValidatorsPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SelectedValidatorsPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_SelectedValidatorsPresenterProtocol
     typealias Verification = __VerificationProxy_SelectedValidatorsPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SelectedValidatorsPresenterProtocol?

     func enableDefaultImplementation(_ stub: SelectedValidatorsPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func selectedValidatorAt(index: Int)  {
        
    return cuckoo_manager.call("selectedValidatorAt(index: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectedValidatorAt(index: index))
        
    }
    

	 struct __StubbingProxy_SelectedValidatorsPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectedValidatorsPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func selectedValidatorAt<M1: Cuckoo.Matchable>(index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectedValidatorsPresenterProtocol.self, method: "selectedValidatorAt(index: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SelectedValidatorsPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectedValidatorAt<M1: Cuckoo.Matchable>(index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("selectedValidatorAt(index: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SelectedValidatorsPresenterProtocolStub: SelectedValidatorsPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectedValidatorAt(index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSelectedValidatorsWireframeProtocol: SelectedValidatorsWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SelectedValidatorsWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_SelectedValidatorsWireframeProtocol
     typealias Verification = __VerificationProxy_SelectedValidatorsWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SelectedValidatorsWireframeProtocol?

     func enableDefaultImplementation(_ stub: SelectedValidatorsWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showInformation(about validatorInfo: SelectedValidatorInfo, from view: SelectedValidatorsViewProtocol?)  {
        
    return cuckoo_manager.call("showInformation(about: SelectedValidatorInfo, from: SelectedValidatorsViewProtocol?)",
            parameters: (validatorInfo, view),
            escapingParameters: (validatorInfo, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showInformation(about: validatorInfo, from: view))
        
    }
    

	 struct __StubbingProxy_SelectedValidatorsWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showInformation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(about validatorInfo: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedValidatorInfo, SelectedValidatorsViewProtocol?)> where M1.MatchedType == SelectedValidatorInfo, M2.OptionalMatchedType == SelectedValidatorsViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedValidatorInfo, SelectedValidatorsViewProtocol?)>] = [wrap(matchable: validatorInfo) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectedValidatorsWireframeProtocol.self, method: "showInformation(about: SelectedValidatorInfo, from: SelectedValidatorsViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SelectedValidatorsWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showInformation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(about validatorInfo: M1, from view: M2) -> Cuckoo.__DoNotUse<(SelectedValidatorInfo, SelectedValidatorsViewProtocol?), Void> where M1.MatchedType == SelectedValidatorInfo, M2.OptionalMatchedType == SelectedValidatorsViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedValidatorInfo, SelectedValidatorsViewProtocol?)>] = [wrap(matchable: validatorInfo) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("showInformation(about: SelectedValidatorInfo, from: SelectedValidatorsViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SelectedValidatorsWireframeProtocolStub: SelectedValidatorsWireframeProtocol {
    

    

    
     func showInformation(about validatorInfo: SelectedValidatorInfo, from view: SelectedValidatorsViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import BigInt
import Foundation
import SoraFoundation


 class MockStakingConfirmViewProtocol: StakingConfirmViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingConfirmViewProtocol
    
     typealias Stubbing = __StubbingProxy_StakingConfirmViewProtocol
     typealias Verification = __VerificationProxy_StakingConfirmViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingConfirmViewProtocol?

     func enableDefaultImplementation(_ stub: StakingConfirmViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)  {
        
    return cuckoo_manager.call("didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)",
            parameters: (confirmationViewModel),
            escapingParameters: (confirmationViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(confirmationViewModel: confirmationViewModel))
        
    }
    
    
    
     func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)  {
        
    return cuckoo_manager.call("didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)",
            parameters: (assetViewModel),
            escapingParameters: (assetViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(assetViewModel: assetViewModel))
        
    }
    
    
    
     func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)  {
        
    return cuckoo_manager.call("didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)",
            parameters: (feeViewModel),
            escapingParameters: (feeViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(feeViewModel: feeViewModel))
        
    }
    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_StakingConfirmViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingConfirmViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingConfirmViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockStakingConfirmViewProtocol, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingConfirmViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingConfirmViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(confirmationViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(LocalizableResource<StakingConfirmViewModelProtocol>)> where M1.MatchedType == LocalizableResource<StakingConfirmViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<StakingConfirmViewModelProtocol>)>] = [wrap(matchable: confirmationViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(assetViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(LocalizableResource<AssetBalanceViewModelProtocol>)> where M1.MatchedType == LocalizableResource<AssetBalanceViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<AssetBalanceViewModelProtocol>)>] = [wrap(matchable: assetViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(feeViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(LocalizableResource<BalanceViewModelProtocol>?)> where M1.OptionalMatchedType == LocalizableResource<BalanceViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<BalanceViewModelProtocol>?)>] = [wrap(matchable: feeViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)", parameterMatchers: matchers))
	    }
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingConfirmViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(confirmationViewModel: M1) -> Cuckoo.__DoNotUse<(LocalizableResource<StakingConfirmViewModelProtocol>), Void> where M1.MatchedType == LocalizableResource<StakingConfirmViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<StakingConfirmViewModelProtocol>)>] = [wrap(matchable: confirmationViewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(assetViewModel: M1) -> Cuckoo.__DoNotUse<(LocalizableResource<AssetBalanceViewModelProtocol>), Void> where M1.MatchedType == LocalizableResource<AssetBalanceViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<AssetBalanceViewModelProtocol>)>] = [wrap(matchable: assetViewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(feeViewModel: M1) -> Cuckoo.__DoNotUse<(LocalizableResource<BalanceViewModelProtocol>?), Void> where M1.OptionalMatchedType == LocalizableResource<BalanceViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<BalanceViewModelProtocol>?)>] = [wrap(matchable: feeViewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingConfirmViewProtocolStub: StakingConfirmViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingConfirmPresenterProtocol: StakingConfirmPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingConfirmPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_StakingConfirmPresenterProtocol
     typealias Verification = __VerificationProxy_StakingConfirmPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingConfirmPresenterProtocol?

     func enableDefaultImplementation(_ stub: StakingConfirmPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func selectWalletAccount()  {
        
    return cuckoo_manager.call("selectWalletAccount()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectWalletAccount())
        
    }
    
    
    
     func selectPayoutAccount()  {
        
    return cuckoo_manager.call("selectPayoutAccount()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectPayoutAccount())
        
    }
    
    
    
     func selectValidators()  {
        
    return cuckoo_manager.call("selectValidators()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectValidators())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_StakingConfirmPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func selectWalletAccount() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmPresenterProtocol.self, method: "selectWalletAccount()", parameterMatchers: matchers))
	    }
	    
	    func selectPayoutAccount() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmPresenterProtocol.self, method: "selectPayoutAccount()", parameterMatchers: matchers))
	    }
	    
	    func selectValidators() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmPresenterProtocol.self, method: "selectValidators()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingConfirmPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectWalletAccount() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectWalletAccount()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectPayoutAccount() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectPayoutAccount()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectValidators() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectValidators()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingConfirmPresenterProtocolStub: StakingConfirmPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectWalletAccount()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectPayoutAccount()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectValidators()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingConfirmInteractorInputProtocol: StakingConfirmInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingConfirmInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_StakingConfirmInteractorInputProtocol
     typealias Verification = __VerificationProxy_StakingConfirmInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingConfirmInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: StakingConfirmInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func submitNomination(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])  {
        
    return cuckoo_manager.call("submitNomination(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])",
            parameters: (controller, amount, rewardDestination, targets),
            escapingParameters: (controller, amount, rewardDestination, targets),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.submitNomination(controller: controller, amount: amount, rewardDestination: rewardDestination, targets: targets))
        
    }
    
    
    
     func estimateFee(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])  {
        
    return cuckoo_manager.call("estimateFee(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])",
            parameters: (controller, amount, rewardDestination, targets),
            escapingParameters: (controller, amount, rewardDestination, targets),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.estimateFee(controller: controller, amount: amount, rewardDestination: rewardDestination, targets: targets))
        
    }
    

	 struct __StubbingProxy_StakingConfirmInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func submitNomination<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(controller: M1, amount: M2, rewardDestination: M3, targets: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])> where M1.MatchedType == AccountItem, M2.MatchedType == BigUInt, M3.MatchedType == RewardDestination, M4.MatchedType == [SelectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: amount) { $0.1 }, wrap(matchable: rewardDestination) { $0.2 }, wrap(matchable: targets) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorInputProtocol.self, method: "submitNomination(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])", parameterMatchers: matchers))
	    }
	    
	    func estimateFee<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(controller: M1, amount: M2, rewardDestination: M3, targets: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])> where M1.MatchedType == AccountItem, M2.MatchedType == BigUInt, M3.MatchedType == RewardDestination, M4.MatchedType == [SelectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: amount) { $0.1 }, wrap(matchable: rewardDestination) { $0.2 }, wrap(matchable: targets) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorInputProtocol.self, method: "estimateFee(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingConfirmInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func submitNomination<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(controller: M1, amount: M2, rewardDestination: M3, targets: M4) -> Cuckoo.__DoNotUse<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo]), Void> where M1.MatchedType == AccountItem, M2.MatchedType == BigUInt, M3.MatchedType == RewardDestination, M4.MatchedType == [SelectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: amount) { $0.1 }, wrap(matchable: rewardDestination) { $0.2 }, wrap(matchable: targets) { $0.3 }]
	        return cuckoo_manager.verify("submitNomination(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func estimateFee<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(controller: M1, amount: M2, rewardDestination: M3, targets: M4) -> Cuckoo.__DoNotUse<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo]), Void> where M1.MatchedType == AccountItem, M2.MatchedType == BigUInt, M3.MatchedType == RewardDestination, M4.MatchedType == [SelectedValidatorInfo] {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountItem, BigUInt, RewardDestination, [SelectedValidatorInfo])>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: amount) { $0.1 }, wrap(matchable: rewardDestination) { $0.2 }, wrap(matchable: targets) { $0.3 }]
	        return cuckoo_manager.verify("estimateFee(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingConfirmInteractorInputProtocolStub: StakingConfirmInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func submitNomination(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func estimateFee(controller: AccountItem, amount: BigUInt, rewardDestination: RewardDestination, targets: [SelectedValidatorInfo])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingConfirmInteractorOutputProtocol: StakingConfirmInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingConfirmInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_StakingConfirmInteractorOutputProtocol
     typealias Verification = __VerificationProxy_StakingConfirmInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingConfirmInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: StakingConfirmInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(price: PriceData?)  {
        
    return cuckoo_manager.call("didReceive(price: PriceData?)",
            parameters: (price),
            escapingParameters: (price),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(price: price))
        
    }
    
    
    
     func didReceive(priceError: Error)  {
        
    return cuckoo_manager.call("didReceive(priceError: Error)",
            parameters: (priceError),
            escapingParameters: (priceError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(priceError: priceError))
        
    }
    
    
    
     func didReceive(balance: DyAccountData?)  {
        
    return cuckoo_manager.call("didReceive(balance: DyAccountData?)",
            parameters: (balance),
            escapingParameters: (balance),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(balance: balance))
        
    }
    
    
    
     func didReceive(balanceError: Error)  {
        
    return cuckoo_manager.call("didReceive(balanceError: Error)",
            parameters: (balanceError),
            escapingParameters: (balanceError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(balanceError: balanceError))
        
    }
    
    
    
     func didStartNomination()  {
        
    return cuckoo_manager.call("didStartNomination()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartNomination())
        
    }
    
    
    
     func didCompleteNomination(txHash: String)  {
        
    return cuckoo_manager.call("didCompleteNomination(txHash: String)",
            parameters: (txHash),
            escapingParameters: (txHash),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteNomination(txHash: txHash))
        
    }
    
    
    
     func didFailNomination(error: Error)  {
        
    return cuckoo_manager.call("didFailNomination(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didFailNomination(error: error))
        
    }
    
    
    
     func didReceive(paymentInfo: RuntimeDispatchInfo)  {
        
    return cuckoo_manager.call("didReceive(paymentInfo: RuntimeDispatchInfo)",
            parameters: (paymentInfo),
            escapingParameters: (paymentInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(paymentInfo: paymentInfo))
        
    }
    
    
    
     func didReceive(feeError: Error)  {
        
    return cuckoo_manager.call("didReceive(feeError: Error)",
            parameters: (feeError),
            escapingParameters: (feeError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(feeError: feeError))
        
    }
    

	 struct __StubbingProxy_StakingConfirmInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(price: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PriceData?)> where M1.OptionalMatchedType == PriceData {
	        let matchers: [Cuckoo.ParameterMatcher<(PriceData?)>] = [wrap(matchable: price) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(price: PriceData?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(priceError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: priceError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(priceError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(balance: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(DyAccountData?)> where M1.OptionalMatchedType == DyAccountData {
	        let matchers: [Cuckoo.ParameterMatcher<(DyAccountData?)>] = [wrap(matchable: balance) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(balance: DyAccountData?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(balanceError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: balanceError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(balanceError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didStartNomination() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didStartNomination()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteNomination<M1: Cuckoo.Matchable>(txHash: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: txHash) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didCompleteNomination(txHash: String)", parameterMatchers: matchers))
	    }
	    
	    func didFailNomination<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didFailNomination(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(paymentInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeDispatchInfo)> where M1.MatchedType == RuntimeDispatchInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(RuntimeDispatchInfo)>] = [wrap(matchable: paymentInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(paymentInfo: RuntimeDispatchInfo)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(feeError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: feeError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmInteractorOutputProtocol.self, method: "didReceive(feeError: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingConfirmInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(price: M1) -> Cuckoo.__DoNotUse<(PriceData?), Void> where M1.OptionalMatchedType == PriceData {
	        let matchers: [Cuckoo.ParameterMatcher<(PriceData?)>] = [wrap(matchable: price) { $0 }]
	        return cuckoo_manager.verify("didReceive(price: PriceData?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(priceError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: priceError) { $0 }]
	        return cuckoo_manager.verify("didReceive(priceError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(balance: M1) -> Cuckoo.__DoNotUse<(DyAccountData?), Void> where M1.OptionalMatchedType == DyAccountData {
	        let matchers: [Cuckoo.ParameterMatcher<(DyAccountData?)>] = [wrap(matchable: balance) { $0 }]
	        return cuckoo_manager.verify("didReceive(balance: DyAccountData?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(balanceError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: balanceError) { $0 }]
	        return cuckoo_manager.verify("didReceive(balanceError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartNomination() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartNomination()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteNomination<M1: Cuckoo.Matchable>(txHash: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: txHash) { $0 }]
	        return cuckoo_manager.verify("didCompleteNomination(txHash: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didFailNomination<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didFailNomination(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(paymentInfo: M1) -> Cuckoo.__DoNotUse<(RuntimeDispatchInfo), Void> where M1.MatchedType == RuntimeDispatchInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(RuntimeDispatchInfo)>] = [wrap(matchable: paymentInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(paymentInfo: RuntimeDispatchInfo)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(feeError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: feeError) { $0 }]
	        return cuckoo_manager.verify("didReceive(feeError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingConfirmInteractorOutputProtocolStub: StakingConfirmInteractorOutputProtocol {
    

    

    
     func didReceive(price: PriceData?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(priceError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(balance: DyAccountData?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(balanceError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartNomination()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteNomination(txHash: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didFailNomination(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(paymentInfo: RuntimeDispatchInfo)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(feeError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingConfirmWireframeProtocol: StakingConfirmWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingConfirmWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_StakingConfirmWireframeProtocol
     typealias Verification = __VerificationProxy_StakingConfirmWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingConfirmWireframeProtocol?

     func enableDefaultImplementation(_ stub: StakingConfirmWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSelectedValidator(from view: StakingConfirmViewProtocol?, validators: [SelectedValidatorInfo], maxTargets: Int)  {
        
    return cuckoo_manager.call("showSelectedValidator(from: StakingConfirmViewProtocol?, validators: [SelectedValidatorInfo], maxTargets: Int)",
            parameters: (view, validators, maxTargets),
            escapingParameters: (view, validators, maxTargets),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSelectedValidator(from: view, validators: validators, maxTargets: maxTargets))
        
    }
    
    
    
     func complete(from view: StakingConfirmViewProtocol?)  {
        
    return cuckoo_manager.call("complete(from: StakingConfirmViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.complete(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_StakingConfirmWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSelectedValidator<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, validators: M2, maxTargets: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(StakingConfirmViewProtocol?, [SelectedValidatorInfo], Int)> where M1.OptionalMatchedType == StakingConfirmViewProtocol, M2.MatchedType == [SelectedValidatorInfo], M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingConfirmViewProtocol?, [SelectedValidatorInfo], Int)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }, wrap(matchable: maxTargets) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmWireframeProtocol.self, method: "showSelectedValidator(from: StakingConfirmViewProtocol?, validators: [SelectedValidatorInfo], maxTargets: Int)", parameterMatchers: matchers))
	    }
	    
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(StakingConfirmViewProtocol?)> where M1.OptionalMatchedType == StakingConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmWireframeProtocol.self, method: "complete(from: StakingConfirmViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingConfirmWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingConfirmWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSelectedValidator<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, validators: M2, maxTargets: M3) -> Cuckoo.__DoNotUse<(StakingConfirmViewProtocol?, [SelectedValidatorInfo], Int), Void> where M1.OptionalMatchedType == StakingConfirmViewProtocol, M2.MatchedType == [SelectedValidatorInfo], M3.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingConfirmViewProtocol?, [SelectedValidatorInfo], Int)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: validators) { $0.1 }, wrap(matchable: maxTargets) { $0.2 }]
	        return cuckoo_manager.verify("showSelectedValidator(from: StakingConfirmViewProtocol?, validators: [SelectedValidatorInfo], maxTargets: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func complete<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(StakingConfirmViewProtocol?), Void> where M1.OptionalMatchedType == StakingConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("complete(from: StakingConfirmViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingConfirmWireframeProtocolStub: StakingConfirmWireframeProtocol {
    

    

    
     func showSelectedValidator(from view: StakingConfirmViewProtocol?, validators: [SelectedValidatorInfo], maxTargets: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func complete(from view: StakingConfirmViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import CommonWallet
import Foundation
import SoraFoundation


 class MockStakingMainViewProtocol: StakingMainViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingMainViewProtocol
    
     typealias Stubbing = __StubbingProxy_StakingMainViewProtocol
     typealias Verification = __VerificationProxy_StakingMainViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingMainViewProtocol?

     func enableDefaultImplementation(_ stub: StakingMainViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    

    

    
    
    
     func didReceive(viewModel: StakingMainViewModelProtocol)  {
        
    return cuckoo_manager.call("didReceive(viewModel: StakingMainViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(viewModel: viewModel))
        
    }
    
    
    
     func didReceiveChainName(chainName newChainName: LocalizableResource<String>)  {
        
    return cuckoo_manager.call("didReceiveChainName(chainName: LocalizableResource<String>)",
            parameters: (newChainName),
            escapingParameters: (newChainName),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveChainName(chainName: newChainName))
        
    }
    
    
    
     func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)  {
        
    return cuckoo_manager.call("didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRecieveNetworkStakingInfo(viewModel: viewModel))
        
    }
    
    
    
     func didReceiveStakingState(viewModel: StakingViewState)  {
        
    return cuckoo_manager.call("didReceiveStakingState(viewModel: StakingViewState)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveStakingState(viewModel: viewModel))
        
    }
    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    

	 struct __StubbingProxy_StakingMainViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingMainViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockStakingMainViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockStakingMainViewProtocol, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(StakingMainViewModelProtocol)> where M1.MatchedType == StakingMainViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingMainViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainViewProtocol.self, method: "didReceive(viewModel: StakingMainViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveChainName<M1: Cuckoo.Matchable>(chainName newChainName: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(LocalizableResource<String>)> where M1.MatchedType == LocalizableResource<String> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<String>)>] = [wrap(matchable: newChainName) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainViewProtocol.self, method: "didReceiveChainName(chainName: LocalizableResource<String>)", parameterMatchers: matchers))
	    }
	    
	    func didRecieveNetworkStakingInfo<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(LocalizableResource<NetworkStakingInfoViewModelProtocol>)> where M1.MatchedType == LocalizableResource<NetworkStakingInfoViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<NetworkStakingInfoViewModelProtocol>)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainViewProtocol.self, method: "didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveStakingState<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(StakingViewState)> where M1.MatchedType == StakingViewState {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingViewState)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainViewProtocol.self, method: "didReceiveStakingState(viewModel: StakingViewState)", parameterMatchers: matchers))
	    }
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainViewProtocol.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingMainViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(StakingMainViewModelProtocol), Void> where M1.MatchedType == StakingMainViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingMainViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(viewModel: StakingMainViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveChainName<M1: Cuckoo.Matchable>(chainName newChainName: M1) -> Cuckoo.__DoNotUse<(LocalizableResource<String>), Void> where M1.MatchedType == LocalizableResource<String> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<String>)>] = [wrap(matchable: newChainName) { $0 }]
	        return cuckoo_manager.verify("didReceiveChainName(chainName: LocalizableResource<String>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRecieveNetworkStakingInfo<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(LocalizableResource<NetworkStakingInfoViewModelProtocol>), Void> where M1.MatchedType == LocalizableResource<NetworkStakingInfoViewModelProtocol> {
	        let matchers: [Cuckoo.ParameterMatcher<(LocalizableResource<NetworkStakingInfoViewModelProtocol>)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveStakingState<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(StakingViewState), Void> where M1.MatchedType == StakingViewState {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingViewState)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didReceiveStakingState(viewModel: StakingViewState)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingMainViewProtocolStub: StakingMainViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    

    

    
     func didReceive(viewModel: StakingMainViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveChainName(chainName newChainName: LocalizableResource<String>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveStakingState(viewModel: StakingViewState)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingMainPresenterProtocol: StakingMainPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingMainPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_StakingMainPresenterProtocol
     typealias Verification = __VerificationProxy_StakingMainPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingMainPresenterProtocol?

     func enableDefaultImplementation(_ stub: StakingMainPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func performMainAction()  {
        
    return cuckoo_manager.call("performMainAction()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.performMainAction())
        
    }
    
    
    
     func performAccountAction()  {
        
    return cuckoo_manager.call("performAccountAction()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.performAccountAction())
        
    }
    
    
    
     func updateAmount(_ newValue: Decimal)  {
        
    return cuckoo_manager.call("updateAmount(_: Decimal)",
            parameters: (newValue),
            escapingParameters: (newValue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateAmount(newValue))
        
    }
    
    
    
     func selectAmountPercentage(_ percentage: Float)  {
        
    return cuckoo_manager.call("selectAmountPercentage(_: Float)",
            parameters: (percentage),
            escapingParameters: (percentage),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectAmountPercentage(percentage))
        
    }
    

	 struct __StubbingProxy_StakingMainPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func performMainAction() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainPresenterProtocol.self, method: "performMainAction()", parameterMatchers: matchers))
	    }
	    
	    func performAccountAction() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainPresenterProtocol.self, method: "performAccountAction()", parameterMatchers: matchers))
	    }
	    
	    func updateAmount<M1: Cuckoo.Matchable>(_ newValue: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Decimal)> where M1.MatchedType == Decimal {
	        let matchers: [Cuckoo.ParameterMatcher<(Decimal)>] = [wrap(matchable: newValue) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainPresenterProtocol.self, method: "updateAmount(_: Decimal)", parameterMatchers: matchers))
	    }
	    
	    func selectAmountPercentage<M1: Cuckoo.Matchable>(_ percentage: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Float)> where M1.MatchedType == Float {
	        let matchers: [Cuckoo.ParameterMatcher<(Float)>] = [wrap(matchable: percentage) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainPresenterProtocol.self, method: "selectAmountPercentage(_: Float)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingMainPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func performMainAction() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("performMainAction()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func performAccountAction() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("performAccountAction()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateAmount<M1: Cuckoo.Matchable>(_ newValue: M1) -> Cuckoo.__DoNotUse<(Decimal), Void> where M1.MatchedType == Decimal {
	        let matchers: [Cuckoo.ParameterMatcher<(Decimal)>] = [wrap(matchable: newValue) { $0 }]
	        return cuckoo_manager.verify("updateAmount(_: Decimal)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectAmountPercentage<M1: Cuckoo.Matchable>(_ percentage: M1) -> Cuckoo.__DoNotUse<(Float), Void> where M1.MatchedType == Float {
	        let matchers: [Cuckoo.ParameterMatcher<(Float)>] = [wrap(matchable: percentage) { $0 }]
	        return cuckoo_manager.verify("selectAmountPercentage(_: Float)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingMainPresenterProtocolStub: StakingMainPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func performMainAction()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func performAccountAction()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func updateAmount(_ newValue: Decimal)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectAmountPercentage(_ percentage: Float)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingMainInteractorInputProtocol: StakingMainInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingMainInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_StakingMainInteractorInputProtocol
     typealias Verification = __VerificationProxy_StakingMainInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingMainInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: StakingMainInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_StakingMainInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingMainInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingMainInteractorInputProtocolStub: StakingMainInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingMainInteractorOutputProtocol: StakingMainInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingMainInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_StakingMainInteractorOutputProtocol
     typealias Verification = __VerificationProxy_StakingMainInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingMainInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: StakingMainInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(selectedAddress: String)  {
        
    return cuckoo_manager.call("didReceive(selectedAddress: String)",
            parameters: (selectedAddress),
            escapingParameters: (selectedAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(selectedAddress: selectedAddress))
        
    }
    
    
    
     func didReceive(price: PriceData?)  {
        
    return cuckoo_manager.call("didReceive(price: PriceData?)",
            parameters: (price),
            escapingParameters: (price),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(price: price))
        
    }
    
    
    
     func didReceive(priceError: Error)  {
        
    return cuckoo_manager.call("didReceive(priceError: Error)",
            parameters: (priceError),
            escapingParameters: (priceError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(priceError: priceError))
        
    }
    
    
    
     func didReceive(totalReward: TotalRewardItem)  {
        
    return cuckoo_manager.call("didReceive(totalReward: TotalRewardItem)",
            parameters: (totalReward),
            escapingParameters: (totalReward),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(totalReward: totalReward))
        
    }
    
    
    
     func didReceive(totalReward: Error)  {
        
    return cuckoo_manager.call("didReceive(totalReward: Error)",
            parameters: (totalReward),
            escapingParameters: (totalReward),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(totalReward: totalReward))
        
    }
    
    
    
     func didReceive(accountInfo: DyAccountInfo?)  {
        
    return cuckoo_manager.call("didReceive(accountInfo: DyAccountInfo?)",
            parameters: (accountInfo),
            escapingParameters: (accountInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(accountInfo: accountInfo))
        
    }
    
    
    
     func didReceive(balanceError: Error)  {
        
    return cuckoo_manager.call("didReceive(balanceError: Error)",
            parameters: (balanceError),
            escapingParameters: (balanceError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(balanceError: balanceError))
        
    }
    
    
    
     func didReceive(calculator: RewardCalculatorEngineProtocol)  {
        
    return cuckoo_manager.call("didReceive(calculator: RewardCalculatorEngineProtocol)",
            parameters: (calculator),
            escapingParameters: (calculator),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(calculator: calculator))
        
    }
    
    
    
     func didReceive(calculatorError: Error)  {
        
    return cuckoo_manager.call("didReceive(calculatorError: Error)",
            parameters: (calculatorError),
            escapingParameters: (calculatorError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(calculatorError: calculatorError))
        
    }
    
    
    
     func didReceive(stashItem: StashItem?)  {
        
    return cuckoo_manager.call("didReceive(stashItem: StashItem?)",
            parameters: (stashItem),
            escapingParameters: (stashItem),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(stashItem: stashItem))
        
    }
    
    
    
     func didReceive(stashItemError: Error)  {
        
    return cuckoo_manager.call("didReceive(stashItemError: Error)",
            parameters: (stashItemError),
            escapingParameters: (stashItemError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(stashItemError: stashItemError))
        
    }
    
    
    
     func didReceive(ledgerInfo: DyStakingLedger?)  {
        
    return cuckoo_manager.call("didReceive(ledgerInfo: DyStakingLedger?)",
            parameters: (ledgerInfo),
            escapingParameters: (ledgerInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(ledgerInfo: ledgerInfo))
        
    }
    
    
    
     func didReceive(ledgerInfoError: Error)  {
        
    return cuckoo_manager.call("didReceive(ledgerInfoError: Error)",
            parameters: (ledgerInfoError),
            escapingParameters: (ledgerInfoError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(ledgerInfoError: ledgerInfoError))
        
    }
    
    
    
     func didReceive(nomination: Nomination?)  {
        
    return cuckoo_manager.call("didReceive(nomination: Nomination?)",
            parameters: (nomination),
            escapingParameters: (nomination),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(nomination: nomination))
        
    }
    
    
    
     func didReceive(nominationError: Error)  {
        
    return cuckoo_manager.call("didReceive(nominationError: Error)",
            parameters: (nominationError),
            escapingParameters: (nominationError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(nominationError: nominationError))
        
    }
    
    
    
     func didReceive(validatorPrefs: ValidatorPrefs?)  {
        
    return cuckoo_manager.call("didReceive(validatorPrefs: ValidatorPrefs?)",
            parameters: (validatorPrefs),
            escapingParameters: (validatorPrefs),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(validatorPrefs: validatorPrefs))
        
    }
    
    
    
     func didReceive(validatorError: Error)  {
        
    return cuckoo_manager.call("didReceive(validatorError: Error)",
            parameters: (validatorError),
            escapingParameters: (validatorError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(validatorError: validatorError))
        
    }
    
    
    
     func didReceive(electionStatus: ElectionStatus?)  {
        
    return cuckoo_manager.call("didReceive(electionStatus: ElectionStatus?)",
            parameters: (electionStatus),
            escapingParameters: (electionStatus),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(electionStatus: electionStatus))
        
    }
    
    
    
     func didReceive(electionStatusError: Error)  {
        
    return cuckoo_manager.call("didReceive(electionStatusError: Error)",
            parameters: (electionStatusError),
            escapingParameters: (electionStatusError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(electionStatusError: electionStatusError))
        
    }
    
    
    
     func didReceive(eraStakersInfo: EraStakersInfo)  {
        
    return cuckoo_manager.call("didReceive(eraStakersInfo: EraStakersInfo)",
            parameters: (eraStakersInfo),
            escapingParameters: (eraStakersInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(eraStakersInfo: eraStakersInfo))
        
    }
    
    
    
     func didReceive(eraStakersInfoError: Error)  {
        
    return cuckoo_manager.call("didReceive(eraStakersInfoError: Error)",
            parameters: (eraStakersInfoError),
            escapingParameters: (eraStakersInfoError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(eraStakersInfoError: eraStakersInfoError))
        
    }
    
    
    
     func didReceive(networkStakingInfo: NetworkStakingInfo)  {
        
    return cuckoo_manager.call("didReceive(networkStakingInfo: NetworkStakingInfo)",
            parameters: (networkStakingInfo),
            escapingParameters: (networkStakingInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(networkStakingInfo: networkStakingInfo))
        
    }
    
    
    
     func didReceive(networkStakingInfoError: Error)  {
        
    return cuckoo_manager.call("didReceive(networkStakingInfoError: Error)",
            parameters: (networkStakingInfoError),
            escapingParameters: (networkStakingInfoError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(networkStakingInfoError: networkStakingInfoError))
        
    }
    
    
    
     func didReceive(payee: RewardDestinationArg?)  {
        
    return cuckoo_manager.call("didReceive(payee: RewardDestinationArg?)",
            parameters: (payee),
            escapingParameters: (payee),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(payee: payee))
        
    }
    
    
    
     func didReceive(payeeError: Error)  {
        
    return cuckoo_manager.call("didReceive(payeeError: Error)",
            parameters: (payeeError),
            escapingParameters: (payeeError),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(payeeError: payeeError))
        
    }
    
    
    
     func didReceive(newChain: Chain)  {
        
    return cuckoo_manager.call("didReceive(newChain: Chain)",
            parameters: (newChain),
            escapingParameters: (newChain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(newChain: newChain))
        
    }
    

	 struct __StubbingProxy_StakingMainInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(selectedAddress: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: selectedAddress) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(selectedAddress: String)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(price: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PriceData?)> where M1.OptionalMatchedType == PriceData {
	        let matchers: [Cuckoo.ParameterMatcher<(PriceData?)>] = [wrap(matchable: price) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(price: PriceData?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(priceError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: priceError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(priceError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(totalReward: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TotalRewardItem)> where M1.MatchedType == TotalRewardItem {
	        let matchers: [Cuckoo.ParameterMatcher<(TotalRewardItem)>] = [wrap(matchable: totalReward) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(totalReward: TotalRewardItem)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(totalReward: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: totalReward) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(totalReward: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(accountInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(DyAccountInfo?)> where M1.OptionalMatchedType == DyAccountInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(DyAccountInfo?)>] = [wrap(matchable: accountInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(accountInfo: DyAccountInfo?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(balanceError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: balanceError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(balanceError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(calculator: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RewardCalculatorEngineProtocol)> where M1.MatchedType == RewardCalculatorEngineProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RewardCalculatorEngineProtocol)>] = [wrap(matchable: calculator) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(calculator: RewardCalculatorEngineProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(calculatorError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: calculatorError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(calculatorError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(stashItem: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(StashItem?)> where M1.OptionalMatchedType == StashItem {
	        let matchers: [Cuckoo.ParameterMatcher<(StashItem?)>] = [wrap(matchable: stashItem) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(stashItem: StashItem?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(stashItemError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: stashItemError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(stashItemError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(ledgerInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(DyStakingLedger?)> where M1.OptionalMatchedType == DyStakingLedger {
	        let matchers: [Cuckoo.ParameterMatcher<(DyStakingLedger?)>] = [wrap(matchable: ledgerInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(ledgerInfo: DyStakingLedger?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(ledgerInfoError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: ledgerInfoError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(ledgerInfoError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(nomination: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Nomination?)> where M1.OptionalMatchedType == Nomination {
	        let matchers: [Cuckoo.ParameterMatcher<(Nomination?)>] = [wrap(matchable: nomination) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(nomination: Nomination?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(nominationError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: nominationError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(nominationError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(validatorPrefs: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ValidatorPrefs?)> where M1.OptionalMatchedType == ValidatorPrefs {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorPrefs?)>] = [wrap(matchable: validatorPrefs) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(validatorPrefs: ValidatorPrefs?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(validatorError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: validatorError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(validatorError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(electionStatus: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ElectionStatus?)> where M1.OptionalMatchedType == ElectionStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(ElectionStatus?)>] = [wrap(matchable: electionStatus) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(electionStatus: ElectionStatus?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(electionStatusError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: electionStatusError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(electionStatusError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(eraStakersInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EraStakersInfo)> where M1.MatchedType == EraStakersInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(EraStakersInfo)>] = [wrap(matchable: eraStakersInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(eraStakersInfo: EraStakersInfo)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(eraStakersInfoError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: eraStakersInfoError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(eraStakersInfoError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(networkStakingInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(NetworkStakingInfo)> where M1.MatchedType == NetworkStakingInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkStakingInfo)>] = [wrap(matchable: networkStakingInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(networkStakingInfo: NetworkStakingInfo)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(networkStakingInfoError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: networkStakingInfoError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(networkStakingInfoError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(payee: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RewardDestinationArg?)> where M1.OptionalMatchedType == RewardDestinationArg {
	        let matchers: [Cuckoo.ParameterMatcher<(RewardDestinationArg?)>] = [wrap(matchable: payee) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(payee: RewardDestinationArg?)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(payeeError: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: payeeError) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(payeeError: Error)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(newChain: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Chain)> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: newChain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainInteractorOutputProtocol.self, method: "didReceive(newChain: Chain)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingMainInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(selectedAddress: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: selectedAddress) { $0 }]
	        return cuckoo_manager.verify("didReceive(selectedAddress: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(price: M1) -> Cuckoo.__DoNotUse<(PriceData?), Void> where M1.OptionalMatchedType == PriceData {
	        let matchers: [Cuckoo.ParameterMatcher<(PriceData?)>] = [wrap(matchable: price) { $0 }]
	        return cuckoo_manager.verify("didReceive(price: PriceData?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(priceError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: priceError) { $0 }]
	        return cuckoo_manager.verify("didReceive(priceError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(totalReward: M1) -> Cuckoo.__DoNotUse<(TotalRewardItem), Void> where M1.MatchedType == TotalRewardItem {
	        let matchers: [Cuckoo.ParameterMatcher<(TotalRewardItem)>] = [wrap(matchable: totalReward) { $0 }]
	        return cuckoo_manager.verify("didReceive(totalReward: TotalRewardItem)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(totalReward: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: totalReward) { $0 }]
	        return cuckoo_manager.verify("didReceive(totalReward: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(accountInfo: M1) -> Cuckoo.__DoNotUse<(DyAccountInfo?), Void> where M1.OptionalMatchedType == DyAccountInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(DyAccountInfo?)>] = [wrap(matchable: accountInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(accountInfo: DyAccountInfo?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(balanceError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: balanceError) { $0 }]
	        return cuckoo_manager.verify("didReceive(balanceError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(calculator: M1) -> Cuckoo.__DoNotUse<(RewardCalculatorEngineProtocol), Void> where M1.MatchedType == RewardCalculatorEngineProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(RewardCalculatorEngineProtocol)>] = [wrap(matchable: calculator) { $0 }]
	        return cuckoo_manager.verify("didReceive(calculator: RewardCalculatorEngineProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(calculatorError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: calculatorError) { $0 }]
	        return cuckoo_manager.verify("didReceive(calculatorError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(stashItem: M1) -> Cuckoo.__DoNotUse<(StashItem?), Void> where M1.OptionalMatchedType == StashItem {
	        let matchers: [Cuckoo.ParameterMatcher<(StashItem?)>] = [wrap(matchable: stashItem) { $0 }]
	        return cuckoo_manager.verify("didReceive(stashItem: StashItem?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(stashItemError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: stashItemError) { $0 }]
	        return cuckoo_manager.verify("didReceive(stashItemError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(ledgerInfo: M1) -> Cuckoo.__DoNotUse<(DyStakingLedger?), Void> where M1.OptionalMatchedType == DyStakingLedger {
	        let matchers: [Cuckoo.ParameterMatcher<(DyStakingLedger?)>] = [wrap(matchable: ledgerInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(ledgerInfo: DyStakingLedger?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(ledgerInfoError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: ledgerInfoError) { $0 }]
	        return cuckoo_manager.verify("didReceive(ledgerInfoError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(nomination: M1) -> Cuckoo.__DoNotUse<(Nomination?), Void> where M1.OptionalMatchedType == Nomination {
	        let matchers: [Cuckoo.ParameterMatcher<(Nomination?)>] = [wrap(matchable: nomination) { $0 }]
	        return cuckoo_manager.verify("didReceive(nomination: Nomination?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(nominationError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: nominationError) { $0 }]
	        return cuckoo_manager.verify("didReceive(nominationError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(validatorPrefs: M1) -> Cuckoo.__DoNotUse<(ValidatorPrefs?), Void> where M1.OptionalMatchedType == ValidatorPrefs {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorPrefs?)>] = [wrap(matchable: validatorPrefs) { $0 }]
	        return cuckoo_manager.verify("didReceive(validatorPrefs: ValidatorPrefs?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(validatorError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: validatorError) { $0 }]
	        return cuckoo_manager.verify("didReceive(validatorError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(electionStatus: M1) -> Cuckoo.__DoNotUse<(ElectionStatus?), Void> where M1.OptionalMatchedType == ElectionStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(ElectionStatus?)>] = [wrap(matchable: electionStatus) { $0 }]
	        return cuckoo_manager.verify("didReceive(electionStatus: ElectionStatus?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(electionStatusError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: electionStatusError) { $0 }]
	        return cuckoo_manager.verify("didReceive(electionStatusError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(eraStakersInfo: M1) -> Cuckoo.__DoNotUse<(EraStakersInfo), Void> where M1.MatchedType == EraStakersInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(EraStakersInfo)>] = [wrap(matchable: eraStakersInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(eraStakersInfo: EraStakersInfo)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(eraStakersInfoError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: eraStakersInfoError) { $0 }]
	        return cuckoo_manager.verify("didReceive(eraStakersInfoError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(networkStakingInfo: M1) -> Cuckoo.__DoNotUse<(NetworkStakingInfo), Void> where M1.MatchedType == NetworkStakingInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(NetworkStakingInfo)>] = [wrap(matchable: networkStakingInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(networkStakingInfo: NetworkStakingInfo)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(networkStakingInfoError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: networkStakingInfoError) { $0 }]
	        return cuckoo_manager.verify("didReceive(networkStakingInfoError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(payee: M1) -> Cuckoo.__DoNotUse<(RewardDestinationArg?), Void> where M1.OptionalMatchedType == RewardDestinationArg {
	        let matchers: [Cuckoo.ParameterMatcher<(RewardDestinationArg?)>] = [wrap(matchable: payee) { $0 }]
	        return cuckoo_manager.verify("didReceive(payee: RewardDestinationArg?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(payeeError: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: payeeError) { $0 }]
	        return cuckoo_manager.verify("didReceive(payeeError: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(newChain: M1) -> Cuckoo.__DoNotUse<(Chain), Void> where M1.MatchedType == Chain {
	        let matchers: [Cuckoo.ParameterMatcher<(Chain)>] = [wrap(matchable: newChain) { $0 }]
	        return cuckoo_manager.verify("didReceive(newChain: Chain)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingMainInteractorOutputProtocolStub: StakingMainInteractorOutputProtocol {
    

    

    
     func didReceive(selectedAddress: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(price: PriceData?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(priceError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(totalReward: TotalRewardItem)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(totalReward: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(accountInfo: DyAccountInfo?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(balanceError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(calculator: RewardCalculatorEngineProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(calculatorError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(stashItem: StashItem?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(stashItemError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(ledgerInfo: DyStakingLedger?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(ledgerInfoError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(nomination: Nomination?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(nominationError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(validatorPrefs: ValidatorPrefs?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(validatorError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(electionStatus: ElectionStatus?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(electionStatusError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(eraStakersInfo: EraStakersInfo)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(eraStakersInfoError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(networkStakingInfo: NetworkStakingInfo)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(networkStakingInfoError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(payee: RewardDestinationArg?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(payeeError: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(newChain: Chain)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingMainWireframeProtocol: StakingMainWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingMainWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_StakingMainWireframeProtocol
     typealias Verification = __VerificationProxy_StakingMainWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingMainWireframeProtocol?

     func enableDefaultImplementation(_ stub: StakingMainWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?)  {
        
    return cuckoo_manager.call("showSetupAmount(from: StakingMainViewProtocol?, amount: Decimal?)",
            parameters: (view, amount),
            escapingParameters: (view, amount),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSetupAmount(from: view, amount: amount))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_StakingMainWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSetupAmount<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable>(from view: M1, amount: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(StakingMainViewProtocol?, Decimal?)> where M1.OptionalMatchedType == StakingMainViewProtocol, M2.OptionalMatchedType == Decimal {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingMainViewProtocol?, Decimal?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: amount) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainWireframeProtocol.self, method: "showSetupAmount(from: StakingMainViewProtocol?, amount: Decimal?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingMainWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingMainWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSetupAmount<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable>(from view: M1, amount: M2) -> Cuckoo.__DoNotUse<(StakingMainViewProtocol?, Decimal?), Void> where M1.OptionalMatchedType == StakingMainViewProtocol, M2.OptionalMatchedType == Decimal {
	        let matchers: [Cuckoo.ParameterMatcher<(StakingMainViewProtocol?, Decimal?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: amount) { $0.1 }]
	        return cuckoo_manager.verify("showSetupAmount(from: StakingMainViewProtocol?, amount: Decimal?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingMainWireframeProtocolStub: StakingMainWireframeProtocol {
    

    

    
     func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SoraFoundation


 class MockValidatorStakeInfoProtocol: ValidatorStakeInfoProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorStakeInfoProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorStakeInfoProtocol
     typealias Verification = __VerificationProxy_ValidatorStakeInfoProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorStakeInfoProtocol?

     func enableDefaultImplementation(_ stub: ValidatorStakeInfoProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var nominators: [NominatorInfo] {
        get {
            return cuckoo_manager.getter("nominators",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.nominators)
        }
        
    }
    
    
    
     var totalStake: Decimal {
        get {
            return cuckoo_manager.getter("totalStake",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.totalStake)
        }
        
    }
    
    
    
     var stakeReturn: Decimal {
        get {
            return cuckoo_manager.getter("stakeReturn",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.stakeReturn)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ValidatorStakeInfoProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var nominators: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorStakeInfoProtocol, [NominatorInfo]> {
	        return .init(manager: cuckoo_manager, name: "nominators")
	    }
	    
	    
	    var totalStake: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorStakeInfoProtocol, Decimal> {
	        return .init(manager: cuckoo_manager, name: "totalStake")
	    }
	    
	    
	    var stakeReturn: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorStakeInfoProtocol, Decimal> {
	        return .init(manager: cuckoo_manager, name: "stakeReturn")
	    }
	    
	    
	}

	 struct __VerificationProxy_ValidatorStakeInfoProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var nominators: Cuckoo.VerifyReadOnlyProperty<[NominatorInfo]> {
	        return .init(manager: cuckoo_manager, name: "nominators", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var totalStake: Cuckoo.VerifyReadOnlyProperty<Decimal> {
	        return .init(manager: cuckoo_manager, name: "totalStake", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var stakeReturn: Cuckoo.VerifyReadOnlyProperty<Decimal> {
	        return .init(manager: cuckoo_manager, name: "stakeReturn", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ValidatorStakeInfoProtocolStub: ValidatorStakeInfoProtocol {
    
    
     var nominators: [NominatorInfo] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([NominatorInfo]).self)
        }
        
    }
    
    
     var totalStake: Decimal {
        get {
            return DefaultValueRegistry.defaultValue(for: (Decimal).self)
        }
        
    }
    
    
     var stakeReturn: Decimal {
        get {
            return DefaultValueRegistry.defaultValue(for: (Decimal).self)
        }
        
    }
    

    

    
}



 class MockValidatorInfoProtocol: ValidatorInfoProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var address: String {
        get {
            return cuckoo_manager.getter("address",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.address)
        }
        
    }
    
    
    
     var identity: AccountIdentity? {
        get {
            return cuckoo_manager.getter("identity",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.identity)
        }
        
    }
    
    
    
     var stakeInfo: ValidatorStakeInfoProtocol? {
        get {
            return cuckoo_manager.getter("stakeInfo",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.stakeInfo)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ValidatorInfoProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var address: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorInfoProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "address")
	    }
	    
	    
	    var identity: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorInfoProtocol, AccountIdentity?> {
	        return .init(manager: cuckoo_manager, name: "identity")
	    }
	    
	    
	    var stakeInfo: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorInfoProtocol, ValidatorStakeInfoProtocol?> {
	        return .init(manager: cuckoo_manager, name: "stakeInfo")
	    }
	    
	    
	}

	 struct __VerificationProxy_ValidatorInfoProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var address: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "address", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var identity: Cuckoo.VerifyReadOnlyProperty<AccountIdentity?> {
	        return .init(manager: cuckoo_manager, name: "identity", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var stakeInfo: Cuckoo.VerifyReadOnlyProperty<ValidatorStakeInfoProtocol?> {
	        return .init(manager: cuckoo_manager, name: "stakeInfo", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ValidatorInfoProtocolStub: ValidatorInfoProtocol {
    
    
     var address: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var identity: AccountIdentity? {
        get {
            return DefaultValueRegistry.defaultValue(for: (AccountIdentity?).self)
        }
        
    }
    
    
     var stakeInfo: ValidatorStakeInfoProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (ValidatorStakeInfoProtocol?).self)
        }
        
    }
    

    

    
}



 class MockValidatorInfoViewProtocol: ValidatorInfoViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoViewProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoViewProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoViewProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return cuckoo_manager.getter("localizationManager",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager)
        }
        
        set {
            cuckoo_manager.setter("localizationManager",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.localizationManager = newValue)
        }
        
    }
    

    

    
    
    
     func didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol, extrasViewModel: [ValidatorInfoViewController.Section])  {
        
    return cuckoo_manager.call("didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol, extrasViewModel: [ValidatorInfoViewController.Section])",
            parameters: (accountViewModel, extrasViewModel),
            escapingParameters: (accountViewModel, extrasViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(accountViewModel: accountViewModel, extrasViewModel: extrasViewModel))
        
    }
    
    
    
    public func applyLocalization()  {
        
    return cuckoo_manager.call("applyLocalization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyLocalization())
        
    }
    

	 struct __StubbingProxy_ValidatorInfoViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorInfoViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockValidatorInfoViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var localizationManager: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockValidatorInfoViewProtocol, LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(accountViewModel: M1, extrasViewModel: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ValidatorInfoAccountViewModelProtocol, [ValidatorInfoViewController.Section])> where M1.MatchedType == ValidatorInfoAccountViewModelProtocol, M2.MatchedType == [ValidatorInfoViewController.Section] {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorInfoAccountViewModelProtocol, [ValidatorInfoViewController.Section])>] = [wrap(matchable: accountViewModel) { $0.0 }, wrap(matchable: extrasViewModel) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoViewProtocol.self, method: "didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol, extrasViewModel: [ValidatorInfoViewController.Section])", parameterMatchers: matchers))
	    }
	    
	    func applyLocalization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoViewProtocol.self, method: "applyLocalization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorInfoViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var localizationManager: Cuckoo.VerifyOptionalProperty<LocalizationManagerProtocol> {
	        return .init(manager: cuckoo_manager, name: "localizationManager", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(accountViewModel: M1, extrasViewModel: M2) -> Cuckoo.__DoNotUse<(ValidatorInfoAccountViewModelProtocol, [ValidatorInfoViewController.Section]), Void> where M1.MatchedType == ValidatorInfoAccountViewModelProtocol, M2.MatchedType == [ValidatorInfoViewController.Section] {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorInfoAccountViewModelProtocol, [ValidatorInfoViewController.Section])>] = [wrap(matchable: accountViewModel) { $0.0 }, wrap(matchable: extrasViewModel) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol, extrasViewModel: [ValidatorInfoViewController.Section])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyLocalization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("applyLocalization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorInfoViewProtocolStub: ValidatorInfoViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
    public var localizationManager: LocalizationManagerProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (LocalizationManagerProtocol?).self)
        }
        
        set { }
        
    }
    

    

    
     func didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol, extrasViewModel: [ValidatorInfoViewController.Section])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func applyLocalization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockValidatorInfoInteractorInputProtocol: ValidatorInfoInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoInteractorInputProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    

	 struct __StubbingProxy_ValidatorInfoInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorInfoInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorInfoInteractorInputProtocolStub: ValidatorInfoInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockValidatorInfoInteractorOutputProtocol: ValidatorInfoInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoInteractorOutputProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(validatorInfo: ValidatorInfoProtocol)  {
        
    return cuckoo_manager.call("didReceive(validatorInfo: ValidatorInfoProtocol)",
            parameters: (validatorInfo),
            escapingParameters: (validatorInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(validatorInfo: validatorInfo))
        
    }
    

	 struct __StubbingProxy_ValidatorInfoInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(validatorInfo: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ValidatorInfoProtocol)> where M1.MatchedType == ValidatorInfoProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorInfoProtocol)>] = [wrap(matchable: validatorInfo) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoInteractorOutputProtocol.self, method: "didReceive(validatorInfo: ValidatorInfoProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorInfoInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(validatorInfo: M1) -> Cuckoo.__DoNotUse<(ValidatorInfoProtocol), Void> where M1.MatchedType == ValidatorInfoProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ValidatorInfoProtocol)>] = [wrap(matchable: validatorInfo) { $0 }]
	        return cuckoo_manager.verify("didReceive(validatorInfo: ValidatorInfoProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorInfoInteractorOutputProtocolStub: ValidatorInfoInteractorOutputProtocol {
    

    

    
     func didReceive(validatorInfo: ValidatorInfoProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockValidatorInfoPresenterProtocol: ValidatorInfoPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoPresenterProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoPresenterProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func presentAccountOptions()  {
        
    return cuckoo_manager.call("presentAccountOptions()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAccountOptions())
        
    }
    
    
    
     func presentTotalStake()  {
        
    return cuckoo_manager.call("presentTotalStake()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentTotalStake())
        
    }
    
    
    
     func activateEmail()  {
        
    return cuckoo_manager.call("activateEmail()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateEmail())
        
    }
    
    
    
     func activateWeb()  {
        
    return cuckoo_manager.call("activateWeb()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateWeb())
        
    }
    
    
    
     func activateTwitter()  {
        
    return cuckoo_manager.call("activateTwitter()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateTwitter())
        
    }
    
    
    
     func activateRiotName()  {
        
    return cuckoo_manager.call("activateRiotName()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateRiotName())
        
    }
    

	 struct __StubbingProxy_ValidatorInfoPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func presentAccountOptions() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "presentAccountOptions()", parameterMatchers: matchers))
	    }
	    
	    func presentTotalStake() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "presentTotalStake()", parameterMatchers: matchers))
	    }
	    
	    func activateEmail() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "activateEmail()", parameterMatchers: matchers))
	    }
	    
	    func activateWeb() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "activateWeb()", parameterMatchers: matchers))
	    }
	    
	    func activateTwitter() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "activateTwitter()", parameterMatchers: matchers))
	    }
	    
	    func activateRiotName() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoPresenterProtocol.self, method: "activateRiotName()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorInfoPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentAccountOptions() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("presentAccountOptions()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentTotalStake() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("presentTotalStake()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateEmail() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateEmail()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateWeb() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateWeb()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateTwitter() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateTwitter()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateRiotName() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateRiotName()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorInfoPresenterProtocolStub: ValidatorInfoPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentAccountOptions()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentTotalStake()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateEmail()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateWeb()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateTwitter()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateRiotName()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockValidatorInfoWireframeProtocol: ValidatorInfoWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ValidatorInfoWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ValidatorInfoWireframeProtocol
     typealias Verification = __VerificationProxy_ValidatorInfoWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ValidatorInfoWireframeProtocol?

     func enableDefaultImplementation(_ stub: ValidatorInfoWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_ValidatorInfoWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockValidatorInfoWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ValidatorInfoWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ValidatorInfoWireframeProtocolStub: ValidatorInfoWireframeProtocol {
    

    

    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import SoraFoundation


 class MockUsernameSetupViewProtocol: UsernameSetupViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupViewProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupViewProtocol
     typealias Verification = __VerificationProxy_UsernameSetupViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupViewProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(viewModel: viewModel))
        
    }
    

	 struct __StubbingProxy_UsernameSetupViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUsernameSetupViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUsernameSetupViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupViewProtocol.self, method: "set(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("set(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupViewProtocolStub: UsernameSetupViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUsernameSetupPresenterProtocol: UsernameSetupPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupPresenterProtocol
     typealias Verification = __VerificationProxy_UsernameSetupPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupPresenterProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_UsernameSetupPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupPresenterProtocolStub: UsernameSetupPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUsernameSetupWireframeProtocol: UsernameSetupWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupWireframeProtocol
     typealias Verification = __VerificationProxy_UsernameSetupWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupWireframeProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: UsernameSetupViewProtocol?, username: String)  {
        
    return cuckoo_manager.call("proceed(from: UsernameSetupViewProtocol?, username: String)",
            parameters: (view, username),
            escapingParameters: (view, username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view, username: username))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_UsernameSetupWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, username: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UsernameSetupViewProtocol?, String)> where M1.OptionalMatchedType == UsernameSetupViewProtocol, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(UsernameSetupViewProtocol?, String)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: username) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "proceed(from: UsernameSetupViewProtocol?, username: String)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, username: M2) -> Cuckoo.__DoNotUse<(UsernameSetupViewProtocol?, String), Void> where M1.OptionalMatchedType == UsernameSetupViewProtocol, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(UsernameSetupViewProtocol?, String)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: username) { $0.1 }]
	        return cuckoo_manager.verify("proceed(from: UsernameSetupViewProtocol?, username: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupWireframeProtocolStub: UsernameSetupWireframeProtocol {
    

    

    
     func proceed(from view: UsernameSetupViewProtocol?, username: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}

