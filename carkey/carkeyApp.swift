//
//  carkeyApp.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//

import SwiftUI
import Foundation

@main
struct carkeyApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(DataManager.shared)
                .environmentObject(BluetoothManager.shared)
        }
    }
}
