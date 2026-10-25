# SSFRuntimeCodingService

[![CI Status](https://img.shields.io/travis/Radmir Dzhurabaev/SSFRuntimeCodingService.svg?style=flat)](https://travis-ci.org/Radmir Dzhurabaev/SSFRuntimeCodingService)
[![Version](https://img.shields.io/cocoapods/v/SSFRuntimeCodingService.svg?style=flat)](https://cocoapods.org/pods/SSFRuntimeCodingService)
[![License](https://img.shields.io/cocoapods/l/SSFRuntimeCodingService.svg?style=flat)](https://cocoapods.org/pods/SSFRuntimeCodingService)
[![Platform](https://img.shields.io/cocoapods/p/SSFRuntimeCodingService.svg?style=flat)](https://cocoapods.org/pods/SSFRuntimeCodingService)

## Description

SSFRuntimeCodingService provides ability to interact with chain's metadata in convenient way. It takes raw chain metadata as input and build easy-to-use native representation. You can encode and decode SCALE format, and also surf through chain's runtime metadata using this library.

### Components - Interfaces

```
public protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { get }

    func setup()
    func readySnapshot() async throws -> RuntimeSnapshot
    func cleanup()
    func fetchCoderFactoryOperation(
        with timeout: TimeInterval,
        closure: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol>
}
```

### Components - Implementations

RuntimeProvider - basic implementation of RuntimeProviderProtocol/RuntimeCodingServiceProtocol. Takes raw metadata as input, makes runtime snapshot.

```
// operationQueue - Queue used for internal operations executing
// usedRuntimePaths - Map that used for filter raw metadata and build runtime snapshot only for methods/types used in project
// chainMetadata - instance of RuntimeMetadataItemProtocol. Representation of raw metadata, consists of chain's genesis hash, metadata spec version, metadata transactionVersion, and raw metadata byte array
// chainTypes - specific runtime types for chains (see example https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/all_chains_types.json)

    public init(
        operationQueue: OperationQueue,
        usedRuntimePaths: [String: [String]],
        chainMetadata: RuntimeMetadataItemProtocol,
        chainTypes: Data
    )
```


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SSFRuntimeCodingService is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SSFRuntimeCodingService'
```

## Author

Radmir Dzhurabaev, dzhurabaev@soramitsu.co.jp

## License

SSFRuntimeCodingService is available under Apache-2.0 OR MIT, at your option. See [LICENSE](LICENSE) for the license choices and original notices.
