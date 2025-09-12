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
            ContentView()
                .environmentObject(DataManager.shared.carData)
                .environmentObject(DataManager.shared.userData)
                .environmentObject(DataManager.shared.sgmwUnifiedOAuth)
        }
    }
}
