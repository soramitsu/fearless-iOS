//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPTransport.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/23/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

#if canImport(Network)
import Foundation
import Network

public enum TCPTransportError: Error {
    case invalidRequest
}

@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class TCPTransport: AuthorizedTransport, ConnectionEventSerializing, ConnectionBoundTransport {
    // The outer event lock serializes lifecycle and callback admission. It is
    // deliberately distinct from the final writer context lock. Never invoke
    // an engine/delegate while holding writeContextLock.
    private let eventLock = NSRecursiveLock()
    private let writeContextLock = NSLock()
    private let queue = DispatchQueue(label: "com.vluxe.starscream.networkstream")
    private weak var delegate: TransportEventClient?
    private var context: EventContext?
    private var connection: NWConnection? // writeContextLock
    private var isTLS = false // writeContextLock
    private var writeContext: EventContext? // writeContextLock

    internal final class EventContext {
        let connection: NWConnection
        let generation: ConnectionGeneration
        init(connection: NWConnection, generation: ConnectionGeneration) {
            self.connection = connection
            self.generation = generation
        }
    }

    /// Narrow source-test seam: production always calls NWConnection.receive.
    internal var receiveOverride: ((NWConnection, @escaping (Data?, Bool, NWError?) -> Void) -> Void)?

    public var usingTLS: Bool {
        writeContextLock.lock(); defer { writeContextLock.unlock() }
        return isTLS
    }

    public init(connection: NWConnection) {
        withConnectionEvents {
            let current = EventContext(connection: connection, generation: ConnectionGeneration())
            install(current, tls: false)
            start(current)
        }
    }

    public init() {}

    internal func withConnectionEvents(_ action: () -> Void) {
        eventLock.lock(); defer { eventLock.unlock() }
        action()
    }

    public func connect(url: URL, timeout: Double = 10, certificatePinning: CertificatePinning? = nil) {
        withConnectionEvents {
            retireCurrent()
            guard let parts = url.getParts(), let port = UInt16(exactly: parts.port) else {
                delegate?.connectionChanged(state: .failed(TCPTransportError.invalidRequest))
                return
            }
            let generation = ConnectionGeneration()
            let options = NWProtocolTCP.Options()
            options.connectionTimeout = Int(timeout.rounded(.up))
            let tlsOptions = parts.isTLS ? NWProtocolTLS.Options() : nil
            if let tlsOptions = tlsOptions {
                sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { [weak self] (_, secTrust, complete) in
                    let once = TLSCompletion(complete)
                    guard let transport = self else { once.finish(false); return }
                    let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()
                    guard let pinner = certificatePinning else {
                        transport.finishVerification(.success, generation: generation, completion: once)
                        return
                    }
                    pinner.evaluateTrust(trust: trust, domain: parts.host) { [weak transport] state in
                        guard let transport = transport else { once.finish(false); return }
                        transport.finishVerification(state, generation: generation, completion: once)
                    }
                }, queue)
            }
            let parameters = NWParameters(tls: tlsOptions, tcp: options)
            let conn = NWConnection(host: NWEndpoint.Host.name(parts.host, nil), port: NWEndpoint.Port(rawValue: port)!, using: parameters)
            let current = EventContext(connection: conn, generation: generation)
            install(current, tls: parts.isTLS)
            start(current)
        }
    }

    public func disconnect() { withConnectionEvents { retireCurrent() } }

    public func register(delegate: TransportEventClient) {
        withConnectionEvents { self.delegate = delegate }
    }

    private func install(_ current: EventContext, tls: Bool) {
        context = current
        writeContextLock.lock()
        connection = current.connection
        writeContext = nil
        isTLS = tls
        writeContextLock.unlock()
    }

    private func retireCurrent() {
        let previous = context
        previous?.generation.retire()
        context = nil
        writeContextLock.lock()
        connection = nil
        writeContext = nil
        writeContextLock.unlock()
        previous?.connection.cancel()
    }

    public func write(data: Data, completion: @escaping (Error?) -> Void) {
        writeContextLock.lock()
        let current = connection
        writeContextLock.unlock()
        // Legacy writes retain their API, but bind to the captured connection
        // instead of looking up a replacement from a later completion/read.
        current?.send(content: data, completion: .contentProcessed(completion))
    }

    internal func captureWriteContext() -> AnyObject? {
        writeContextLock.lock(); defer { writeContextLock.unlock() }
        guard let current = writeContext, case .ready = current.connection.state else { return nil }
        return current
    }

    internal func writeConnectionBound(data: Data, context: AnyObject, completion: @escaping (Error?) -> Void) {
        writeContextLock.lock()
        guard let current = writeContext, current === context, case .ready = current.connection.state else {
            writeContextLock.unlock()
            completion(AuthorizedWriteError.connectionChanged)
            return
        }
        current.connection.send(content: data, completion: .contentProcessed(completion))
        writeContextLock.unlock()
    }

    internal func write(data: Data, context: AnyObject, operation: AuthorizedWrite,
                        authorization: WebSocketWriteAuthorizing, completion: @escaping (Error?) -> Void) throws {
        writeContextLock.lock(); defer { writeContextLock.unlock() }
        guard let current = writeContext, current === context, case .ready = current.connection.state else {
            throw AuthorizedWriteError.connectionChanged
        }
        // Unchanged physical boundary: all blocking locks precede authority.
        // The writer never acquires eventLock or queues work after this point.
        operation.perform(authorization: authorization) {
            current.connection.send(content: data, completion: .contentProcessed(completion))
        }
    }

    internal func captureEventContext() -> EventContext? {
        eventLock.lock(); defer { eventLock.unlock() }
        return context
    }

    private func withCurrent(_ current: EventContext, _ action: () -> Void) {
        withConnectionEvents {
            guard context === current, current.generation.isCurrent else { return }
            action()
        }
    }

    private func start(_ current: EventContext) {
        current.connection.stateUpdateHandler = { [weak self, weak current] state in
            guard let self = self, let current = current else { return }
            self.handleState(state, context: current)
        }
        current.connection.viabilityUpdateHandler = { [weak self, weak current] viable in
            guard let self = self, let current = current else { return }
            self.handleEvent(.viability(viable), context: current)
        }
        current.connection.betterPathUpdateHandler = { [weak self, weak current] better in
            guard let self = self, let current = current else { return }
            self.handleEvent(.shouldReconnect(better), context: current)
        }
        current.connection.start(queue: queue)
        readLoop(current)
    }

    internal func handleEvent(_ event: ConnectionState, context current: EventContext) {
        withCurrent(current) { delegate?.connectionChanged(state: event) }
    }

    internal func handleState(_ state: NWConnection.State, context current: EventContext) {
        withCurrent(current) {
            let event: ConnectionState
            switch state {
            case .ready:
                writeContextLock.lock(); writeContext = current; writeContextLock.unlock()
                event = .connected
            case .waiting(let error):
                invalidateWriteContext(current)
                if case .posix(.ETIMEDOUT) = error { event = .timeout }
                else { event = .waiting(error: error) }
            case .cancelled:
                invalidateWriteContext(current); event = .cancelled
            case .failed(let error):
                invalidateWriteContext(current); event = .failed(error)
            case .setup, .preparing: return
            @unknown default: return
            }
            // eventLock still protects admission, but context lock is released
            // before any engine callback can acquire its writer semaphore.
            delegate?.connectionChanged(state: event)
        }
    }

    private func invalidateWriteContext(_ current: EventContext) {
        writeContextLock.lock()
        if writeContext === current { writeContext = nil }
        writeContextLock.unlock()
    }

    private func readLoop(_ current: EventContext) {
        withCurrent(current) {
            let receive: (Data?, Bool, NWError?) -> Void = { [weak self, weak current] data, final, error in
                guard let self = self, let current = current else { return }
                self.handleRead(data: data, isFinal: final, error: error, context: current)
            }
            if let receiveOverride = receiveOverride { receiveOverride(current.connection, receive) }
            else {
                current.connection.receive(minimumIncompleteLength: 2, maximumLength: 4096) { data, context, complete, error in
                    receive(data, context?.isFinal == true && complete, error)
                }
            }
        }
    }

    internal func handleRead(data: Data?, isFinal: Bool, error: NWError?, context current: EventContext) {
        withCurrent(current) {
            if let data = data { delegate?.connectionChanged(state: .receive(data)) }
            // A delegate may retire/reconnect recursively. Recheck identity
            // before scheduling another receive, always on this same socket.
            if !isFinal && error == nil { readLoop(current) }
        }
    }

    internal final class TLSCompletion {
        private let lock = NSLock()
        private var completion: ((Bool) -> Void)?
        init(_ completion: @escaping (Bool) -> Void) { self.completion = completion }
        func finish(_ accepted: Bool) { resolve { accepted } }
        func resolve(_ decision: () -> Bool) {
            lock.lock(); let callback = completion; completion = nil; lock.unlock()
            guard let callback = callback else { return }
            callback(decision())
        }
    }

    internal func finishVerification(_ state: PinningState, generation: ConnectionGeneration, completion: TLSCompletion) {
        completion.resolve {
            var accepted = false
            withConnectionEvents {
                guard context?.generation === generation, generation.isCurrent else { return }
                switch state {
                case .success: accepted = true
                case .failed(let error): delegate?.connectionChanged(state: .failed(error))
                }
            }
            return accepted
        }
        // Resolve OS verification exactly once even after retirement. Never
        // leave the old TLS handshake pending or let it fail the new engine.
    }
}
#else
typealias TCPTransport = FoundationTransport
#endif
