//
//  CentralView.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/24.
//

import SwiftUI

struct CentralView: View {
    @State private var centralManager: CentralManager = .init()
    var body: some View {
        VStack(spacing: 16) {
            Text(centralManager.isPoweredOn ? "Powered On" : "Powered Off")
                .font(.headline)
                .foregroundColor(centralManager.isPoweredOn ? .green : .red)

            if let distance = centralManager.distance {
                Text(Helper.localFormatter.string(from: distance))
                    .font(.title)
            } else {
                Text("Distance: --")
                    .font(.title)
            }

            Button("Start Scan") {
                centralManager.startScan()
            }
            .padding()
            .disabled(!centralManager.isPoweredOn)
        }
        .padding()
    }
}

#Preview {
    CentralView()
}
