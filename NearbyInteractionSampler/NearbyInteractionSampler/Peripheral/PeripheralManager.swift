//
//  PeripheralManager.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/19.
//

import Foundation
import CoreBluetooth
import NearbyInteraction

@Observable
class PeripheralManager: NSObject {
    private var peripheralManager: CBPeripheralManager?
    private let serviceUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd91")
    private let peripheralTokenCharacteristicUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd92")
    private let centralTokenCharacteristicUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd93")

    private var peripheralTokenCharacteristic: CBMutableCharacteristic?
    private var centralTokenCharacteristic: CBMutableCharacteristic?

    private var niSession: NISession?
    private var localDiscoveryToken: NIDiscoveryToken?

    var isPoweredOn: Bool = false
    var distance: Measurement<UnitLength>? = nil

    // MARK: - 初期化
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - アドバタイズ開始
    private func startAdvertising() {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            return
        }

        // サービスとキャラクタリスティックをセットアップ
        let service = CBMutableService(type: serviceUUID, primary: true)

        let centralCharacteristic = CBMutableCharacteristic(
            type: centralTokenCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )

        let peripheralCharacteristic = CBMutableCharacteristic(
            type: peripheralTokenCharacteristicUUID,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )

        service.characteristics = [centralCharacteristic, peripheralCharacteristic]

        self.centralTokenCharacteristic = centralCharacteristic
        self.peripheralTokenCharacteristic = peripheralCharacteristic

        peripheralManager.add(service)

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "MyPeripheral" // 任意で
        ])

        startNISession()
    }

    /// アドバタイズ停止
    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
    }

    // MARK: - Nearby Interaction セッション設定

    private func startNISession() {
        niSession = NISession()
        niSession?.delegate = self

        if let token = niSession?.discoveryToken,
           let data = archiveDiscoveryToken(token) {
            self.localDiscoveryToken = token
            self.centralTokenCharacteristic?.value = data
        } else {
            print("Failed to get local discovery token.")
        }
    }

    private func archiveDiscoveryToken(_ token: NIDiscoveryToken) -> Data? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            return data
        } catch {
            print("Failed to archive discovery token: \(error)")
            return nil
        }
    }

    private func unarchiveDiscoveryToken(_ data: Data) -> NIDiscoveryToken? {
        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
            return token
        } catch {
            print("Failed to unarchive discovery token: \(error)")
            return nil
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension PeripheralManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isPoweredOn = (peripheral.state == .poweredOn)
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            stopAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let characteristic = request.characteristic as? CBMutableCharacteristic else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }

        if characteristic.uuid == centralTokenCharacteristicUUID {
            if let value = characteristic.value {
                if request.offset > value.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }
                request.value = value.subdata(in: request.offset..<value.count)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        } else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let characteristic = request.characteristic as? CBMutableCharacteristic,
                  let requestValue = request.value else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            if characteristic.uuid == peripheralTokenCharacteristicUUID {
                characteristic.value = requestValue
                if let centralToken = unarchiveDiscoveryToken(requestValue) {
                    let config = NINearbyPeerConfiguration(peerToken: centralToken)
                    niSession?.run(config)
                }

                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }
}

// MARK: - NISessionDelegate
extension PeripheralManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let firstObject = nearbyObjects.first, let distance = firstObject.distance else { return }

        let measurementDistance = Measurement(value: Double(distance), unit: UnitLength.meters)
        self.distance = measurementDistance
    }

    func sessionWasSuspended(_ session: NISession) {
        print("NISession was suspended.")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        print("NISession suspension ended. Restarting session.")
        if let localToken = session.discoveryToken, let data = archiveDiscoveryToken(localToken) {
            centralTokenCharacteristic?.value = data
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NISession invalidated: \(error)")
        niSession = nil
        startNISession()
    }
}
