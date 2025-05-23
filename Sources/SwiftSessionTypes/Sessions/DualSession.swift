//
//  DualSession.swift.swift
//  SessionTypeKit
//
//  Created by jacob brown on 4/7/25.
//

import AsyncAlgorithms

/// A utility class for implementing session-based communications using channels
public class DualSession {
    
    /// Creates a new session with two dual endpoints and executes the provided closures on each endpoint
    ///
    /// This method initializes a pair of dual endpoints and concurrently executes the provided closures.
    /// The first closure operates on the secondary endpoint of type `Endpoint<B, A>`, while the second closure
    /// operates on the primary endpoint of type `Endpoint<A, B>`.
    ///
    /// - Parameters:
    ///   - sideOne: The closure to be executed on the secondary endpoint of type `Channel<B, A>`.
    ///   - sideTwo: The closure to be executed on the primary endpoint of type `Endpoint<A, B>`.
    public static func create <A: ~Copyable, B: ~Copyable> (_ sideOne: @Sendable @escaping (_: consuming Endpoint<B, A>) async -> Void,
                                                              _ sideTwo: @Sendable @escaping (_: consuming Endpoint<A, B>) async -> Void)
        async
    {
        let channel: AsyncChannel<Sendable> = AsyncChannel()

        async let task1: Void = {
            let endpoint2 = Endpoint<B, A>(with: channel)
            await sideOne(consume endpoint2)
        }()

        async let task2: Void = {
            let endpoint1 = Endpoint<A, B>(with: channel)
            await sideTwo(consume endpoint1)
        }()

        _ = await (task1, task2)
    }

    /// Closes the endpoint, indicating the end of communication.
    /// - Parameter endpoint: The endpoint to close the communication. The endpoint is consumed after being passed to this method
    public static func close(_ endpoint: consuming Endpoint<Empty, Empty>) {
        endpoint.close()
    }
}

/// Extension for the DualSession class that provides methods using endpoint passing for branching operations
/// between endpoints.
extension DualSession {
    
    /// Offers a choice between two branches on the given endpoint, and returns the selected branch.
    /// - Parameter endpoint: The endpoint to which the choice is offered. This endpoint expects a value indicating the selected branch (`true` for the first branch, `false` for the second branch). These option can be selected from the receiving endpoints using the .left or .right methods. This method consumes the endpoint that is passed into it.
    ///
    /// - Returns: An `Or` enum value containing either the first branch endpoint of type `Endpoint<A, B>` or the second branch endpoint of type `Endpoint<C, D>`.
    public static func offer<A: ~Copyable, B: ~Copyable, C: ~Copyable, D: ~Copyable>(_ endpoint: consuming Endpoint<Empty, Or<Endpoint<A, B>, Endpoint<C, D>>>)
        async -> Or<Endpoint<B, A>, Endpoint<D, C>>
    {
        let bool = await endpoint.recv() as! Bool
        if bool {
            return .left(Endpoint<B, A>(from: endpoint))
        } else {
            return .right(Endpoint<D, C>(from: endpoint))
        }
    }
    
    /// Selects the left branch on the given endpoint and returns the continuation endpoint.
    /// - Parameter endpoint: The endpoint on which the left branch is selected. This endpoint is consumed by this method.
    /// - Returns: The continuation endpoint of type `Endpoint<B, A>`.
    public static func left<A: ~Copyable, B: ~Copyable, C: ~Copyable, D: ~Copyable>(_ endpoint: consuming Endpoint<Or<Endpoint<A, B>, Endpoint<C, D>>, Empty>) async -> Endpoint<B, A> {
        await endpoint.send(true)
        return Endpoint<B, A>(from: endpoint)
    }
    
    /// Selects the left branch on the given endpoint and returns the continuation endpoint.
    /// - Parameter endpoint: The endpoint on which the left branch is selected. This endpoint is consumed by this method.
    /// - Returns: The continuation endpoint of type `Endpoint<B, A>`.
    public static func right<A: ~Copyable, B: ~Copyable, C: ~Copyable, D: ~Copyable>(_ endpoint: consuming Endpoint<Or<Endpoint<A, B>, Endpoint<C, D>>, Empty>) async -> Endpoint<D, C> {
        await endpoint.send(false)
        return Endpoint<D, C>(from: endpoint)
    }
}

/// Extension for the DualSession class that provides methods using endpoint passing for communicataion operations
/// between endpoints.
extension DualSession {
    
    /// Sends a message to the endpoint and returns the continuation endpoint
    /// - Parameters:
    ///   - payload: The payload to be sent to the endpoint.
    ///   - endpoint: The endpoint to which the payload is sent. This endpoint is consumed by this operation.
    /// - Returns: The continuation endpoint
    public static func send<A: Sendable, B: ~Copyable, C: ~Copyable>(_ payload: A,
                                     on endpoint: consuming Endpoint<Coupling<A, Endpoint<B, C>>, Empty>)
        async -> Endpoint<C, B>
    {
        await endpoint.send(payload)
        return Endpoint<C, B>(from: endpoint)
    }

    /// Receives a message from the endpoint and returns it along with the continuation endpoint.
    /// - Parameter endpoint: The endpoint from which the message is received. This endpoint is consumed.
    /// - Returns: A tuple containing the received message and the continuation endpoint.
    public static func recv<A, B: ~Copyable, C: ~Copyable>(from endpoint: consuming Endpoint<Empty, Coupling<A, Endpoint<B, C>>>)
        async -> Coupling<A, Endpoint<C, B>>
    {
        let msg = await endpoint.recv()
        return Coupling(msg as! A, Endpoint<C, B>(from: endpoint))
    }
}
