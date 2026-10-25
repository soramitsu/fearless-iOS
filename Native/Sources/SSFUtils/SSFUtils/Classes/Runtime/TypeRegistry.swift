import BigInt
import Foundation

public enum TypeRegistryError: Error {
    case unexpectedJson
    case invalidKey(String)
}

public struct ConstantPath: Hashable {
    let moduleName: String
    let constantName: String

    public init(moduleName: String, constantName: String) {
        self.moduleName = moduleName
        self.constantName = constantName
    }
}
// sourcery: AutoMockable
public protocol TypeRegistryProtocol {
    var registeredTypes: [Node] { get }
    var registeredTypeNames: Set<String> { get }
    var registeredOverrides: Set<ConstantPath> { get }

    func node(for key: String) -> Node?
    func override(for moduleName: String, constantName: String) -> String?
}

protocol TypeRegistering {
    func register(typeName: String, json: JSON) -> Node
    func register(typeName: String, node: Node) -> Node
}

/**
 *  Class is designed to store types definitions used in Substrate Runtime
 *  and described by a json. The implementation parses the json and
 *  tries to construct a graph. Each node of the graph is identified by type's name
 *  and describes type's specifics such as which fields are there and on which types it depends on.
 *  Each node is create by a corresponding factory which uses specific parser to process type definitions.
 *
 *  Currently the following types are supported:
 *  - Structure (an ordered collection of fields)
 *  - Enum mapping (custom type with named set of values)
 *  - Enum collection (custom type with a list of values)
 *  - Numeric set (a name set represented by a bit vector)
 *  - Vector (unbounded list of values)
 *  - Option (optional value)
 *  - Compact (special type for compact representation of the integer)
 *  - Fixed array (a list of values with a given length)
 *  - Alias (just a term that represents an alias to other type)
 *
 *  The main purpose of the registry is to support SCALE coding/decoding in the runtime
 *  with ability to allow type definitions updates.
 */

public class TypeRegistry: TypeRegistryProtocol {
    private var graph: [String: Node] = [:]
    private var nodeFactory: TypeNodeFactoryProtocol
    private var typeResolver: TypeResolving
    private var resolutionCache: [String: String] = [:]
    private var allKeys: Set<String> = []
    private var allOverrides: Set<ConstantPath> = []

    private var overrides: [ConstantPath: String] = [:]

    private let json: JSON
    private let overridesJson: [JSON]?
    private let additionalNodes: [Node]

    public lazy var registeredTypes: [Node] = {
        resolveJsons()
        return graph.keys.compactMap { graph[$0] }
    }()

    public lazy var registeredTypeNames: Set<String> = {
        resolveJsons()
        return allKeys
    }()

    public lazy var registeredOverrides: Set<ConstantPath> = {
        resolveJsons()
        return allOverrides
    }()

    init(
        json: JSON,
        overrides: [JSON]?,
        nodeFactory: TypeNodeFactoryProtocol,
        typeResolver: TypeResolving,
        additionalNodes: [Node]
    ) throws {
        self.nodeFactory = nodeFactory
        self.typeResolver = typeResolver
        self.json = json
        overridesJson = overrides
        self.additionalNodes = additionalNodes
    }

    public func node(for key: String) -> Node? {
        resolveJsons()

        if let node = graph[key] {
            return node
        }

        if let resolvedKey = resolutionCache[key], let node = graph[resolvedKey] {
            return node
        }

        if let resolvedKey = typeResolver.resolve(typeName: key, using: allKeys) {
            resolutionCache[key] = resolvedKey
            if let node = graph[resolvedKey] {
                return node
            }

            return try? nodeFactory.buildNode(
                from: .stringValue(key),
                typeName: key,
                mediator: self
            )
        }

        return nil
    }

    public func override(for moduleName: String, constantName: String) -> String? {
        resolveJsons()
        return overrides[.init(moduleName: moduleName, constantName: constantName)]
    }

    // MARK: Private

    private func resolveJsons() {
        guard graph.keys.isEmpty else {
            return
        }
        parse(json: json)
        parse(overrides: overridesJson)
        override(nodes: additionalNodes)
        resolveGenerics()

        allKeys = Set(graph.keys)
        allOverrides = Set(overrides.keys)
    }

    private func override(nodes: [Node]) {
        for node in nodes {
            graph[node.typeName] = node
        }
    }

    private func parse(overrides: [JSON]?) {
        guard let modules = overrides else { return }

        for module in modules {
            guard let moduleName = module["module"]?.stringValue else { continue }
            guard let constants = module["constants"]?.arrayValue else { continue }

            for constant in constants {
                guard let constantName = constant["name"]?.stringValue else { continue }
                guard let value = constant["value"]?.stringValue else { continue }

                self.overrides[.init(moduleName: moduleName, constantName: constantName)] = value
            }
        }
    }

    private func parse(json: JSON) {
        guard let dict = json.dictValue else {
            return
        }

        let keyParser = TermParser.generic()

        let refinedDict = dict.reduce(into: [String: JSON]()) { result, item in
            if let type = keyParser.parse(json: .stringValue(item.key))?.first?.stringValue {
                result[type] = item.value
            }
        }

        for typeName in refinedDict.keys {
            graph[typeName] = GenericNode(typeName: typeName)
        }

        for item in refinedDict {
            if let node = try? nodeFactory.buildNode(
                from: item.value,
                typeName: item.key,
                mediator: self
            ) {
                graph[item.key] = node
            }
        }
    }

    private func resolveGenerics() {
        let allTypeNames = Set(graph.keys)

        let genericTypeNames = allTypeNames.filter { graph[$0] is GenericNode }
        let nonGenericTypeNames = allTypeNames.subtracting(genericTypeNames)

        for genericTypeName in genericTypeNames {
            if let resolvedKey = typeResolver.resolve(
                typeName: genericTypeName,
                using: nonGenericTypeNames
            ) {
                graph[genericTypeName] = ProxyNode(typeName: resolvedKey, resolver: self)
            }
        }
    }
}

extension TypeRegistry: TypeRegistering {
    func register(typeName: String, json: JSON) -> Node {
        let proxy = ProxyNode(typeName: typeName, resolver: self)

        guard graph[typeName] == nil else {
            return proxy
        }

        graph[typeName] = GenericNode(typeName: typeName)

        if let node = try? nodeFactory.buildNode(from: json, typeName: typeName, mediator: self) {
            return register(typeName: typeName, node: node)
        }

        return proxy
    }

    func register(typeName: String, node: Node) -> Node {
        graph[typeName] = node
        return ProxyNode(typeName: typeName, resolver: self)
    }
}

extension TypeRegistry: NodeResolver {
    public func resolve(for key: String) -> Node? { graph[key] }
}
