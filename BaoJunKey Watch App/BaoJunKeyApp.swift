//
//  BaoJunKeyApp.swift
//  BaoJunKey Watch App
//
//  Watch app entry point with environment objects
//

import SwiftUI

@main
struct BaoJunKey_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchBluetoothManager.shared)
                .environmentObject(WatchDataManager.shared)
        }
    }
}
