//
//  TemplatePredicate+Match.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import Foundation

extension TemplatePredicate {
    /// Lightweight client-side evaluation against an already-loaded `NodeTemplate`.
    /// The browser uses this to filter the templates it has cached locally; the
    /// authoritative filtering is delegated to `TemplateRegistry.loadTemplates` for
    /// remote / paginated stores.
    func matches(_ template: NodeTemplate) -> Bool {
        switch self {
        case let .filter(name, scope):
            if let name, !name.isEmpty {
                let needle = name.lowercased()
                let haystack = template.kind.localizedDisplayName.lowercased()
                if !haystack.contains(needle) { return false }
            }
            if let scope, let kind = scope.kind {
                switch kind {
                case .nodeTemplates:
                    break
                case let .ports(input):
                    if input, template.inputs.isEmpty { return false }
                    if !input, template.outputs.isEmpty { return false }
                }
            }
            // `scope.store` is opaque to client-side evaluation — only the registry
            // knows where a given template was loaded from.
            return true
        case let .not(inner):
            return !inner.matches(template)
        case let .and(predicates):
            return predicates.allSatisfy { $0.matches(template) }
        case let .or(predicates):
            return predicates.contains { $0.matches(template) }
        }
    }
}
