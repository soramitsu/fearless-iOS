import Foundation

enum TypeRegistryCatalogError: Error {
    case missingVersioning
    case missingCurrentVersion
    case missingNetworkTypes
    case duplicatedVersioning
}

public protocol TypeRegistryCatalogProtocol {
    func node(for typeName: String, version: UInt64) -> Node?
    func override(for moduleName: String, constantName: String, version: UInt64) -> String?
    func replacingRuntimeMetadata(
        _ newMetadata: RuntimeMetadata,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalogProtocol
}

/**
 *  Class is designed to provide an interface to access different versions of the type
 *  definition graphs.
 */

public class TypeRegistryCatalog: TypeRegistryCatalogProtocol {
    public let runtimeMetadataRegistry: TypeRegistryProtocol
    public let baseRegistry: TypeRegistryProtocol
    public let versionedRegistries: [UInt64: TypeRegistryProtocol]
    public let typeResolver: TypeResolving

    public lazy var versionedTypes: [String: [UInt64]] = {
        let versionedTypes = allVersions.reduce(into: [String: [UInt64]]()) { result, item in
            guard let typeRegistry = versionedRegistries[item] else { return }

            let typeNames = typeRegistry.registeredTypeNames
                .filter { !(typeRegistry.node(for: $0) is GenericNode) }

            for typeName in typeNames {
                let versions: [UInt64] = result[typeName] ?? []

                if versions.last != item {
                    result[typeName] = versions + [item]
                }
            }
        }

        return versionedTypes
    }()

    public lazy var versionedOverrides: [ConstantPath: [UInt64]] = {
        let versionedOverrides = allVersions
            .reduce(into: [ConstantPath: [UInt64]]()) { result, item in
                guard let typeRegistry = versionedRegistries[item] else { return }
                for constantPath in typeRegistry.registeredOverrides {
                    let versions: [UInt64] = result[constantPath] ?? []

                    if versions.last != item {
                        result[constantPath] = versions + [item]
                    }
                }
            }

        return versionedOverrides
    }()

    public lazy var allTypes: Set<String> = Set(versionedTypes.keys)

    public let mutex = NSLock()
    public var registryCache: [String: TypeRegistryProtocol] = [:]
    private let allVersions: [Dictionary<UInt64, TypeRegistryProtocol>.Keys.Element]

    public init(
        baseRegistry: TypeRegistryProtocol,
        versionedRegistries: [UInt64: TypeRegistryProtocol],
        runtimeMetadataRegistry: TypeRegistryProtocol,
        typeResolver: TypeResolving
    ) {
        self.baseRegistry = baseRegistry
        self.versionedRegistries = versionedRegistries
        self.runtimeMetadataRegistry = runtimeMetadataRegistry
        self.typeResolver = typeResolver
        allVersions = versionedRegistries.keys.sorted()
    }

    public func node(for typeName: String, version: UInt64) -> Node? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let cacheKey = "\(typeName)_\(version)"

        if let registry = registryCache[cacheKey], let node = registry.node(for: typeName) {
            return node
        }

        let registry = getRegistry(for: typeName, version: version)
        return fallbackToRuntimeMetadataIfNeeded(
            from: registry,
            typeName: typeName,
            cacheKey: cacheKey
        )
    }

    public func override(for moduleName: String, constantName: String, version: UInt64) -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let cacheKey = "\(moduleName)_\(constantName)"

        if let registry = registryCache[cacheKey], let override = registry.override(
            for: moduleName,
            constantName: constantName
        ) {
            return override
        }

        let registry = getRegistry(for: moduleName, constantName: constantName, version: version)
        if let override = registry.override(for: moduleName, constantName: constantName) {
            registryCache[cacheKey] = registry
            return override
        }

        return nil
    }

    public func replacingRuntimeMetadata(
        _ newMetadata: RuntimeMetadata,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalogProtocol {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        registryCache = [:]

        let newRuntimeRegistry = try TypeRegistry.createFromRuntimeMetadata(
            newMetadata,
            usedRuntimePaths: usedRuntimePaths
        )

        return TypeRegistryCatalog(
            baseRegistry: baseRegistry,
            versionedRegistries: versionedRegistries,
            runtimeMetadataRegistry: newRuntimeRegistry,
            typeResolver: typeResolver
        )
    }

    // MARK: Nodes private

    private func getRegistry(for typeName: String, version: UInt64) -> TypeRegistryProtocol {
        let versions: [UInt64]

        if let typeVersions = versionedTypes[typeName] {
            versions = typeVersions
        } else if let resolvedName = typeResolver.resolve(typeName: typeName, using: allTypes) {
            versions = versionedTypes[resolvedName] ?? []
        } else {
            versions = []
        }

        guard let minVersion = versions.reversed().first(where: { $0 <= version }) else {
            return baseRegistry
        }

        return versionedRegistries[minVersion] ?? baseRegistry
    }

    private func fallbackToRuntimeMetadataIfNeeded(
        from registry: TypeRegistryProtocol,
        typeName: String,
        cacheKey: String
    ) -> Node? {
        if let node = registry.node(for: typeName) {
            registryCache[cacheKey] = registry
            return node
        }

        registryCache[cacheKey] = runtimeMetadataRegistry
        return runtimeMetadataRegistry.node(for: typeName)
    }

    // MARK: Overrides private

    private func getRegistry(
        for moduleName: String,
        constantName: String,
        version: UInt64
    ) -> TypeRegistryProtocol {
        let versions: [UInt64]
        let constantPath = ConstantPath(moduleName: moduleName, constantName: constantName)

        if let typeVersions = versionedOverrides[constantPath] {
            versions = typeVersions
        } else {
            versions = []
        }

        guard let minVersion = versions.reversed().first(where: { $0 <= version }) else {
            return baseRegistry
        }

        return versionedRegistries[minVersion] ?? baseRegistry
    }
}
