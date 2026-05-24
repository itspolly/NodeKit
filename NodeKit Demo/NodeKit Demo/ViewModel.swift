//
//  ViewModel.swift
//  NodeKit Demo
//
//  Created by Jamie Bishop on 24/05/2026.
//

import Foundation
import NodeKit

@MainActor
class RegistryViewModel {
    let templates = TemplateRegistry()
    let portTypes = PortTypeRegistry()

    init() {
        // Custom port type registered alongside the four NodeKit primitives.
        // The editor reads display hints (colour, name) from `portTypes`;
        // connection compatibility compares `typeIdentifier` strings directly,
        // so a port wires up correctly even if its type isn't registered.
        let pulse = PortType(
            id: "demo.pulse",
            localizedDisplayName: "Pulse",
            color: .init(red: 0.78, green: 0.40, blue: 0.92)
        )
        portTypes.register(pulse)

        let source = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Source"),
            inputs: [],
            outputs: [
                .init(id: UUID(), kind: .output, type: pulse, localizedDisplayName: "Pulse"),
                .init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "Value"),
            ]
        )
        let sink = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Sink"),
            inputs: [
                .init(id: UUID(), kind: .input, type: pulse, localizedDisplayName: "Pulse"),
                .init(id: UUID(), kind: .input, type: .double, localizedDisplayName: "Input"),
            ],
            outputs: []
        )

        templates.register(template: source)
        templates.register(template: sink)

        // Late-arrival test: after 3s, register another template. It should
        // appear in the browser without any user interaction. Demonstrates
        // `@Observable` propagation through `TemplateRegistry`.
        Task { @MainActor [templates] in
            try? await Task.sleep(for: .seconds(3))
            let late = NodeTemplate(
                kind: .init(id: UUID(), localizedDisplayName: "Late arrival"),
                inputs:  [.init(id: UUID(), kind: .input,  type: .double, localizedDisplayName: "in")],
                outputs: [.init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "out")]
            )
            templates.register(template: late)
        }
    }
}
