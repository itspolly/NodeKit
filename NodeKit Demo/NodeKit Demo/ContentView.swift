//
//  ContentView.swift
//  NodeKit Demo
//
//  Created by Jamie Bishop on 24/05/2026.
//

import SwiftUI
import NodeKit

struct ContentView: View {
    @State private var graph = Graph(nodes: [])
    @State private var browserFilter: TemplatePredicate = .filter(name: nil, scope: nil)
    @State var registryModel = RegistryViewModel()

    var body: some View {
        NavigationSplitView {
            TemplateRegistryView(
                templateRegistry: registryModel.registry,
                predicate: $browserFilter
            )
            .frame(width: 320)
        } detail: {
            GraphEditor(graph: $graph, templateRegistry: registryModel.registry)
        }
    }
}

#Preview {
    ContentView()
}
