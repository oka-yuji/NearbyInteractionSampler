//
//  RootView.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/24.
//

import SwiftUI

struct RootView: View {
    @State private var showPeripheralView: Bool = false
    @State private var showCentralView: Bool = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PeripheralView()
                    } label: {
                        Text("Peripheral")
                    }
                    NavigationLink {
                        CentralView()
                    } label: {
                        Text("Central")
                    }
                } header: {
                    Text("Core Bluetooth")
                        .textCase(.none)
                }
            }
            .navigationTitle("NI Sampler")
        }
    }
}

#Preview {
    RootView()
}
