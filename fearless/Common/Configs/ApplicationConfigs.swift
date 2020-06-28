import Foundation
import os

protocol ApplicationConfigProtocol {}

final class ApplicationConfig {
    static let shared: ApplicationConfig! = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {}
