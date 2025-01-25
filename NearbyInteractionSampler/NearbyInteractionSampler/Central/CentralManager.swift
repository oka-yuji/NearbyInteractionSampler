//
//  CentralManager.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/24.
//

import Foundation
import CoreBluetooth
import NearbyInteraction

@Observable
class CentralManager: NSObject {
    private var centralManager: CBCentralManager?
    private var discoveredPeripheral: CBPeripheral?

    private let serviceUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd91")
    private let peripheralTokenCharacteristicUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd92")
    private let centralTokenCharacteristicUUID = CBUUID(string: "af89f37e-5f29-4410-bdbc-96da2006dd93")

    private var peripheralTokenCharacteristic: CBCharacteristic?
    private var centralTokenCharacteristic: CBCharacteristic?

    private var niSession: NISession?
    private var localDiscoveryToken: NIDiscoveryToken?

    var isPoweredOn: Bool = false
    var distance: Measurement<UnitLength>? = nil

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard let cm = centralManager,
              cm.state == .poweredOn else {
            print("CentralManager is not powered on yet.")
            return
        }
        cm.scanForPeripherals(withServices: [serviceUUID], options: nil)
        print("Scanning for peripherals...")
    }

    func stopScan() {
        centralManager?.stopScan()
    }

    private func setupNISession() {
        niSession = NISession()
        niSession?.delegate = self
        if let token = niSession?.discoveryToken {
            localDiscoveryToken = token
        } else {
            print("Failed to get local discoveryToken in Central.")
        }
    }

    private func archiveDiscoveryToken(_ token: NIDiscoveryToken) -> Data? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                        requiringSecureCoding: true)
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

extension CentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isPoweredOn = (central.state == .poweredOn)
        if central.state == .poweredOn {
            print("Central is powered on.")
            // 自動でスキャンを始めるならコメントアウト外す
            // startScan()
        } else {
            print("Central state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber)
    {
        print("Discovered peripheral: \(peripheral)")
        self.discoveredPeripheral = peripheral

        stopScan()

        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral)")
        peripheral.delegate = self

        peripheral.discoverServices([serviceUUID])

        setupNISession()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(String(describing: error))")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral)")
    }
}

extension CentralManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("didDiscoverServices error: \(error)")
            return
        }

        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([centralTokenCharacteristicUUID,
                                                    peripheralTokenCharacteristicUUID],
                                                   for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("didDiscoverCharacteristicsFor error: \(error)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == centralTokenCharacteristicUUID {
                centralTokenCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }

            if characteristic.uuid == peripheralTokenCharacteristicUUID {
                peripheralTokenCharacteristic = characteristic
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("didUpdateValueFor error: \(error)")
            return
        }

        if characteristic.uuid == centralTokenCharacteristicUUID {
            guard let data = characteristic.value,
                  let peripheralToken = unarchiveDiscoveryToken(data) else {
                print("Failed to unarchive token from peripheral.")
                return
            }

            print("Got peripheral's token from characteristic: \(peripheralToken)")
            if let niSession = niSession {
                let config = NINearbyPeerConfiguration(peerToken: peripheralToken)
                niSession.run(config)
            }

            if let localToken = localDiscoveryToken,
               let localTokenData = archiveDiscoveryToken(localToken),
               let peripheralTokenCharacteristic = peripheralTokenCharacteristic
            {
                peripheral.writeValue(localTokenData,
                                      for: peripheralTokenCharacteristic,
                                      type: .withResponse)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("didWriteValueFor error: \(error)")
        } else {
            print("Successfully wrote local token to peripheral.")
        }
    }
}

extension CentralManager: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let firstObject = nearbyObjects.first, let dist = firstObject.distance else { return }
        distance = Measurement(value: Double(dist), unit: .meters)
    }

    func sessionWasSuspended(_ session: NISession) {
        print("NISession was suspended on Central.")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        print("NISession suspension ended. Restarting session on Central.")

        if let localToken = session.discoveryToken,
           let data = archiveDiscoveryToken(localToken) {
            if let peripheral = discoveredPeripheral,
               let peripheralTokenCharacteristic = peripheralTokenCharacteristic {
                peripheral.writeValue(data,
                                      for: peripheralTokenCharacteristic,
                                      type: .withResponse)
            }
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NISession invalidated on Central: \(error)")
        niSession = nil
        setupNISession()
    }
}
