//
//  ViewModel.swift
//  NodeKit Demo
//
//  Created by Jamie Bishop on 24/05/2026.
//

import Foundation
import NodeKit

class RegistryViewModel {
    let registry = TemplateRegistry()
    
    init() {
        let source = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Source"),
            inputs: [],
            outputs: [
                .init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "Value")
            ]
        )
        let sink = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Sink"),
            inputs: [
                .init(id: UUID(), kind: .input, type: .double, localizedDisplayName: "Input")
            ],
            outputs: []
        )

        registry.register(template: source)
        registry.register(template: sink)
        
        // Late-arrival test: after 3s, register another template.
        // It should appear in the browser without any user interaction.
        Task { @MainActor [registry] in
            try? await Task.sleep(for: .seconds(3))
            let late = NodeTemplate(
                kind: .init(id: UUID(), localizedDisplayName: "Late arrival"),
                inputs:  [.init(id: UUID(), kind: .input,  type: .double, localizedDisplayName: "in")],
                outputs: [.init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "out")]
            )
            registry.register(template: late)
        }
    }
}
