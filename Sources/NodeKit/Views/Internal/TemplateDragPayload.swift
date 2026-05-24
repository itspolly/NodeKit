//
//  TemplateDragPayload.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let nodeKitTemplate = UTType(exportedAs: "is.polly.nodekit.template")
}

struct TemplateDragPayload: Codable, Transferable, Hashable, Sendable {
    let templateKindID: UUID

    static var transferRepresentation: some TransferRepresentation {
        // `ProxyRepresentation` keeps the in-process drag path synchronous —
        // no `NSItemProvider` JSON round-trip and no async resolution races
        // on the drop side. Declared first so the system prefers it whenever
        // both sides live in-process (the common case: template browser →
        // graph canvas in the same window). `CodableRepresentation` stays
        // as the cross-process fallback and is what the exported UTI
        // advertises.
        ProxyRepresentation(
            exporting: { $0.templateKindID.uuidString },
            importing: { Self(templateKindID: UUID(uuidString: $0)!) }
        )
        CodableRepresentation(contentType: .nodeKitTemplate)
    }
}
