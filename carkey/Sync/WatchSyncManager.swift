//
//  WatchSyncManager.swift
//  carkey
//
//  iOS-side WCSession manager - sends AppData to Apple Watch
//

import WatchConnectivity
import Foundation
import OSLog

let loggerSyncIOS = Logger(
    subsystem: "com.sleepyshark.carkey",
    category: "sync"
)

class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    private var session: WCSession

    private override init() {
        session = WCSession.default
        super.init()
    }

    func startSession() {
        guard WCSession.isSupported() else {
            loggerSyncIOS.warning("WCSession not supported on this device")
            return
        }
        self.session.delegate = self
        self.session.activate()
        loggerSyncIOS.debug("iOS WCSession activated")
    }

    /// Send AppData to watch via updateApplicationContext
    func sendAppData(_ appData: AppData) {
        guard self.session.activationState == .activated else {
            loggerSyncIOS.debug("WCSession not activated yet, skipping sync")
            return
        }

        guard self.session.isPaired, self.session.isWatchAppInstalled else {
            loggerSyncIOS.debug("Watch not available for sync (paired: \(self.session.isPaired), installed: \(self.session.isWatchAppInstalled))")
            return
        }

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(appData)
            let context: [String: Any] = [
                "appData": jsonData,
                "timestamp": Date().timeIntervalSince1970
            ]
            try self.session.updateApplicationContext(context)
            loggerSyncIOS.debug("AppData synced to watch: car=\(appData.carData?.carInfo.carName ?? "none"), key=\(appData.carKeyData != nil)")
        } catch {
            loggerSyncIOS.error("Failed to sync AppData to watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            loggerSyncIOS.error("iOS WCSession activation failed: \(error.localizedDescription)")
            return
        }
        loggerSyncIOS.debug("iOS WCSession activated: state=\(activationState.rawValue)")

        // Send current data to watch on activation
        let currentData = DataManager.shared.appData
        sendAppData(currentData)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        loggerSyncIOS.debug("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        loggerSyncIOS.debug("WCSession deactivated, reactivating")
        session.activate()
    }

    // Handle watch requesting fresh data
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "appData" {
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(DataManager.shared.appData)
                replyHandler(["appData": jsonData])
                loggerSyncIOS.debug("Sent appData to watch on request")
            } catch {
                replyHandler(["error": error.localizedDescription])
                loggerSyncIOS.error("Failed to encode appData for watch request: \(error)")
            }
        }
    }
}
