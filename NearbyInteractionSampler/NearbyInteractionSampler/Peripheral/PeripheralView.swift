//
//  PeripheralView.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/24.
//

import SwiftUI

struct PeripheralView: View {
    @State private var peripheralManager: PeripheralManager = .init()

    var body: some View {
        VStack(spacing: 16) {
            Text(peripheralManager.isPoweredOn ? "Powered On" : "Not Powered On")
                .font(.headline)

            if let distance = peripheralManager.distance?.converted(to: Helper.localUnits) {
                Text(Helper.localFormatter.string(from: distance))
                    .font(.title)
            } else {
                Text("Distance: --")
                    .font(.title)
            }
        }
        .padding()
    }
}

#Preview {
    PeripheralView()
}
