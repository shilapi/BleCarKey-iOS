//
//  WatchDataManager.swift
//  BaoJunKey Watch App
//
//  Local data persistence + bridge between WCSession sync and BLE
//

import Foundation
import SwiftUI
import Combine
import OSLog

let loggerDataWatch = Logger(
    subsystem: "com.sleepyshark.carkey.watchkitapp",
    category: "data"
)

class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    // Display properties for UI
    @Published var carName: String = "未连接手机"
    @Published var carModel: String = ""
    @Published var batteryLevel: Int = 0
    @Published var hasKeyData: Bool = false
    @Published var lastSyncDate: String = "从未同步"
    @Published var isLocked: Bool = true

    // Internal state
    private(set) var appData: AppData = AppData()
    private let syncManager = WatchSyncManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadFromDisk()
        setupSyncObserver()
        updateDisplayProperties()
    }

    // MARK: - Persistence

    private static func archiveURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("WatchUserData").appendingPathExtension("json")
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: WatchDataManager.archiveURL()) else {
            loggerDataWatch.debug("No local data file found - fresh start")
            return
        }
        do {
            let decoder = JSONDecoder()
            appData = try decoder.decode(AppData.self, from: data)
            loggerDataWatch.debug("Loaded local data: car=\(self.appData.carData?.carInfo.carName ?? "none"), key=\(self.appData.carKeyData != nil)")
        } catch {
            loggerDataWatch.error("Failed to decode local data: \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(appData)
            try data.write(to: WatchDataManager.archiveURL())
            loggerDataWatch.debug("Local data saved")
        } catch {
            loggerDataWatch.error("Failed to save local data: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Observer

    private func setupSyncObserver() {
        // Observe WatchSyncManager for new data from iPhone
        syncManager.$receivedAppData
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAppData in
                self?.applySyncedData(newAppData)
            }
            .store(in: &cancellables)
    }

    private func applySyncedData(_ newAppData: AppData) {
        // Merge: only update non-nil fields from synced data
        if let userData = newAppData.userData {
            appData.userData = userData
        }
        if let carKeyData = newAppData.carKeyData {
            appData.carKeyData = carKeyData
        }
        if let carData = newAppData.carData {
            appData.carData = carData
        }
        save()
        updateDisplayProperties()

        // Push key data to BLE manager
        pushKeyToBluetoothManager()
    }

    // MARK: - BLE Key Bridge

    func getBleKeyInfo() -> E300BleKeyInfoModel? {
        guard let keyData = appData.carKeyData else {
            loggerDataWatch.debug("No carKeyData available for BLE key model")
            return nil
        }
        return E300BleKeyInfoModel(
            bleMac: keyData.bleMac,
            keyId: keyData.keyId,
            masterKey: keyData.masterKey,
            keyMasterRandom: keyData.keyMasterRandom
        )
    }

    func pushKeyToBluetoothManager() {
        guard let keyInfo = getBleKeyInfo() else { return }
        WatchBluetoothManager.shared.UpdateKey(key: keyInfo)
        loggerDataWatch.debug("BLE key pushed to WatchBluetoothManager")
    }

    // MARK: - Display

    private func updateDisplayProperties() {
        carName = appData.carData?.carInfo.carName ?? "未连接手机"
        carModel = appData.carData?.carInfo.carTypeName ?? ""
        batteryLevel = appData.carData?.carStatus.batterySOCPercentage ?? 0
        hasKeyData = appData.carKeyData != nil
        lastSyncDate = appData.carData?.updateDate ?? "从未同步"
    }
}
