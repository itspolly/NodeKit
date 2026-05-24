//
//  NodeTemplate+Kind.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

import Foundation

public extension NodeTemplate {
    /// Identity + display name for a ``NodeTemplate``.
    ///
    /// `Kind` is what ``Node/templateIdentifier`` points at and what the
    /// browser keys cells on. Keep ``id`` stable across releases — it's
    /// written into saved graphs and used to resolve nodes back to their
    /// shape after a round-trip.
    struct Kind: Sendable, Identifiable, Equatable, Codable {
        /// Stable identity for this template kind. Persisted in saved graphs.
        public let id: UUID

        /// Localized display name shown in the browser and the node header.
        public let localizedDisplayName: String

        /// Create a kind.
        public init(id: UUID, localizedDisplayName: String) {
            self.id = id
            self.localizedDisplayName = localizedDisplayName
        }
    }
}
