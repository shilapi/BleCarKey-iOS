//
//  WatchSyncManager.swift
//  BaoJunKey Watch App
//
//  WCSession delegate - receives AppData from iPhone
//

import WatchConnectivity
import Foundation
import Combine
import OSLog

let loggerSyncWatch = Logger(
    subsystem: "com.sleepyshark.carkey.watchkitapp",
    category: "sync"
)

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    @Published var receivedAppData: AppData?
    @Published var isReachable: Bool = false
    @Published var isSynced: Bool = false

    private var session: WCSession

    private override init() {
        session = WCSession.default
        super.init()

        guard WCSession.isSupported() else {
            loggerSyncWatch.error("WCSession not supported on this device")
            return
        }

        session.delegate = self
        session.activate()
        loggerSyncWatch.debug("WCSession activated")
    }

    /// Request latest app data from iPhone
    func requestAppData() {
        guard session.isReachable else {
            loggerSyncWatch.debug("iPhone not reachable for data request")
            return
        }

        session.sendMessage(["request": "appData"], replyHandler: { reply in
            if let jsonData = reply["appData"] as? Data {
                self.decodeAndStore(jsonData)
            } else if let error = reply["error"] as? String {
                loggerSyncWatch.error("iPhone returned error: \(error)")
            }
        }, errorHandler: { error in
            loggerSyncWatch.error("Failed to send message to iPhone: \(error.localizedDescription)")
        })
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            loggerSyncWatch.error("WCSession activation failed: \(error.localizedDescription)")
            return
        }
        loggerSyncWatch.debug("WCSession activation complete: \(activationState.rawValue)")
        isReachable = session.isReachable

        // Load any previously received ApplicationContext
        if let context = session.receivedApplicationContext as? [String: Any],
           let jsonData = context["appData"] as? Data {
            decodeAndStore(jsonData)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        loggerSyncWatch.debug("WCSession reachability changed: \(session.isReachable)")

        // Request fresh data when watch becomes reachable
        if session.isReachable {
            requestAppData()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        loggerSyncWatch.debug("Received application context from iPhone")
        if let jsonData = applicationContext["appData"] as? Data {
            decodeAndStore(jsonData)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        loggerSyncWatch.debug("Received message from iPhone")
        if let jsonData = message["appData"] as? Data {
            decodeAndStore(jsonData)
        }
    }

    // MARK: - Private

    private func decodeAndStore(_ jsonData: Data) {
        do {
            let decoder = JSONDecoder()
            let appData = try decoder.decode(AppData.self, from: jsonData)
            DispatchQueue.main.async {
                self.receivedAppData = appData
                self.isSynced = true
            }
            loggerSyncWatch.debug("Successfully decoded AppData from iPhone: car=\(appData.carData?.carInfo.carName ?? "none"), key=\(appData.carKeyData != nil ? "yes" : "no")")
        } catch {
            loggerSyncWatch.error("Failed to decode AppData: \(error.localizedDescription)")
        }
    }
}
